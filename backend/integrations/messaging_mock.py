"""MOCK messaging provider - DEMO MODE ONLY.

No WhatsApp/SMS/network call is made here and no real message is ever sent. It only
pretends to deliver so the approval workflow can be demonstrated end to end.
"""
import uuid
from dataclasses import dataclass

DEMO_SUCCESS_MESSAGE = "Campaign sent successfully (Demo Mode)."


class MessagingError(Exception):
    """The (mock) provider could not deliver the campaign."""


@dataclass
class DeliveryResult:
    recipient_count: int
    reference: str
    mode: str = "demo"


def send_campaign(message: str, recipient_count: int) -> DeliveryResult:
    if not message or not message.strip():
        raise MessagingError("Cannot send an empty message")
    return DeliveryResult(recipient_count=recipient_count, reference=f"DEMO-{uuid.uuid4().hex[:10].upper()}")
