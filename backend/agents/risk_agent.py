"""Business Risk Detection Agent - statistical anomaly detection (Z-scores).

Checks (history = all days; REPORTED alerts only cover the last 30 days):
  1. Transaction amount: Z-score of log(amount). log is used because shop
     amounts are right-skewed. z >= 3.5 is unusual.
  2. Transaction time: an IST hour is "unusual" if it holds < 0.5% of the shop's
     history (data-driven, needs >= 100 transactions).
  3. Daily transaction count: Z-score vs the same day-type (weekday/weekend).
  4. Daily revenue: Z-score vs the same day-type.

Wording is deliberately neutral ("Unusual Activity Detected"): an outlier is not
proof of fraud. IsolationForest is intentionally not used - on a small shop it
would flag a fixed share of normal transactions and create false alarms.
"""
import logging
import math
from datetime import timedelta

import numpy as np
import pandas as pd
from sqlalchemy.orm import Session

from utils.calculations import load_transactions, rupees, today_ist
from utils.helpers import utcnow

logger = logging.getLogger(__name__)

LOOKBACK_DAYS = 30
AMOUNT_Z_LOW, AMOUNT_Z_MED, AMOUNT_Z_HIGH = 3.5, 4.5, 6.0
RARE_HOUR_SHARE = 0.005
MIN_TXNS = 100
DAILY_Z = 3.0
SEV_ORDER = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}


def run_risk_analysis(db: Session, merchant_id: int, now=None) -> dict:
    now = now or utcnow()
    today = today_ist(now)
    created_at = now.isoformat()
    df = load_transactions(db, merchant_id)
    df = df[df["date"] <= today] if not df.empty else df
    alerts: list[dict] = []

    if len(df) < MIN_TXNS:
        return {"merchant_id": merchant_id, "alerts": [], "alert_count": 0,
                "note": f"Need at least {MIN_TXNS} transactions for anomaly detection."}

    recent = df[df["date"] > today - timedelta(days=LOOKBACK_DAYS)]

    # ---- 1 & 2: per-transaction amount and time ----
    log_amt = np.log(df["amount"].clip(lower=1))
    mu, sd = float(log_amt.mean()), float(log_amt.std(ddof=0)) or 1.0
    typical = math.exp(mu)
    hour_share = df["hour"].value_counts(normalize=True)
    usual_hours = sorted(h for h, s in hour_share.items() if s >= RARE_HOUR_SHARE)
    usual_txt = f"{min(usual_hours):02d}:00-{max(usual_hours):02d}:59" if usual_hours else "n/a"

    for _, r in recent.iterrows():
        z = (math.log(max(r["amount"], 1)) - mu) / sd
        odd_amount = z >= AMOUNT_Z_LOW
        odd_time = hour_share.get(int(r["hour"]), 0.0) < RARE_HOUR_SHARE
        if not (odd_amount or odd_time):
            continue
        reasons, sev = [], "LOW"
        if odd_amount:
            sev = "HIGH" if z >= AMOUNT_Z_HIGH else "MEDIUM" if z >= AMOUNT_Z_MED else "LOW"
            reasons.append(f"amount Rs {r['amount']:,.0f} is far above the usual ~Rs {typical:,.0f} "
                           f"(z-score {z:.1f})")
        if odd_time:
            reasons.append(f"it happened at {r['ts'].strftime('%H:%M')}, outside your usual hours")
            sev = "HIGH" if odd_amount else "MEDIUM"
        alerts.append({
            "alert_type": "unusual_transaction", "severity": sev,
            "title": "Unusual Activity Detected",
            "description": f"On {r['ts'].strftime('%d %b')}: " + " and ".join(reasons) +
                           ". Please review this transaction.",
            "transaction_id": int(r["id"]),
            "detected_value": rupees(r["amount"]) if odd_amount else r["ts"].strftime("%H:%M"),
            "expected_value": rupees(typical) if odd_amount else usual_txt,
            "created_at": created_at,
        })

    # ---- 3 & 4: daily counts / revenue vs same day-type ----
    daily = df[df["date"] < today].groupby("date").agg(count=("id", "size"), revenue=("amount", "sum"))
    daily = daily.reindex(pd.date_range(daily.index.min(), today - timedelta(days=1)), fill_value=0)
    daily["weekend"] = daily.index.dayofweek >= 5
    if len(daily) >= 28:
        for metric, label, a_type in (("count", "transactions", "abnormal_transaction_count"),
                                      ("revenue", "revenue", "unusual_revenue_change")):
            for d in daily.index[-14:]:
                peers = daily[(daily["weekend"] == daily.loc[d, "weekend"]) & (daily.index != d)][metric]
                m, s = float(peers.mean()), float(peers.std(ddof=0))
                if s == 0:
                    continue
                z = (float(daily.loc[d, metric]) - m) / s
                if abs(z) >= DAILY_Z:
                    up = z > 0
                    fmt = (lambda v: f"Rs {v:,.0f}") if metric == "revenue" else (lambda v: f"{v:.0f}")
                    alerts.append({
                        "alert_type": a_type,
                        "severity": "MEDIUM" if abs(z) >= 4 else "LOW",
                        "title": f"Unusual Activity Detected: {'high' if up else 'low'} daily {label}",
                        "description": f"On {d.strftime('%d %b')} daily {label} were {fmt(daily.loc[d, metric])}, "
                                       f"versus a typical {fmt(m)} for this type of day (z-score {z:.1f}).",
                        "transaction_id": None,
                        "detected_value": rupees(daily.loc[d, metric]),
                        "expected_value": rupees(m),
                        "created_at": created_at,
                    })

    alerts.sort(key=lambda a: (SEV_ORDER[a["severity"]], a["created_at"]))
    return {"merchant_id": merchant_id, "alerts": alerts, "alert_count": len(alerts), "note": None}
