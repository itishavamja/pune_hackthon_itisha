"""Synthetic data generator for the demo merchant.

Run from the backend folder:
    python -m scripts.seed_data            # seed (no-op if already seeded)
    python -m scripts.seed_data --reset    # wipe the demo merchant and re-seed

Story baked into the data (nothing here is returned by the API directly - the
agents must *discover* all of it from the transactions):
  * 90 days of history, busier on weekends.
  * ~150 customers in 4 groups: regulars, occasional, lapsed regulars, new.
  * 20 lapsed regulars who used to visit every 2-4 days, then stopped 14-30 days ago.
  * Remaining regulars visit less and less over the last 14 days -> sales decline.
  * 3 unusual transactions (one very large, two at odd night hours).
Fixed random seed -> reproducible. Dates are relative to "today" so the demo is
always fresh.
"""
import argparse
import logging
import random
from datetime import datetime, timedelta

import numpy as np
from sqlalchemy.orm import Session

from database import SessionLocal, init_db
from models import Customer, Merchant, Transaction
from utils.helpers import from_ist, to_ist, utcnow

logger = logging.getLogger("seed")

SEED = 42
DAYS = 90
DEMO_PHONE = "9000000001"
N_REGULAR, N_OCCASIONAL, N_LAPSED, N_NEW = 70, 45, 20, 15  # = 150 customers

FIRST = ["Aarav", "Vivaan", "Aditya", "Sai", "Arjun", "Rohan", "Kiran", "Rahul", "Amit", "Sunil",
         "Priya", "Anita", "Sneha", "Pooja", "Kavita", "Meera", "Sunita", "Neha", "Asha", "Rekha",
         "Ganesh", "Suresh", "Mahesh", "Prakash", "Deepak", "Shweta", "Swati", "Manisha", "Vijay", "Nitin"]
LAST = ["Patil", "Deshmukh", "Joshi", "Kulkarni", "Shinde", "Jadhav", "More", "Pawar", "Kale", "Gaikwad",
        "Sharma", "Verma", "Shah", "Mehta", "Bhosale", "Thakur", "Naik", "Chavan", "Kamble", "Wagh"]
PAY_MODES = ["UPI", "UPI", "UPI", "CARD", "CASH", "WALLET"]


def _paise(rupees: float) -> int:
    return int(round(rupees)) * 100


def _make_customers(rng: random.Random, today_ist: datetime):
    """Return list of dicts describing each customer's behaviour."""
    names, specs = set(), []

    def unique_name():
        while True:
            n = f"{rng.choice(FIRST)} {rng.choice(LAST)}"
            if n not in names:
                names.add(n)
                return n

    def add(kind, gap, basket, start_day, stop_day=0):
        specs.append(dict(kind=kind, name=unique_name(), gap=gap, basket=basket,
                          start_day=start_day, stop_day=stop_day))

    for _ in range(N_REGULAR):
        add("regular", rng.uniform(3, 6), rng.uniform(250, 700), rng.randint(70, 90))
    for _ in range(N_OCCASIONAL):
        add("occasional", rng.uniform(10, 18), rng.uniform(300, 900), rng.randint(60, 90))
    for _ in range(N_LAPSED):  # frequent buyers who vanished 14-30 days ago
        add("lapsed", rng.uniform(2.5, 4), rng.uniform(350, 800), rng.randint(75, 90),
            stop_day=rng.randint(15, 30))
    for _ in range(N_NEW):
        add("new", rng.uniform(4, 8), rng.uniform(200, 600), rng.randint(1, 18))
    for i, s in enumerate(specs):
        s["phone"] = f"98{i:08d}"
    return specs


def _daily_probability(spec, days_ago: int, is_weekend: bool) -> float:
    if days_ago > spec["start_day"] or days_ago < spec["stop_day"]:
        return 0.0
    p = 1.0 / spec["gap"]
    p *= 1.45 if is_weekend else 0.9           # weekend pattern
    if spec["kind"] in ("regular", "occasional"):
        if days_ago <= 7:
            p *= 0.57                          # deliberate slowdown, worst in the last week
        elif days_ago <= 14:
            p *= 0.88                          # ...starting 2 weeks ago
    return min(p, 0.95)


def _local_time(rng: random.Random, day_ist: datetime, is_weekend: bool) -> datetime:
    """Business hours 8:00-21:30 IST, with morning and evening peaks."""
    peak = rng.choice([10, 11, 18, 19, 20]) if rng.random() < 0.6 else rng.randint(8, 21)
    return day_ist.replace(hour=peak, minute=rng.randint(0, 59), second=rng.randint(0, 59))


