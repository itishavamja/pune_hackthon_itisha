from agents.customer_agent import run_customer_analysis
from tests.conftest import NOW, add_customer, add_txn


def _visit_every(db, merchant, cust, gap, start_days_ago, stop_days_ago):
    d = start_days_ago
    while d >= stop_days_ago:
        add_txn(db, merchant, d, 400, customer=cust)
        d -= gap
    db.commit()


def test_lapsed_regular_is_flagged_high_risk(db, merchant):
    lapsed = add_customer(db, merchant, "Lapsed Regular", "9100000001")
    active = add_customer(db, merchant, "Active Regular", "9100000002")
    _visit_every(db, merchant, lapsed, gap=3, start_days_ago=80, stop_days_ago=21)   # silent ~20 days
    _visit_every(db, merchant, active, gap=3, start_days_ago=80, stop_days_ago=1)
    r = run_customer_analysis(db, merchant.id, now=NOW)
    names = {c["customer_name"]: c for c in r["at_risk_details"]}
    assert "Lapsed Regular" in names
    assert names["Lapsed Regular"]["risk_level"] == "HIGH"
    assert names["Lapsed Regular"]["days_inactive"] >= 14
    assert "Active Regular" not in names
    assert r["at_risk_customers"] == 1
    assert r["total_customers"] == 2
    assert r["churn_risk_percentage"] == 50.0


def test_new_customer_never_called_churned(db, merchant):
    new = add_customer(db, merchant, "Newbie", "9100000003", first_seen_days_ago=12)
    add_txn(db, merchant, 12, 300, customer=new)
    add_txn(db, merchant, 11, 300, customer=new)    # 2 visits, then 11 quiet days
    db.commit()
    r = run_customer_analysis(db, merchant.id, now=NOW)
    rec = next(c for c in r["customers"] if c["customer_name"] == "Newbie")
    assert rec["segment"] == "New"
    assert rec["risk_level"] == "LOW"
    assert r["at_risk_customers"] == 0


def test_long_gap_new_customer_with_few_visits_not_flagged(db, merchant):
    c = add_customer(db, merchant, "One Timer", "9100000004")
    add_txn(db, merchant, 40, 250, customer=c)      # a single purchase 40 days ago
    db.commit()
    r = run_customer_analysis(db, merchant.id, now=NOW)
    assert r["at_risk_customers"] == 0


def test_overdue_but_recent_goes_to_early_warning(db, merchant):
    c = add_customer(db, merchant, "Slowing Down", "9100000005")
    _visit_every(db, merchant, c, gap=2, start_days_ago=60, stop_days_ago=8)   # silent 8 days: 4x interval
    r = run_customer_analysis(db, merchant.id, now=NOW)
    rec = next(x for x in r["customers"] if x["customer_name"] == "Slowing Down")
    assert rec["segment"] == "Early Warning"
    assert r["at_risk_customers"] == 0          # not yet away 14+ days
    assert r["early_warning_customers"] == 1


def test_phone_numbers_not_exposed(db, merchant):
    c = add_customer(db, merchant, "Private Person", "9199999999")
    _visit_every(db, merchant, c, gap=3, start_days_ago=60, stop_days_ago=20)
    r = run_customer_analysis(db, merchant.id, now=NOW)
    assert "9199999999" not in str(r)
