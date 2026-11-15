from agents.sales_agent import run_sales_analysis
from tests.conftest import NOW, add_txn, build_daily_sales


def test_declining_sales_raises_alert(db, merchant):
    # Steady ~Rs 300/txn, then the last 7 days drop to Rs 200/txn (about -33%).
    build_daily_sales(db, merchant, lambda d: 200 if d <= 7 else 300)
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["sales_status"] == "declining"
    assert r["revenue_change_percentage"] < -15
    assert r["alert_message"]
    assert r["method"] == "holt_winters_exponential_smoothing"
    assert len(r["forecast_sales"]) == 7
    assert abs(r["predicted_revenue"] - sum(f["revenue"] for f in r["forecast_sales"])) < 0.2


def test_stable_sales_no_alert(db, merchant):
    build_daily_sales(db, merchant, lambda d: 300)
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["sales_status"] == "stable"
    assert abs(r["revenue_change_percentage"]) < 1
    assert r["alert_message"] is None


def test_numbers_come_from_database(db, merchant):
    build_daily_sales(db, merchant, lambda d: 100, days=30, per_day=2)   # 2 txns of 100/105
    add_txn(db, merchant, 0, 777, hour=9)                                 # today's revenue
    db.commit()
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["today_revenue"] == 777.0
    # each day has two transactions: Rs 100 and Rs 105 -> 205/day * 7 days
    assert r["last_7_days_revenue"] == 1435.0


def test_short_history_uses_documented_fallback(db, merchant):
    build_daily_sales(db, merchant, lambda d: 300, days=10)
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["method"] == "weekday_moving_average"
    assert len(r["forecast_sales"]) == 7


def test_no_transactions_does_not_crash(db, merchant):
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["sales_status"] == "insufficient_data"


def test_merchant_isolation(db, merchant):
    from models import Merchant
    other = Merchant(business_name="Other", owner_name="X", phone="9000000098")
    db.add(other)
    db.commit()
    build_daily_sales(db, other, lambda d: 500)
    r = run_sales_analysis(db, merchant.id, now=NOW)
    assert r["sales_status"] == "insufficient_data"
