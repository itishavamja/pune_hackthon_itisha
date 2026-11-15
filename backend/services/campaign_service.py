"""Campaign persistence (Phase 5). The approval workflow is added in Phase 7."""
import logging
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from integrations import messaging_mock
from integrations.messaging_mock import MessagingError
from models import Campaign, CampaignApprovalHistory
from services import notification_service
from services.errors import ConflictError, DeliveryFailed, NotFoundError, ValidationFailed
from utils.helpers import utcnow

logger = logging.getLogger(__name__)


def save_drafts(db: Session, merchant_id: int, run_id: int, drafts: list[dict]) -> list[Campaign]:
    """Persist generated drafts without committing (the caller owns the transaction).

    If a DRAFT of the same type and language already exists it is kept untouched (the
    merchant may have edited it) instead of creating a duplicate.
    """
    saved: list[Campaign] = []
    for d in drafts:
        existing = (db.query(Campaign)
                    .filter(Campaign.merchant_id == merchant_id, Campaign.status == "draft",
                            Campaign.campaign_type == d["campaign_type"],
                            Campaign.language == d["language"])
                    .order_by(Campaign.id.desc()).first())
        if existing:
            saved.append(existing)
            continue
        c = Campaign(merchant_id=merchant_id, title=d["campaign_title"], segment=d["target_segment"],
                     language=d["language"], message=d["message"], campaign_type=d["campaign_type"],
                     objective=d["objective"], reason=d["reason_for_recommendation"],
                     target_customer_count=d["target_customer_count"], status="draft",
                     analysis_run_id=run_id)
        db.add(c)
        db.flush()
        db.add(CampaignApprovalHistory(campaign_id=c.id, action="created", previous_status=None,
                                       new_status="draft"))
        saved.append(c)
    return saved


def get_owned(db: Session, merchant_id: int, campaign_id: int) -> Campaign:
    """Merchant-level isolation: another merchant's campaign looks like 'not found'."""
    c = db.query(Campaign).filter(Campaign.id == campaign_id, Campaign.merchant_id == merchant_id).first()
    if c is None:
        raise NotFoundError(f"Campaign {campaign_id} not found")
    return c


def list_campaigns(db: Session, merchant_id: int, limit: int, offset: int, status: Optional[str]) -> dict:
    q = db.query(Campaign).filter(Campaign.merchant_id == merchant_id)
    if status:
        q = q.filter(Campaign.status == status)
    total = q.count()
    rows = q.order_by(Campaign.id.desc()).offset(offset).limit(limit).all()
    return {"campaigns": rows, "pagination": {"total": total, "limit": limit, "offset": offset}}


def update_draft(db: Session, merchant_id: int, campaign_id: int,
                 title: Optional[str], message: Optional[str]) -> Campaign:
    """Edit wording - allowed ONLY while the campaign is a draft."""
    if title is None and message is None:
        raise ValidationFailed("Provide a new title and/or message")
    try:
        c = get_owned(db, merchant_id, campaign_id)
        if c.status != "draft":
            raise ConflictError(f"Only draft campaigns can be edited (this one is '{c.status}')")
        if title is not None:
            c.title = title.strip()
        if message is not None:
            c.message = message.strip()
        db.add(CampaignApprovalHistory(campaign_id=c.id, action="edited", previous_status="draft",
                                       new_status="draft"))
        db.commit()
        return c
    except Exception:
        db.rollback()
        raise


# ---------------------------------------------------------------- approval workflow
#   draft -> approved -> sent        draft -> rejected
# Every transition is an atomic conditional UPDATE ("... WHERE status = <expected>") so two
# simultaneous requests cannot both succeed, and each one writes a history row.

def _transition(db: Session, campaign_id: int, expected: str, values: dict) -> bool:
    n = (db.query(Campaign).filter(Campaign.id == campaign_id, Campaign.status == expected)
         .update(values, synchronize_session=False))
    return n == 1


def _history(db: Session, campaign_id: int, action: str, prev: Optional[str], new: str) -> None:
    db.add(CampaignApprovalHistory(campaign_id=campaign_id, action=action, previous_status=prev,
                                   new_status=new))


def _result(c: Campaign, message: str, already: bool) -> dict:
    return {"campaign": c, "message": message, "already_processed": already}


def approve_campaign(db: Session, merchant_id: int, campaign_id: int) -> dict:
    """Approve a draft and send it through the mock provider (Demo Mode).

    Safe to call repeatedly: an already-sent campaign is returned as-is (no second send).
    A rejected campaign can never be approved or sent.
    """
    try:
        c = get_owned(db, merchant_id, campaign_id)
        if c.status == "rejected":
            raise ConflictError("Rejected campaigns cannot be approved or sent")
        if c.status == "sent":
            return _result(c, "This campaign was already sent (Demo Mode). No duplicate message was sent.", True)

        if c.status == "draft":
            if not _transition(db, c.id, "draft", {"status": "approved", "approved_at": utcnow()}):
                db.rollback()                      # lost a race: re-read the new state and re-decide
                return approve_campaign(db, merchant_id, campaign_id)
            _history(db, c.id, "approved", "draft", "approved")
            db.commit()                            # approval is durable even if sending then fails
            db.refresh(c)
        return _send(db, c)
    except Exception:
        db.rollback()
        raise


def _send(db: Session, c: Campaign) -> dict:
    already = False
    try:
        notification_service.deliver_campaign(db, c)
    except MessagingError as exc:
        db.rollback()
        _history(db, c.id, "send_failed", "approved", "approved")
        db.commit()
        logger.warning("Delivery failed for campaign %s: %s", c.id, exc)
        raise DeliveryFailed("Sending failed. The campaign is approved but not sent - approve again to retry.")
    except IntegrityError:
        db.rollback()                              # another request already delivered it
        already = True
    if _transition(db, c.id, "approved", {"status": "sent", "sent_at": utcnow()}):
        _history(db, c.id, "sent", "approved", "sent")
    db.commit()
    db.refresh(c)
    msg = ("This campaign was already sent (Demo Mode). No duplicate message was sent." if already
           else messaging_mock.DEMO_SUCCESS_MESSAGE)
    return _result(c, msg, already)


def reject_campaign(db: Session, merchant_id: int, campaign_id: int) -> dict:
    """Reject a draft. Repeating the request is harmless; approved/sent campaigns cannot be rejected."""
    try:
        c = get_owned(db, merchant_id, campaign_id)
        if c.status == "rejected":
            return _result(c, "This campaign was already rejected.", True)
        if c.status != "draft":
            raise ConflictError(f"Only draft campaigns can be rejected (this one is '{c.status}')")
        if not _transition(db, c.id, "draft", {"status": "rejected"}):
            db.rollback()
            return reject_campaign(db, merchant_id, campaign_id)
        _history(db, c.id, "rejected", "draft", "rejected")
        db.commit()
        db.refresh(c)
        return _result(c, "Campaign rejected. It will not be sent.", False)
    except Exception:
        db.rollback()
        raise


def campaign_to_dict(c: Campaign) -> dict:
    return {"id": c.id, "title": c.title, "campaign_type": c.campaign_type, "segment": c.segment,
            "target_customer_count": c.target_customer_count, "language": c.language,
            "message": c.message, "objective": c.objective, "reason": c.reason, "status": c.status,
            "created_at": c.created_at.isoformat()}
