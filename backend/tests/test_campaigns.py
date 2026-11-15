"""Campaign generation + orchestrator behaviour (approval workflow tests come in Phase 7)."""
import json

import pytest

import config
from integrations import sarvam_client as sc
from models import Alert, AnalysisRun, Campaign
from services import orchestrator
from tests.conftest import NOW


def test_generation_works_when_sarvam_unavailable(db, seeded):
    r = orchestrator.run_analysis(db, seeded, language="Hindi", now=NOW)
    assert r["ai_explanation"]["source"] == "fallback"
    assert any("AI service unavailable" in w for w in r["warnings"])
    # deterministic analysis is fully present
    assert r["sales_insights"]["sales_status"] == "declining"
    assert r["customer_insights"]["at_risk_customers"] > 0
    assert r["business_risk_insights"]["alert_count"] >= 1
    drafts = r["campaign_drafts"]
    assert drafts and all(d["status"] == "draft" for d in drafts)
    assert all(d["language"] == "Hindi" and d["message"] for d in drafts)


def test_campaign_numbers_come_from_analysis_not_llm(db, seeded, monkeypatch):
    monkeypatch.setattr(config, "SARVAM_API_KEY", "test-key")
    sc.reset_client()
    llm_reply = {
        "business_explanation": "Sales are down and regular customers are visiting less.",
        "campaigns": [{"title": f"T{i}", "message": f"M{i}", "target_segment": "LLM INVENTED SEGMENT",
                       "objective": "x"} for i in range(3)]}
    monkeypatch.setattr(sc, "chat_json", lambda *a, **k: llm_reply)
    r = orchestrator.run_analysis(db, seeded, now=NOW)
    assert r["ai_explanation"]["source"] == "ai"
    win = next(d for d in r["campaign_drafts"] if d["campaign_type"] == "win_back")
    assert win["target_customer_count"] == r["customer_insights"]["at_risk_customers"]
    assert win["segment"] != "LLM INVENTED SEGMENT"
    assert win["title"].startswith("T")                      # wording does come from the LLM
    assert str(r["customer_insights"]["at_risk_customers"]) in win["reason"]


def test_one_failing_agent_does_not_crash_analysis(db, seeded, monkeypatch):
    def boom(*a, **k):
        raise RuntimeError("risk engine exploded")
    monkeypatch.setattr(orchestrator, "run_risk_analysis", boom)
    r = orchestrator.run_analysis(db, seeded, now=NOW)
    assert r["business_risk_insights"]["alerts"] == []
    assert r["business_risk_insights"]["error"]
    assert any("Risk analysis is unavailable" in w for w in r["warnings"])
    assert r["sales_insights"]["sales_status"] == "declining"   # others still work
    assert r["campaign_drafts"]


def test_sarvam_api_error_does_not_crash_analysis(db, seeded, monkeypatch):
    monkeypatch.setattr(config, "SARVAM_API_KEY", "test-key")
    sc.reset_client()

    def fail(*a, **k):
        raise sc.SarvamUnavailable("timeout")
    monkeypatch.setattr(sc, "chat_json", fail)
    r = orchestrator.run_analysis(db, seeded, now=NOW)
    assert r["ai_explanation"]["source"] == "fallback" and r["campaign_drafts"]


def test_same_idempotency_key_returns_same_run(db, seeded):
    a = orchestrator.run_analysis(db, seeded, idempotency_key="abc", now=NOW)
    b = orchestrator.run_analysis(db, seeded, idempotency_key="abc", now=NOW)
    assert a["analysis_run_id"] == b["analysis_run_id"] and b["replayed"] is True
    assert db.query(AnalysisRun).count() == 1
    assert [c["id"] for c in a["campaign_drafts"]] == [c["id"] for c in b["campaign_drafts"]]


def test_rerun_does_not_duplicate_drafts_or_alerts(db, seeded):
    a = orchestrator.run_analysis(db, seeded, now=NOW)
    n_campaigns, n_alerts = db.query(Campaign).count(), db.query(Alert).count()
    b = orchestrator.run_analysis(db, seeded, now=NOW)
    assert a["analysis_run_id"] != b["analysis_run_id"]
    assert db.query(Campaign).count() == n_campaigns
    assert db.query(Alert).count() == n_alerts


def test_edited_draft_survives_rerun(db, seeded):
    a = orchestrator.run_analysis(db, seeded, now=NOW)
    c = db.get(Campaign, a["campaign_drafts"][0]["id"])
    c.message = "My own edited words"
    db.commit()
    orchestrator.run_analysis(db, seeded, now=NOW)
    assert db.get(Campaign, c.id).message == "My own edited words"


def test_unknown_merchant_raises(db):
    with pytest.raises(orchestrator.MerchantNotFound):
        orchestrator.run_analysis(db, 9999, now=NOW)


def test_nothing_is_sent_automatically(db, seeded):
    orchestrator.run_analysis(db, seeded, now=NOW)
    assert {c.status for c in db.query(Campaign).all()} == {"draft"}
    assert all(c.sent_at is None for c in db.query(Campaign).all())


