"""Shared numeric helpers used by all analysis agents."""
from typing import Optional

import pandas as pd
from sqlalchemy.orm import Session

from models import Transaction
from utils.helpers import to_ist


def load_transactions(db: Session, merchant_id: int) -> pd.DataFrame:
    """All transactions of ONE merchant (merchant isolation happens here).

    Columns: id, customer_id, amount (rupees), amount_minor (paise),
             ts (IST datetime), date (IST day, midnight), hour (IST hour).
    """
    rows = (db.query(Transaction.id, Transaction.customer_id, Transaction.amount_minor,
                     Transaction.transaction_time)
            .filter(Transaction.merchant_id == merchant_id)
            .order_by(Transaction.transaction_time).all())
    df = pd.DataFrame(rows, columns=["id", "customer_id", "amount_minor", "transaction_time"])
    if df.empty:
        for c in ("ts", "date", "hour", "amount"):
            df[c] = pd.Series(dtype="float64")
        return df
    df["amount"] = df["amount_minor"] / 100.0
    df["ts"] = df["transaction_time"].apply(to_ist)
    df["ts"] = pd.to_datetime(df["ts"])
    df["date"] = df["ts"].dt.normalize()
    df["hour"] = df["ts"].dt.hour
    return df


def today_ist(now) -> pd.Timestamp:
    return pd.Timestamp(to_ist(now)).normalize()


def pct_change(new: float, old: float) -> Optional[float]:
    """Percentage change from old to new; None when old is 0/unknown."""
    if old is None or old == 0:
        return None
    return round((new - old) / old * 100.0, 2)


def rupees(x) -> float:
    return round(float(x), 2)
