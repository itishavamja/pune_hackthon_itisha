"""Shared test fixtures: isolated in-memory DB + small dataset builders."""
import os
import sys
from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import Base  # noqa: E402
import models  # noqa: E402,F401
from models import Customer, Merchant, Transaction  # noqa: E402
from utils.helpers import from_ist  # noqa: E402

# Fixed "now": 2026-06-15 12:00 UTC (= 17:30 IST). A Monday.
NOW = datetime(2026, 6, 15, 12, 0, 0)
TODAY_IST = datetime(2026, 6, 15)


@pytest.fixture(autouse=True)
def _never_call_real_sarvam(monkeypatch):
    """Tests must never hit the real API, even if a real key is in .env."""
    import config
    from integrations import sarvam_client
    monkeypatch.setattr(config, "SARVAM_API_KEY", "")
    sarvam_client.reset_client()


@pytest.fixture()
def seeded(db):
    """The full demo dataset, generated against the fixed test clock."""
    from scripts.seed_data import seed
    info = seed(db, today=NOW)
    return info["merchant_id"]


@pytest.fixture()
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine, expire_on_commit=False)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture()
def merchant(db):
    m = Merchant(business_name="Test Store", owner_name="Owner", phone="9000000099")
    db.add(m)
    db.commit()
    return m


def add_customer(db, merchant, name, phone, first_seen_days_ago=90):
    c = Customer(merchant_id=merchant.id, name=name, phone=phone,
                 first_seen=from_ist(TODAY_IST - timedelta(days=first_seen_days_ago)))
    db.add(c)
    db.commit()
    return c


def add_txn(db, merchant, days_ago, rupees, hour=11, minute=0, customer=None):
    t_ist = TODAY_IST - timedelta(days=days_ago) + timedelta(hours=hour, minutes=minute)
    db.add(Transaction(merchant_id=merchant.id, customer_id=customer.id if customer else None,
                       amount_minor=int(rupees * 100), payment_mode="UPI",
                       transaction_time=from_ist(t_ist)))


def build_daily_sales(db, merchant, daily_fn, days=60, per_day=10):
    """Create `per_day` transactions per day. daily_fn(days_ago) -> amount each (rupees)."""
    for d in range(days, 0, -1):          # days_ago 60..1 (completed days only)
        for i in range(per_day):
            add_txn(db, merchant, d, daily_fn(d) + (i % 3) * 5, hour=9 + i)
    db.commit()
