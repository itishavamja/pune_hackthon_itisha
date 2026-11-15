"""Customer Intelligence Agent - RFM + personal visit-interval churn logic.

For every customer:
  Recency   = days since last purchase (IST calendar days)
  Frequency = number of transactions
  Monetary  = total spending
  Normal interval = MEAN gap (days) between the customer's distinct visit days.
                    (Mean, not median: visits are irregular, and a median of
                    1-2 days for a frequent shopper made normal pauses look alarming.)

Risk level (ratio = days_inactive / normal_interval):
  LOW    ratio <= 1.5   (still inside the normal pattern)
  MEDIUM 1.5 < ratio <= 2
  HIGH   ratio > 2

Segments:
  "At Risk"       risk MEDIUM/HIGH AND not seen for >= 14 days (stopped visiting)
  "Early Warning" risk MEDIUM/HIGH but seen within the last 14 days (watch list)
  "Active"        risk LOW
  "New"           too little history: fewer than 4 visit days or first purchase
                  < 21 days ago. These are NEVER called at-risk or churned.

`at_risk_customers` counts only the "At Risk" segment.
"""
import logging

import pandas as pd
from sqlalchemy.orm import Session

from models import Customer
from utils.calculations import load_transactions, rupees, today_ist
from utils.helpers import utcnow

logger = logging.getLogger(__name__)

MIN_VISITS = 4
MIN_TENURE_DAYS = 21
MEDIUM_RATIO, HIGH_RATIO = 1.5, 2.0
INACTIVE_DAYS = 14
RISK_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


def run_customer_analysis(db: Session, merchant_id: int, now=None) -> dict:
    now = now or utcnow()
    today = today_ist(now)
    customers = db.query(Customer).filter(Customer.merchant_id == merchant_id).all()
    names = {c.id: c.name for c in customers}
    df = load_transactions(db, merchant_id)
    df = df[(df["date"] <= today) & df["customer_id"].notna()] if not df.empty else df
    avg_basket = float(df["amount"].mean()) if not df.empty else 0.0

    records = []
    grouped = dict(tuple(df.groupby("customer_id"))) if not df.empty else {}
    for c in customers:
        g = grouped.get(c.id)
        if g is None or g.empty:
            records.append(_record(c.id, names[c.id], None, 0, 0.0, None, None, "New", "LOW"))
            continue
        visit_days = sorted(g["date"].unique())
        last_visit = pd.Timestamp(visit_days[-1])
        days_inactive = int((today - last_visit).days)
        tenure = int((today - pd.Timestamp(visit_days[0])).days)
        total = float(g["amount"].sum())
        visits = int(len(g))
        interval = None
        if len(visit_days) >= MIN_VISITS and tenure >= MIN_TENURE_DAYS:
            gaps = pd.Series(visit_days).diff().dropna().dt.days
            interval = max(float(gaps.mean()), 1.0)
            ratio = days_inactive / interval
            risk = "HIGH" if ratio > HIGH_RATIO else "MEDIUM" if ratio > MEDIUM_RATIO else "LOW"
            if risk == "LOW":
                segment = "Active"
            else:
                segment = "At Risk" if days_inactive >= INACTIVE_DAYS else "Early Warning"
        else:
            risk, segment = "LOW", "New"        # insufficient history: never "churned"
        records.append(_record(c.id, names[c.id], last_visit, visits, total, days_inactive,
                               interval, segment, risk))

    at_risk = sorted((r for r in records if r["segment"] == "At Risk"),
                     key=lambda r: (RISK_ORDER[r["risk_level"]], -r["total_spending"]))
    inactive_14 = [r for r in records if r["days_inactive"] is not None
                   and r["days_inactive"] >= INACTIVE_DAYS and r["segment"] != "New"]
    total_customers = len(records)
    seg_counts: dict[str, int] = {}
    for r in records:
        seg_counts[r["segment"]] = seg_counts.get(r["segment"], 0) + 1
    order = ["Active", "Early Warning", "At Risk", "New"]

    return {
        "merchant_id": merchant_id,
        "total_customers": total_customers,
        "active_customers": seg_counts.get("Active", 0) + seg_counts.get("New", 0)
                            + seg_counts.get("Early Warning", 0),
        "at_risk_customers": len(at_risk),
        "early_warning_customers": seg_counts.get("Early Warning", 0),
        "high_risk_customers": sum(1 for r in at_risk if r["risk_level"] == "HIGH"),
        "inactive_14_plus_days": len(inactive_14),
        "churn_risk_percentage": round(len(at_risk) / total_customers * 100, 2) if total_customers else 0.0,
        "average_basket_value": rupees(avg_basket),
        "at_risk_total_spending": rupees(sum(r["total_spending"] for r in at_risk)),
        "customer_segments": [{"segment": s, "count": seg_counts.get(s, 0)} for s in order],
        "at_risk_details": at_risk,
        "customers": records,
    }


def _record(cid, name, last_visit, visits, total, days_inactive, interval, segment, risk):
    return {
        "customer_id": cid,
        "customer_name": name,
        "last_visit": last_visit.strftime("%Y-%m-%d") if last_visit is not None else None,
        "days_inactive": days_inactive,
        "total_spending": rupees(total),
        "visit_count": visits,
        "normal_visit_interval_days": round(interval, 1) if interval else None,
        "segment": segment,
        "risk_level": risk,
    }