def seed(db: Session, reset: bool = False, today: datetime | None = None) -> dict:
    """Seed the demo merchant. Safe to call repeatedly."""
    existing = db.query(Merchant).filter(Merchant.phone == DEMO_PHONE).first()
    if existing and not reset:
        n = db.query(Transaction).filter(Transaction.merchant_id == existing.id).count()
        logger.info("Demo merchant already seeded (id=%s, %s transactions) - skipping", existing.id, n)
        return {"merchant_id": existing.id, "created": False, "transactions": n}
    if existing and reset:
        _wipe(db, existing.id)

    rng = random.Random(SEED)
    nrng = np.random.default_rng(SEED)
    now_utc = today or utcnow()
    now_ist = to_ist(now_utc)
    today_ist = now_ist.replace(hour=0, minute=0, second=0, microsecond=0)

    merchant = Merchant(business_name="Shree General Store", owner_name="Ramesh Patil",
                        phone=DEMO_PHONE, created_at=now_utc - timedelta(days=DAYS))
    db.add(merchant)
    db.flush()

    specs = _make_customers(rng, today_ist)
    customers = []
    for s in specs:
        c = Customer(merchant_id=merchant.id, name=s["name"], phone=s["phone"],
                     first_seen=from_ist(today_ist - timedelta(days=s["start_day"])),
                     created_at=now_utc)
        db.add(c)
        customers.append(c)
    db.flush()

    txns = []
    for days_ago in range(DAYS, -1, -1):
        day_ist = today_ist - timedelta(days=days_ago)
        weekend = day_ist.weekday() >= 5

        def keep(t_ist):  # no transactions in the future (today is partial)
            return from_ist(t_ist) <= now_utc

        for spec, cust in zip(specs, customers):
            if rng.random() < _daily_probability(spec, days_ago, weekend):
                amt = spec["basket"] * float(nrng.lognormal(0, 0.25))
                t = _local_time(rng, day_ist, weekend)
                if keep(t):
                    txns.append((cust.id, _paise(amt), t))

        # anonymous walk-in sales; also thinner in the last 14 days
        walkins = rng.randint(6, 10) if weekend else rng.randint(3, 6)
        if days_ago <= 7:
            walkins = max(1, int(round(walkins * 0.75)))
        elif days_ago <= 14:
            walkins = max(1, int(round(walkins * 0.9)))
        for _ in range(walkins):
            t = _local_time(rng, day_ist, weekend)
            if keep(t):
                txns.append((None, _paise(float(nrng.lognormal(np.log(180), 0.5))), t))

    # --- Deliberate unusual activity (3 transactions) ---------------------------------
    victims = [c for s, c in zip(specs, customers) if s["kind"] == "regular"]
    # Kept modest in size so they do not distort weekly revenue trends.
    unusual = [
        (victims[0].id, 12_000, (today_ist - timedelta(days=22)).replace(hour=14, minute=22)),  # huge amount
        (victims[1].id, 4_000, (today_ist - timedelta(days=10)).replace(hour=3, minute=12)),     # 3 AM
        (None, 5_000, (today_ist - timedelta(days=2)).replace(hour=2, minute=47)),              # 2 AM
    ]
    for cid, rupees, t in unusual:
        txns.append((cid, _paise(rupees), t))

    txns.sort(key=lambda x: x[2])
    db.add_all([
        Transaction(merchant_id=merchant.id, customer_id=cid, amount_minor=amt, currency="INR",
                    payment_mode=rng.choice(PAY_MODES), transaction_time=from_ist(t), created_at=now_utc)
        for cid, amt, t in txns
    ])
    db.commit()
    logger.info("Seeded merchant %s: %s customers, %s transactions",
                merchant.id, len(customers), len(txns))
    return {"merchant_id": merchant.id, "created": True, "transactions": len(txns)}


def _wipe(db: Session, merchant_id: int) -> None:
    from models import (Alert, AnalysisRun, Campaign, CampaignApprovalHistory)
    camp_ids = [c.id for c in db.query(Campaign.id).filter(Campaign.merchant_id == merchant_id)]
    if camp_ids:
        db.query(CampaignApprovalHistory).filter(
            CampaignApprovalHistory.campaign_id.in_(camp_ids)).delete(synchronize_session=False)
    for model in (Campaign, Alert, Transaction, Customer, AnalysisRun):
        db.query(model).filter(model.merchant_id == merchant_id).delete(synchronize_session=False)
    db.query(Merchant).filter(Merchant.id == merchant_id).delete(synchronize_session=False)
    db.commit()


def main():
    import config
    config.setup_logging()
    parser = argparse.ArgumentParser()
    parser.add_argument("--reset", action="store_true", help="delete and re-create demo data")
    args = parser.parse_args()
    init_db()
    with SessionLocal() as db:
        print(seed(db, reset=args.reset))


if __name__ == "__main__":
    main()