def test_result_is_json_serialisable(db, seeded):
    r = orchestrator.run_analysis(db, seeded, now=NOW)
    json.dumps(r)


# ------------------------------------------------------------------ approval workflow
from integrations import messaging_mock  # noqa: E402
from models import CampaignApprovalHistory, DeliveryEvent  # noqa: E402
from services import campaign_service, notification_service  # noqa: E402
from services.errors import ConflictError, DeliveryFailed, NotFoundError, ValidationFailed  # noqa: E402


def _draft(db, merchant_id):
    r = orchestrator.run_analysis(db, merchant_id, now=NOW)
    return db.get(Campaign, r["campaign_drafts"][0]["id"])


def _actions(db, campaign_id):
    return [h.action for h in db.query(CampaignApprovalHistory)
            .filter_by(campaign_id=campaign_id).order_by(CampaignApprovalHistory.id)]


def test_approve_sends_in_demo_mode(db, seeded):
    c = _draft(db, seeded)
    res = campaign_service.approve_campaign(db, seeded, c.id)
    assert res["message"] == "Campaign sent successfully (Demo Mode)."
    assert res["already_processed"] is False
    assert c.status == "sent" and c.approved_at and c.sent_at
    ev = db.query(DeliveryEvent).one()
    assert ev.campaign_id == c.id and ev.channel == "demo"
    assert ev.recipient_count == c.target_customer_count
    assert _actions(db, c.id) == ["created", "approved", "sent"]


def test_reject_draft(db, seeded):
    c = _draft(db, seeded)
    res = campaign_service.reject_campaign(db, seeded, c.id)
    assert c.status == "rejected" and not res["already_processed"]
    assert _actions(db, c.id) == ["created", "rejected"]
    again = campaign_service.reject_campaign(db, seeded, c.id)          # harmless repeat
    assert again["already_processed"] and _actions(db, c.id) == ["created", "rejected"]


def test_rejected_campaign_can_never_be_approved_or_sent(db, seeded):
    c = _draft(db, seeded)
    campaign_service.reject_campaign(db, seeded, c.id)
    with pytest.raises(ConflictError):
        campaign_service.approve_campaign(db, seeded, c.id)
    with pytest.raises(ConflictError):
        notification_service.deliver_campaign(db, c)
    assert db.query(DeliveryEvent).count() == 0 and c.status == "rejected"


def test_unapproved_draft_cannot_be_sent(db, seeded):
    c = _draft(db, seeded)
    with pytest.raises(ConflictError):
        notification_service.deliver_campaign(db, c)
    assert db.query(DeliveryEvent).count() == 0 and c.status == "draft" and c.sent_at is None


def test_edit_draft_then_locked_after_approval(db, seeded):
    c = _draft(db, seeded)
    campaign_service.update_draft(db, seeded, c.id, title="New title", message="New words")
    assert (c.title, c.message) == ("New title", "New words")
    campaign_service.approve_campaign(db, seeded, c.id)
    assert c.message == "New words"                      # the edited text is what was sent
    with pytest.raises(ConflictError):
        campaign_service.update_draft(db, seeded, c.id, title=None, message="too late")
    with pytest.raises(ValidationFailed):
        campaign_service.update_draft(db, seeded, _draft(db, seeded).id, title=None, message=None)


def test_sent_campaign_cannot_be_rejected(db, seeded):
    c = _draft(db, seeded)
    campaign_service.approve_campaign(db, seeded, c.id)
    with pytest.raises(ConflictError):
        campaign_service.reject_campaign(db, seeded, c.id)
    assert c.status == "sent"


def test_failed_send_leaves_campaign_approved_and_retry_works(db, seeded, monkeypatch):
    c = _draft(db, seeded)
    state = {"fail": True}
    real = messaging_mock.send_campaign

    def flaky(message, count):
        if state["fail"]:
            raise messaging_mock.MessagingError("provider down")
        return real(message, count)
    monkeypatch.setattr(messaging_mock, "send_campaign", flaky)

    with pytest.raises(DeliveryFailed):
        campaign_service.approve_campaign(db, seeded, c.id)
    assert c.status == "approved" and c.sent_at is None and db.query(DeliveryEvent).count() == 0
    assert _actions(db, c.id) == ["created", "approved", "send_failed"]

    state["fail"] = False
    res = campaign_service.approve_campaign(db, seeded, c.id)            # retry
    assert c.status == "sent" and res["message"] == "Campaign sent successfully (Demo Mode)."
    assert db.query(DeliveryEvent).count() == 1


def test_other_merchant_cannot_approve(db, seeded):
    from models import Merchant
    other = Merchant(business_name="O", owner_name="O", phone="9222222222")
    db.add(other)
    db.commit()
    c = _draft(db, seeded)
    with pytest.raises(NotFoundError):
        campaign_service.approve_campaign(db, other.id, c.id)
    assert c.status == "draft"
