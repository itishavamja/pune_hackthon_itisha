"""Idempotency: duplicate approvals, repeated analysis, repeated seeding."""
from models import Campaign, CampaignApprovalHistory, Customer, DeliveryEvent, Merchant, Transaction
from scripts.seed_data import seed
from services import campaign_service, orchestrator
from tests.conftest import NOW


def _draft(db, merchant_id):
    r = orchestrator.run_analysis(db, merchant_id, now=NOW)
    return db.get(Campaign, r["campaign_drafts"][0]["id"])


def test_duplicate_approval_requests_send_only_once(db, seeded):
    c = _draft(db, seeded)
    first = campaign_service.approve_campaign(db, seeded, c.id)
    second = campaign_service.approve_campaign(db, seeded, c.id)
    third = campaign_service.approve_campaign(db, seeded, c.id)
    assert first["already_processed"] is False
    assert second["already_processed"] and third["already_processed"]
    assert "No duplicate message was sent" in second["message"]
    assert db.query(DeliveryEvent).filter_by(campaign_id=c.id).count() == 1
    actions = [h.action for h in db.query(CampaignApprovalHistory).filter_by(campaign_id=c.id)]
    assert actions.count("approved") == 1 and actions.count("sent") == 1


def test_race_where_another_request_already_delivered(db, seeded):
    """Simulates a concurrent request: the delivery record exists but status is still 'approved'."""
    c = _draft(db, seeded)
    c.status = "approved"
    db.add(DeliveryEvent(campaign_id=c.id, merchant_id=seeded, channel="demo", recipient_count=1,
                         reference="DEMO-OTHER"))
    db.commit()
    res = campaign_service.approve_campaign(db, seeded, c.id)
    assert res["already_processed"] is True
    assert c.status == "sent"
    assert db.query(DeliveryEvent).filter_by(campaign_id=c.id).count() == 1     # no second send


def test_database_itself_refuses_a_second_delivery(db, seeded):
    import pytest
    from sqlalchemy.exc import IntegrityError
    c = _draft(db, seeded)
    db.add(DeliveryEvent(campaign_id=c.id, merchant_id=seeded, channel="demo", recipient_count=1, reference="A"))
    db.commit()
    db.add(DeliveryEvent(campaign_id=c.id, merchant_id=seeded, channel="demo", recipient_count=1, reference="B"))
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()


def test_repeated_analysis_with_same_key_is_not_reprocessed(db, seeded):
    a = orchestrator.run_analysis(db, seeded, idempotency_key="same", now=NOW)
    n = db.query(Campaign).count()
    b = orchestrator.run_analysis(db, seeded, idempotency_key="same", now=NOW)
    assert b["replayed"] and a["analysis_run_id"] == b["analysis_run_id"]
    assert db.query(Campaign).count() == n


def _counts(db):
    return (db.query(Merchant).count(), db.query(Customer).count(), db.query(Transaction).count())


def test_repeated_seed_does_not_duplicate_data(db):
    first = seed(db, today=NOW)
    counts = _counts(db)
    second = seed(db, today=NOW)
    third = seed(db, today=NOW)
    assert first["created"] is True and second["created"] is False and third["created"] is False
    assert _counts(db) == counts == (1, 150, counts[2])
    phones = [p for (p,) in db.query(Customer.phone).all()]
    assert len(phones) == len(set(phones))                     # no duplicate customers


def test_seed_reset_is_reproducible(db):
    seed(db, today=NOW)
    before = _counts(db)
    seed(db, reset=True, today=NOW)
    assert _counts(db) == before                               # fixed random seed -> identical data
