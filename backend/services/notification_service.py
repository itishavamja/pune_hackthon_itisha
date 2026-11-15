"""Delivers an APPROVED campaign through the (mock) messaging provider and records the event."""
from sqlalchemy.orm import Session

from integrations import messaging_mock
from models import Campaign, DeliveryEvent
from services.errors import ConflictError


def deliver_campaign(db: Session, campaign: Campaign) -> DeliveryEvent:
    """Send an approved campaign. Does NOT commit - the caller owns the transaction.

    Guards:
      * only status == 'approved' can be delivered (draft/rejected/sent raise ConflictError);
      * the unique constraint on delivery_events.campaign_id makes a second delivery of the
        same campaign fail with IntegrityError at flush time.
    """
    if campaign.status != "approved":
        raise ConflictError(f"Only approved campaigns can be sent (this one is '{campaign.status}')")
    result = messaging_mock.send_campaign(campaign.message, campaign.target_customer_count)
    event = DeliveryEvent(campaign_id=campaign.id, merchant_id=campaign.merchant_id, channel=result.mode,
                          recipient_count=result.recipient_count, reference=result.reference,
                          status="delivered_demo")
    db.add(event)
    db.flush()
    return event
