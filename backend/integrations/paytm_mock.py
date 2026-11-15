"""MOCK of a Paytm-style transaction feed - DEMO ONLY.

This is NOT a Paytm integration: no Paytm API, credentials or network call is used or implied.
It simply shows where a real payments feed would plug in by presenting the merchant's locally
stored (synthetic) transactions in a payment-provider-like shape. The analysis agents read the
same data directly from the database.
"""
from sqlalchemy.orm import Session

from models import Transaction

PROVIDER = "MOCK_PAYMENTS_FEED (not Paytm)"


def fetch_recent_transactions(db: Session, merchant_id: int, limit: int = 20) -> list[dict]:
    rows = (db.query(Transaction).filter(Transaction.merchant_id == merchant_id)
            .order_by(Transaction.transaction_time.desc()).limit(limit).all())
    return [{"provider": PROVIDER, "txn_id": f"MOCK-{t.id}", "amount_inr": round(t.amount_minor / 100, 2),
             "currency": t.currency, "payment_mode": t.payment_mode,
             "timestamp_utc": t.transaction_time.isoformat()} for t in rows]
