"""Growth Action Agent.

Step 1 (rules, deterministic): look at the REAL analysis results and decide which
campaigns make sense, who they target, how many customers that is, and why.
Step 2 (Sarvam, optional): write the explanation and the message wording.

Sarvam never decides numbers, target counts or segments. If Sarvam is
unavailable, template wording is used and everything else is unchanged.
Campaigns are only ever created as status="draft" - nothing is sent here.

Rules:
  win_back          at least 1 customer is "At Risk" (overdue AND away 14+ days)
  weekend_promotion weekend average revenue is >= 25% above weekday average
  basket_size       >= 5 customers whose average bill is < 85% of the shop average
"""
import logging

from integrations import sarvam_client

logger = logging.getLogger(__name__)

WEEKEND_STRENGTH = 1.25
BASKET_LOW_RATIO = 0.85
BASKET_MIN_CUSTOMERS = 5
MAX_CAMPAIGNS = 3


def plan_campaigns(sales: dict, customers: dict) -> list[dict]:
    """Deterministic campaign plan from real numbers."""
    plan: list[dict] = []

    at_risk = customers.get("at_risk_customers", 0)
    if at_risk > 0:
        details = customers.get("at_risk_details", [])
        spend = sum(d["total_spending"] for d in details)
        intervals = [d["normal_visit_interval_days"] for d in details if d.get("normal_visit_interval_days")]
        typical = sum(intervals) / len(intervals) if intervals else None
        reason = (f"{at_risk} regular customers have not visited for 14 or more days"
                  + (f" (they normally visit about every {typical:.0f} days)" if typical else "")
                  + f". Together they have spent Rs {spend:,.0f} with you so far.")
        plan.append({"campaign_type": "win_back", "target_segment": "At-risk regular customers",
                     "target_customer_count": at_risk, "objective": "Customer retention",
                     "reason_for_recommendation": reason})

    wd, we = sales.get("weekday_average_revenue", 0), sales.get("weekend_average_revenue", 0)
    if wd > 0 and we >= wd * WEEKEND_STRENGTH:
        active = customers.get("total_customers", 0) - at_risk
        plan.append({"campaign_type": "weekend_promotion", "target_segment": "Active customers",
                     "target_customer_count": max(active, 0), "objective": "Boost weekend sales",
                     "reason_for_recommendation":
                         f"Weekend sales average Rs {we:,.0f} per day versus Rs {wd:,.0f} on weekdays "
                         f"({(we / wd - 1) * 100:.0f}% higher), so weekends are your strongest days."})

    avg = customers.get("average_basket_value", 0)
    low = [c for c in customers.get("customers", [])
           if c["visit_count"] >= 2 and avg > 0
           and (c["total_spending"] / c["visit_count"]) < avg * BASKET_LOW_RATIO]
    if len(low) >= BASKET_MIN_CUSTOMERS:
        plan.append({"campaign_type": "basket_size", "target_segment": "Low average-bill customers",
                     "target_customer_count": len(low), "objective": "Increase basket value",
                     "reason_for_recommendation":
                         f"{len(low)} customers spend less than Rs {avg * BASKET_LOW_RATIO:,.0f} per visit, "
                         f"while your shop average is Rs {avg:,.0f}. A small incentive can lift their bill."})
    return plan[:MAX_CAMPAIGNS]


def generate_growth_plan(sales: dict, customers: dict, risk: dict, merchant, language: str = "Hindi") -> dict:
    """Return {"business_explanation", "explanation_source", "campaigns": [draft dicts]}. Never raises."""
    plan = plan_campaigns(sales, customers)
    facts = sarvam_client.build_facts(sales, customers, merchant.business_name, language, risk)
    if plan:
        insights, source = sarvam_client.generate_insights(facts, plan=plan)
    else:  # healthy shop: nothing to promote; explanation only, no AI call needed
        insights, source = sarvam_client.fallback_insights(facts), "fallback"
        insights.campaigns = []

    campaigns = []
    for p, text in zip(plan, insights.campaigns):
        campaigns.append({
            "campaign_title": text.title,
            "campaign_type": p["campaign_type"],
            "target_segment": p["target_segment"],      # from rules, not from the LLM
            "target_customer_count": p["target_customer_count"],
            "language": language,
            "message": text.message,
            "objective": p["objective"],
            "reason_for_recommendation": p["reason_for_recommendation"],
            "status": "draft",
        })
    return {"business_explanation": insights.business_explanation,
            "explanation_source": source, "campaigns": campaigns}
