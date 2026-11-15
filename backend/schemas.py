"""Pydantic request/response schemas. All money values are INR rupees (floats, 2 dp);
the database stores integer paise."""
from datetime import datetime
from typing import Any, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

Language = Literal["English", "Hindi", "Marathi"]


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Pagination(BaseModel):
    total: int
    limit: int
    offset: int


class ErrorResponse(BaseModel):
    error: str
    message: str
    detail: Any = None


# ---------------------------------------------------------------- dashboard
class SummaryOut(BaseModel):
    currency: str = "INR"
    today_revenue: float
    total_revenue: float
    last_7_days_revenue: float
    previous_7_days_revenue: Optional[float] = None
    revenue_growth_percentage: Optional[float] = None
    total_customers: int
    at_risk_customers: int
    alerts_count: int
    sales_status: str
    last_analysis_at: Optional[datetime] = None


class DayRevenue(BaseModel):
    date: str
    revenue: float


class ActualVsPredicted(BaseModel):
    date: str
    actual: float
    predicted: float


class ForecastOut(BaseModel):
    currency: str = "INR"
    method: Optional[str] = None
    sales_status: str
    alert_message: Optional[str] = None
    revenue_change_percentage: Optional[float] = None
    projected_change_percentage: Optional[float] = None
    predicted_revenue: float
    baseline_revenue: Optional[float] = None
    historical_sales: list[DayRevenue]
    forecast_sales: list[DayRevenue]
    actual_vs_predicted: list[ActualVsPredicted]


class SegmentCount(BaseModel):
    segment: str
    count: int


class AtRiskCustomer(BaseModel):
    customer_id: int
    customer_name: str
    last_visit: Optional[str] = None
    days_inactive: Optional[int] = None
    total_spending: float
    visit_count: int
    normal_visit_interval_days: Optional[float] = None
    segment: str
    risk_level: str


class ChurnSummary(BaseModel):
    total_customers: int
    active_customers: int
    at_risk_customers: int
    early_warning_customers: int
    inactive_14_plus_days: int
    churn_risk_percentage: float
    average_basket_value: float
    at_risk_total_spending: float


class ChurnOut(BaseModel):
    summary: ChurnSummary
    customer_segments: list[SegmentCount]
    at_risk_customers: list[AtRiskCustomer]
    pagination: Pagination


class AlertOut(ORMModel):
    id: int
    alert_type: str
    severity: str
    title: str
    description: str
    metric_value: Optional[str] = None
    created_at: datetime


class AlertsOut(BaseModel):
    alerts: list[AlertOut]
    pagination: Pagination


# ---------------------------------------------------------------- analysis
class AnalyzeRequest(BaseModel):
    language: Language = "Hindi"
    idempotency_key: Optional[str] = Field(default=None, min_length=1, max_length=100)


class AiExplanation(BaseModel):
    text: Optional[str] = None
    source: Optional[str] = None      # "ai" (Sarvam) or "fallback" (templates)
    language: Optional[str] = None


class CampaignOut(ORMModel):
    id: int
    title: Optional[str] = None
    campaign_type: str
    segment: str
    target_customer_count: int = 0
    language: str
    message: str
    objective: Optional[str] = None
    reason: Optional[str] = None
    status: str
    created_at: datetime
    approved_at: Optional[datetime] = None
    sent_at: Optional[datetime] = None


class HistoryOut(ORMModel):
    id: int
    action: str
    previous_status: Optional[str] = None
    new_status: str
    action_timestamp: datetime


class CampaignDetailOut(CampaignOut):
    history: list[HistoryOut] = []


class CampaignListOut(BaseModel):
    campaigns: list[CampaignOut]
    pagination: Pagination


class AnalyzeResponse(BaseModel):
    analysis_run_id: int
    merchant_id: int
    generated_at: str
    replayed: bool
    sales_insights: dict[str, Any]
    customer_insights: dict[str, Any]
    business_risk_insights: dict[str, Any]
    ai_explanation: AiExplanation
    campaign_drafts: list[dict[str, Any]]
    warnings: list[str]


class CampaignUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    message: Optional[str] = Field(default=None, min_length=1, max_length=1000)


class CampaignActionResult(BaseModel):
    campaign: CampaignDetailOut
    message: str
    already_processed: bool = False     # true when the request was a harmless repeat
    demo_mode: bool = True              # no real messages are ever sent


# ---------------------------------------------------------------- ask
class AskRequest(BaseModel):
    question: str = Field(min_length=3, max_length=500)
    language: Language = "English"


class AskResponse(BaseModel):
    answer: str
    source: Literal["ai", "fallback"]
    based_on_analysis_run_id: int
