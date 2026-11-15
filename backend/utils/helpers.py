"""Small shared helpers (time handling, money formatting)."""
from datetime import datetime, timedelta, timezone

IST_OFFSET = timedelta(hours=5, minutes=30)


def utcnow() -> datetime:
    """Naive UTC 'now' (the project stores all timestamps as naive UTC)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def to_ist(dt_utc: datetime) -> datetime:
    """Convert a naive-UTC datetime to naive IST (merchant's local time)."""
    return dt_utc + IST_OFFSET


def from_ist(dt_ist: datetime) -> datetime:
    return dt_ist - IST_OFFSET


def paise_to_rupees(amount_minor: int) -> float:
    return round(amount_minor / 100, 2)
