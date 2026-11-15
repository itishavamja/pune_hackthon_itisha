"""Read-only dashboard queries. Deterministic - never calls Sarvam."""
from typing import Optional

from sqlalchemy import case, func
from sqlalchemy.orm import Session

from agents.customer_agent import run_customer_analysis
from agents.sales_agent import run_sales_analysis
from models import Alert, AnalysisRun, Transaction

SEVERITY_RANK = case((Alert.severity == "HIGH", 0), (Alert.severity == "MEDIUM", 1), else_=2)
RISK_RANK = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


def summary(db: Session, merchant_id: int) -> dict:
    sales = run_sales_analysis(db, merchant_id)
    customers = run_customer_analysis(db, merchant_id)
    total_minor = (db.query(func.coalesce(func.sum(Transaction.amount_minor), 0))
                   .filter(Transaction.merchant_id == merchant_id).scalar())
    alerts_count = db.query(Alert).filter(Alert.merchant_id == merchant_id).count()
    last_run = (db.query(AnalysisRun.created_at).filter(AnalysisRun.merchant_id == merchant_id)
                .order_by(AnalysisRun.id.desc()).first())
    return {
        "today_revenue": sales["today_revenue"],
        "total_revenue": round(total_minor / 100, 2),
        "last_7_days_revenue": sales["last_7_days_revenue"],
        "previous_7_days_revenue": sales["previous_7_days_revenue"],
        "revenue_growth_percentage": sales["revenue_change_percentage"],
        "total_customers": customers["total_customers"],
        "at_risk_customers": customers["at_risk_customers"],
        "alerts_count": alerts_count,
        "sales_status": sales["sales_status"],
        "last_analysis_at": last_run[0] if last_run else None,
    }


def forecast(db: Session, merchant_id: int, history_days: int) -> dict:
    s = run_sales_analysis(db, merchant_id)
    s["historical_sales"] = s["historical_sales"][-history_days:]
    return s


def churn(db: Session, merchant_id: int, limit: int, offset: int, risk_level: Optional[str]) -> dict:
    c = run_customer_analysis(db, merchant_id)
    rows = c["at_risk_details"]                      # already sorted: HIGH first, then by spending
    if risk_level:
        rows = [r for r in rows if r["risk_level"] == risk_level]
    return {
        "summary": {k: c[k] for k in ("total_customers", "active_customers", "at_risk_customers",
                                       "early_warning_customers", "inactive_14_plus_days",
                                       "churn_risk_percentage", "average_basket_value",
                                       "at_risk_total_spending")},
        "customer_segments": c["customer_segments"],
        "at_risk_customers": rows[offset:offset + limit],
        "pagination": {"total": len(rows), "limit": limit, "offset": offset},
    }


def alerts(db: Session, merchant_id: int, limit: int, offset: int, severity: Optional[str]) -> dict:
    q = db.query(Alert).filter(Alert.merchant_id == merchant_id)
    if severity:
        q = q.filter(Alert.severity == severity)
    total = q.count()
    rows = q.order_by(SEVERITY_RANK, Alert.created_at.desc(), Alert.id.desc()).offset(offset).limit(limit).all()
    return {"alerts": rows, "pagination": {"total": total, "limit": limit, "offset": offset}}
