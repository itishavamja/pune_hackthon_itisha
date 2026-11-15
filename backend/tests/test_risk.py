from agents.risk_agent import run_risk_analysis
from tests.conftest import NOW, add_txn, build_daily_sales


def _normal_history(db, merchant):
    build_daily_sales(db, merchant, lambda d: 300, days=45, per_day=8)


def test_unusually_large_amount_detected(db, merchant):
    _normal_history(db, merchant)
    add_txn(db, merchant, 3, 40_000, hour=13)
    db.commit()
    r = run_risk_analysis(db, merchant.id, now=NOW)
    big = [a for a in r["alerts"] if a["alert_type"] == "unusual_transaction"]
    assert len(big) == 1
    assert big[0]["severity"] == "HIGH"
    assert big[0]["detected_value"] == 40_000.0
    assert big[0]["transaction_id"] is not None


def test_unusual_hour_detected(db, merchant):
    _normal_history(db, merchant)
    add_txn(db, merchant, 2, 300, hour=3, minute=10)
    db.commit()
    r = run_risk_analysis(db, merchant.id, now=NOW)
    odd = [a for a in r["alerts"] if a["alert_type"] == "unusual_transaction"]
    assert len(odd) == 1
    assert "03:10" in odd[0]["description"]


def test_clean_history_has_no_transaction_alerts(db, merchant):
    _normal_history(db, merchant)
    r = run_risk_analysis(db, merchant.id, now=NOW)
    assert not [a for a in r["alerts"] if a["alert_type"] == "unusual_transaction"]


def test_wording_never_claims_fraud(db, merchant):
    _normal_history(db, merchant)
    add_txn(db, merchant, 3, 40_000, hour=2)
    db.commit()
    r = run_risk_analysis(db, merchant.id, now=NOW)
    text = " ".join(a["title"] + " " + a["description"] for a in r["alerts"]).lower()
    assert "fraud" not in text
    assert "unusual activity detected" in text


def test_too_little_data_returns_note(db, merchant):
    add_txn(db, merchant, 1, 100)
    db.commit()
    r = run_risk_analysis(db, merchant.id, now=NOW)
    assert r["alerts"] == [] and r["note"]
