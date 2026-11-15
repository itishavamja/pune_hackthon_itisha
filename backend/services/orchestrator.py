"""Central analysis pipeline: run_analysis(merchant_id).

Order: validate merchant -> sales -> customers -> risk -> combine -> growth (Sarvam)
-> store run + alerts + campaign drafts (ONE transaction) -> return everything.

Failure policy: every agent runs in its own try/except. A failed agent produces an
"unavailable" result plus a warning; the other agents still run. Sarvam problems are
absorbed inside the growth step (template fallback), so they can never crash a run.
"""
import logging
from typing import Optional

from sqlalchemy.orm import Session

from agents.customer_agent import run_customer_analysis
from agents.growth_agent import generate_growth_plan
from agents.risk_agent import run_risk_analysis
from agents.sales_agent import run_sales_analysis
from models import Alert, AnalysisRun, Merchant
from services import campaign_service
from utils.helpers import utcnow

logger = logging.getLogger(__name__)


class MerchantNotFound(Exception):
    pass


def _safe(name: str, fn, warnings: list[str], fallback: dict) -> dict:
    try:
        return fn()
    except Exception as exc:
        logger.exception("%s agent failed", name)
        warnings.append(f"{name} analysis is unavailable ({type(exc).__name__}).")
        return {**fallback, "error": f"{name} analysis failed"}


def _strip_customers(c: dict) -> dict:
    """Stored/returned churn result omits the full per-customer list (at_risk_details stays)."""
    return {k: v for k, v in c.items() if k != "customers"}


def _build_alerts(merchant_id: int, run_id: int, sales: dict, customers: dict, risk: dict) -> list[Alert]:
    out: list[Alert] = []
    if sales.get("sales_status") == "declining":
        signals = [x for x in (sales.get("revenue_change_percentage"), sales.get("projected_change_percentage"))
                   if x is not None]
        worst = min(signals) if signals else 0
        out.append(Alert(merchant_id=merchant_id, analysis_run_id=run_id, alert_type="sales_decline",
                         severity="HIGH" if worst < -25 else "MEDIUM", title="Sales Decline Warning",
                         description=sales.get("alert_message") or "Sales are declining.",
                         metric_value=f"{worst:.1f}%"))
    n = customers.get("at_risk_customers", 0)
    if n:
        out.append(Alert(merchant_id=merchant_id, analysis_run_id=run_id, alert_type="customer_churn",
                         severity="HIGH" if customers.get("churn_risk_percentage", 0) >= 25 else "MEDIUM",
                         title="Regular Customers Stopped Visiting",
                         description=f"{n} regular customers have not visited for 14 or more days "
                                     f"({customers.get('churn_risk_percentage', 0):.0f}% of your customers).",
                         metric_value=str(n)))
    for a in risk.get("alerts", []):
        out.append(Alert(merchant_id=merchant_id, analysis_run_id=run_id, alert_type=a["alert_type"],
                         severity=a["severity"], title=a["title"], description=a["description"],
                         metric_value=str(a["detected_value"])))
    return out


def run_analysis(db: Session, merchant_id: int, language: str = "Hindi",
                 idempotency_key: Optional[str] = None, now=None) -> dict:
    merchant = db.get(Merchant, merchant_id)
    if merchant is None:
        raise MerchantNotFound(f"Merchant {merchant_id} not found")

    # Same key from the same merchant -> return the stored run, do no new work.
    if idempotency_key:
        prior = (db.query(AnalysisRun)
                 .filter(AnalysisRun.merchant_id == merchant_id,
                         AnalysisRun.idempotency_key == idempotency_key).first())
        if prior:
            logger.info("Idempotent replay of analysis run %s", prior.id)
            return _response_from_run(db, prior, replayed=True)

    warnings: list[str] = []
    sales = _safe("Sales", lambda: run_sales_analysis(db, merchant_id, now), warnings,
                  {"sales_status": "unavailable", "forecast_sales": [], "historical_sales": [],
                   "actual_vs_predicted": []})
    customers = _safe("Customer", lambda: run_customer_analysis(db, merchant_id, now), warnings,
                      {"total_customers": 0, "at_risk_customers": 0, "at_risk_details": [],
                       "customers": [], "customer_segments": []})
    risk = _safe("Risk", lambda: run_risk_analysis(db, merchant_id, now), warnings,
                 {"alerts": [], "alert_count": 0})

    try:
        growth = generate_growth_plan(sales, customers, risk, merchant, language)
    except Exception as exc:  # should not happen (agent never raises) but never crash the run
        logger.exception("Growth agent failed")
        warnings.append(f"Growth recommendations are unavailable ({type(exc).__name__}).")
        growth = {"business_explanation": None, "explanation_source": "unavailable", "campaigns": []}
    if growth["explanation_source"] == "fallback":
        warnings.append("AI service unavailable - template wording was used for the explanation "
                        "and campaign drafts. All numbers are unaffected.")

    try:
        run = AnalysisRun(merchant_id=merchant_id, idempotency_key=idempotency_key,
                          sales_result=sales, churn_result=_strip_customers(customers),
                          risk_result=risk, growth_result={})
        db.add(run)
        db.flush()
        # Alerts always reflect the latest run: replace this merchant's previous alerts.
        db.query(Alert).filter(Alert.merchant_id == merchant_id).delete(synchronize_session=False)
        db.add_all(_build_alerts(merchant_id, run.id, sales, customers, risk))
        saved = campaign_service.save_drafts(db, merchant_id, run.id, growth["campaigns"])
        run.growth_result = {"business_explanation": growth["business_explanation"],
                             "explanation_source": growth["explanation_source"],
                             "language": language, "warnings": warnings,
                             "campaign_ids": [c.id for c in saved]}
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("Could not store analysis run")
        raise

    return _response_from_run(db, run, replayed=False)


def _response_from_run(db: Session, run: AnalysisRun, replayed: bool) -> dict:
    from models import Campaign
    g = run.growth_result or {}
    ids = g.get("campaign_ids", [])
    camps = db.query(Campaign).filter(Campaign.id.in_(ids)).order_by(Campaign.id).all() if ids else []
    return {
        "analysis_run_id": run.id,
        "merchant_id": run.merchant_id,
        "generated_at": run.created_at.isoformat(),
        "replayed": replayed,
        "sales_insights": run.sales_result,
        "customer_insights": run.churn_result,
        "business_risk_insights": run.risk_result,
        "ai_explanation": {"text": g.get("business_explanation"), "source": g.get("explanation_source"),
                           "language": g.get("language")},
        "campaign_drafts": [campaign_service.campaign_to_dict(c) for c in camps],
        "warnings": g.get("warnings", []),
    }
