"""ORM models. All timestamps are stored as naive UTC; money is integer paise."""
from datetime import datetime, timezone

from sqlalchemy import (JSON, Column, DateTime, ForeignKey, Index, Integer,
                        String, Text, UniqueConstraint)
from sqlalchemy.orm import relationship

from database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Merchant(Base):
    __tablename__ = "merchants"
    id = Column(Integer, primary_key=True)
    business_name = Column(String(200), nullable=False)
    owner_name = Column(String(200), nullable=False)
    phone = Column(String(20), nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    customers = relationship("Customer", back_populates="merchant")
    transactions = relationship("Transaction", back_populates="merchant")
    campaigns = relationship("Campaign", back_populates="merchant")


class Customer(Base):
    __tablename__ = "customers"
    __table_args__ = (UniqueConstraint("merchant_id", "phone", name="uq_customer_phone"),)
    id = Column(Integer, primary_key=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    name = Column(String(200), nullable=False)
    phone = Column(String(20), nullable=False)
    first_seen = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    merchant = relationship("Merchant", back_populates="customers")
    transactions = relationship("Transaction", back_populates="customer")


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (Index("ix_txn_merchant_time", "merchant_id", "transaction_time"),)
    id = Column(Integer, primary_key=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True, index=True)
    amount_minor = Column(Integer, nullable=False)  # paise
    currency = Column(String(3), default="INR", nullable=False)
    payment_mode = Column(String(20), nullable=False)
    transaction_time = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    merchant = relationship("Merchant", back_populates="transactions")
    customer = relationship("Customer", back_populates="transactions")


class Campaign(Base):
    __tablename__ = "campaigns"
    id = Column(Integer, primary_key=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    title = Column(String(200), nullable=True)
    segment = Column(String(200), nullable=False)
    language = Column(String(20), nullable=False)
    message = Column(Text, nullable=False)
    campaign_type = Column(String(50), nullable=False)
    objective = Column(String(200), nullable=True)
    reason = Column(Text, nullable=True)
    target_customer_count = Column(Integer, default=0, nullable=False)
    status = Column(String(20), default="draft", nullable=False, index=True)  # draft/approved/rejected/sent
    analysis_run_id = Column(Integer, ForeignKey("analysis_runs.id"), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    approved_at = Column(DateTime, nullable=True)
    sent_at = Column(DateTime, nullable=True)

    merchant = relationship("Merchant", back_populates="campaigns")
    history = relationship("CampaignApprovalHistory", back_populates="campaign",
                           order_by="CampaignApprovalHistory.id")


class Alert(Base):
    __tablename__ = "alerts"
    id = Column(Integer, primary_key=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    alert_type = Column(String(50), nullable=False)
    severity = Column(String(10), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    metric_value = Column(String(100), nullable=True)
    analysis_run_id = Column(Integer, ForeignKey("analysis_runs.id"), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class AnalysisRun(Base):
    __tablename__ = "analysis_runs"
    id = Column(Integer, primary_key=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    idempotency_key = Column(String(100), nullable=True)
    sales_result = Column(JSON)
    churn_result = Column(JSON)
    risk_result = Column(JSON)
    growth_result = Column(JSON)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    __table_args__ = (UniqueConstraint("merchant_id", "idempotency_key", name="uq_run_idem"),)


class DeliveryEvent(Base):
    """Demo delivery record. UNIQUE(campaign_id) makes a duplicate send impossible at DB level."""
    __tablename__ = "delivery_events"
    __table_args__ = (UniqueConstraint("campaign_id", name="uq_delivery_campaign"),)
    id = Column(Integer, primary_key=True)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False, index=True)
    merchant_id = Column(Integer, ForeignKey("merchants.id"), nullable=False, index=True)
    channel = Column(String(20), default="demo", nullable=False)
    recipient_count = Column(Integer, default=0, nullable=False)
    reference = Column(String(50), nullable=False)
    status = Column(String(30), default="delivered_demo", nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class CampaignApprovalHistory(Base):
    __tablename__ = "campaign_approval_history"
    id = Column(Integer, primary_key=True)
    campaign_id = Column(Integer, ForeignKey("campaigns.id"), nullable=False, index=True)
    action = Column(String(30), nullable=False)
    previous_status = Column(String(20), nullable=True)
    new_status = Column(String(20), nullable=False)
    action_timestamp = Column(DateTime, default=utcnow, nullable=False)

    campaign = relationship("Campaign", back_populates="history")
