"""FastAPI entrypoint: routing, validation, error format, CORS. Business logic lives in services/."""
import logging
import time
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import Depends, FastAPI, Header, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

import config
import schemas
from database import get_db, init_db
from models import Merchant
from services import ask_service, campaign_service, dashboard_service, orchestrator
from services.errors import AppError, NotFoundError

config.setup_logging()
logger = logging.getLogger("dukaan360")


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    logger.info("Database ready")
    yield


app = FastAPI(
    title="Dukaan360 API",
    description="Predict Before You Lose - AI-powered predictive intelligence for small merchants. "
                "All amounts are INR rupees. Demo auth: optional `X-Merchant-Id` header (default 1).",
    version="1.0.0", lifespan=lifespan)

app.add_middleware(CORSMiddleware, allow_origins=config.CORS_ORIGINS,
                   allow_methods=["*"], allow_headers=["*"])


# ------------------------------------------------------------------ logging + errors
@app.middleware("http")
async def access_log(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    logger.info("%s %s -> %s (%.0f ms)", request.method, request.url.path, response.status_code,
                (time.perf_counter() - start) * 1000)
    return response


def _error(status: int, error: str, message: str, detail=None) -> JSONResponse:
    return JSONResponse(status_code=status, content={"error": error, "message": message, "detail": detail})


@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    return _error(exc.status_code, exc.error, exc.message, exc.detail)


@app.exception_handler(orchestrator.MerchantNotFound)
async def merchant_missing_handler(request: Request, exc: orchestrator.MerchantNotFound):
    return _error(404, "not_found", str(exc))


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    errs = [{"field": ".".join(str(p) for p in e["loc"] if p not in ("body", "query", "path")),
             "problem": e["msg"]} for e in exc.errors()]
    return _error(422, "validation_error", "Request validation failed", errs)


@app.exception_handler(Exception)
async def unhandled_handler(request: Request, exc: Exception):
    logger.exception("Unhandled error on %s", request.url.path)
    return _error(500, "internal_error", "Something went wrong. Please try again.")


# ------------------------------------------------------------------ dependencies
def current_merchant_id(x_merchant_id: int = Header(default=config.DEFAULT_MERCHANT_ID, ge=1),
                        db: Session = Depends(get_db)) -> int:
    """Demo 'authentication': merchant chosen by header. Every service call is scoped to this id."""
    if db.get(Merchant, x_merchant_id) is None:
        raise NotFoundError(f"Merchant {x_merchant_id} not found")
    return x_merchant_id


Limit = Query(20, ge=1, le=100, description="Page size")
Offset = Query(0, ge=0, description="Items to skip")
ERRORS = {404: {"model": schemas.ErrorResponse}, 409: {"model": schemas.ErrorResponse},
          422: {"model": schemas.ErrorResponse}}


# ------------------------------------------------------------------ system
@app.get("/health", tags=["System"])
def health():
    return {"status": "ok"}


# ------------------------------------------------------------------ dashboard
@app.get("/summary", response_model=schemas.SummaryOut, tags=["Dashboard"], responses=ERRORS)
def get_summary(merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Dashboard KPIs (calculated live from transactions)."""
    return dashboard_service.summary(db, merchant_id)


@app.get("/forecast", response_model=schemas.ForecastOut, tags=["Dashboard"], responses=ERRORS)
def get_forecast(history_days: int = Query(30, ge=7, le=90, description="Days of history for the chart"),
                 merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Historical + 7-day predicted revenue, ready for chart rendering."""
    return dashboard_service.forecast(db, merchant_id, history_days)


# ------------------------------------------------------------------ customers
@app.get("/churn", response_model=schemas.ChurnOut, tags=["Customer Intelligence"], responses=ERRORS)
def get_churn(limit: int = Limit, offset: int = Offset,
              risk_level: Optional[str] = Query(None, pattern="^(HIGH|MEDIUM)$"),
              merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Customer segments and the at-risk customers (no phone numbers are ever returned)."""
    return dashboard_service.churn(db, merchant_id, limit, offset, risk_level)


# ------------------------------------------------------------------ alerts
@app.get("/alerts", response_model=schemas.AlertsOut, tags=["Business Alerts"], responses=ERRORS)
def get_alerts(limit: int = Limit, offset: int = Offset,
               severity: Optional[str] = Query(None, pattern="^(HIGH|MEDIUM|LOW)$"),
               merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Alerts from the latest analysis, most severe first, then newest. Run POST /analyze to refresh."""
    return dashboard_service.alerts(db, merchant_id, limit, offset, severity)


# ------------------------------------------------------------------ analysis
@app.post("/analyze", response_model=schemas.AnalyzeResponse, tags=["AI Analysis"], responses=ERRORS)
def analyze(body: schemas.AnalyzeRequest = schemas.AnalyzeRequest(),
            idempotency_key: Optional[str] = Header(default=None, max_length=100),
            merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Run the full pipeline: sales + customers + risk + AI explanation + campaign drafts.

    Send an `Idempotency-Key` header (or body field) to make retries safe: the same key returns the
    stored result instead of processing again.
    """
    return orchestrator.run_analysis(db, merchant_id, language=body.language,
                                     idempotency_key=idempotency_key or body.idempotency_key)


# ------------------------------------------------------------------ campaigns
@app.get("/campaigns", response_model=schemas.CampaignListOut, tags=["Campaigns"], responses=ERRORS)
def list_campaigns(limit: int = Limit, offset: int = Offset,
                   status: Optional[str] = Query(None, pattern="^(draft|approved|rejected|sent)$"),
                   merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    return campaign_service.list_campaigns(db, merchant_id, limit, offset, status)


@app.get("/campaigns/{campaign_id}", response_model=schemas.CampaignDetailOut, tags=["Campaigns"],
         responses=ERRORS)
def get_campaign(campaign_id: int, merchant_id: int = Depends(current_merchant_id),
                 db: Session = Depends(get_db)):
    return campaign_service.get_owned(db, merchant_id, campaign_id)


@app.put("/campaigns/{campaign_id}", response_model=schemas.CampaignDetailOut, tags=["Campaigns"],
         responses=ERRORS)
def edit_campaign(campaign_id: int, body: schemas.CampaignUpdate,
                  merchant_id: int = Depends(current_merchant_id), db: Session = Depends(get_db)):
    """Edit title/message. Only allowed while the campaign is a draft (otherwise 409)."""
    return campaign_service.update_draft(db, merchant_id, campaign_id, body.title, body.message)


APPROVAL_ERRORS = {**ERRORS, 502: {"model": schemas.ErrorResponse}}


@app.post("/campaigns/{campaign_id}/approve", response_model=schemas.CampaignActionResult,
          tags=["Campaigns"], responses=APPROVAL_ERRORS)
def approve_campaign(campaign_id: int, merchant_id: int = Depends(current_merchant_id),
                     db: Session = Depends(get_db)):
    """Approve a draft and send it via the MOCK messaging service (Demo Mode - nothing real is sent).

    Idempotent: repeating the request never sends twice. Rejected campaigns return 409.
    If sending fails (502) the campaign stays 'approved'; call again to retry.
    """
    return campaign_service.approve_campaign(db, merchant_id, campaign_id)


@app.post("/campaigns/{campaign_id}/reject", response_model=schemas.CampaignActionResult,
          tags=["Campaigns"], responses=ERRORS)
def reject_campaign(campaign_id: int, merchant_id: int = Depends(current_merchant_id),
                    db: Session = Depends(get_db)):
    """Reject a draft. Approved or sent campaigns cannot be rejected (409)."""
    return campaign_service.reject_campaign(db, merchant_id, campaign_id)


# ------------------------------------------------------------------ ask
@app.post("/ask", response_model=schemas.AskResponse, tags=["Merchant Questions"], responses=ERRORS)
def ask(body: schemas.AskRequest, merchant_id: int = Depends(current_merchant_id),
        db: Session = Depends(get_db)):
    """Ask a question about your business. Answers use only the latest stored analysis."""
    return ask_service.ask(db, merchant_id, body.question, body.language)
