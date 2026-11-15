# Dukaan360 – Predict Before You Lose

AI-powered predictive intelligence backend for small merchants.
Paytm Build for India AI Hackathon (Pune) · Track 1: Merchant Growth AI · Team SYNTAX SQUAD (Itisha Vamja).

> **Core rule:** machine learning / statistics calculate every number.
> Sarvam AI only *explains* them and *writes campaign wording*. It never produces a sales figure,
> customer count, percentage or risk score.

Stack: Python 3.11+ (developed on 3.14) · FastAPI · SQLAlchemy + SQLite · pandas / NumPy / statsmodels / scikit-learn · Sarvam AI (`sarvamai` SDK) · pytest.

---

## 1. Setup (Windows PowerShell)

Run everything from the `backend` folder.

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1        # if blocked, skip this line and prefix commands with .\venv\Scripts\
pip install -r requirements.txt
copy .env.example .env             # skip if .env already exists
```

If `Activate.ps1` is blocked by execution policy, either run
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once, or skip activation and call
`.\venv\Scripts\python` directly (as the examples below also work with).

### Configure Sarvam AI (optional but needed for AI-written text)

Edit `backend\.env`:

```
SARVAM_API_KEY=your_key_here
SARVAM_MODEL=sarvam-105b-conversations
```

* `.env` is git-ignored. The key is never printed or logged.
* **Without a key everything still works**: sales, churn and risk analysis are unaffected and
  campaign text falls back to built-in English / Hindi / Marathi templates (the API reports
  `"source": "fallback"` so this is never hidden).
* Verify your key with one real call (sends only example numbers, no merchant data):

```powershell
python -m scripts.test_sarvam_live
```

---

## 2. Run

```powershell
python -m scripts.seed_data                 # creates dukaan360.db + demo data (safe to repeat)
python -m uvicorn main:app --reload --port 8000
```

* API: http://localhost:8000 · Swagger UI: **http://localhost:8000/docs**
* Re-create demo data from scratch: `python -m scripts.seed_data --reset`
* Run the automated demo walkthrough against the running server: `python -m scripts.demo_check`
* Tests: `python -m pytest tests -q` (Sarvam is mocked; no network or key needed)

Optional `.env` values: `DATABASE_URL`, `CORS_ORIGINS` (default `http://localhost:5173`),
`SARVAM_TIMEOUT_SECONDS` (default 30), `DEFAULT_MERCHANT_ID` (default 1), `LOG_LEVEL`.

---

## 3. Architecture

```
main.py              FastAPI routes, validation, error format, CORS, logging (no business logic)
config.py            environment configuration
database.py          engine, session dependency (SQLite foreign keys ON)
models.py            SQLAlchemy tables      schemas.py   Pydantic request/response models
agents/
  sales_agent.py     revenue aggregation, weekday/weekend pattern, 7-day forecast, decline alert
  customer_agent.py  RFM + personal visit-interval churn logic
  risk_agent.py      Z-score anomaly detection
  growth_agent.py    rules choose campaigns/targets/reasons; Sarvam writes wording
services/
  orchestrator.py    run_analysis(): the one pipeline (agent failures isolated)
  dashboard_service  read-only KPI/forecast/churn/alert queries
  campaign_service   persistence + approval workflow (atomic transitions)
  notification_service  delivers APPROVED campaigns via the mock provider
  ask_service.py     /ask answers from the latest stored analysis
integrations/
  sarvam_client.py   official SDK, JSON validation, number guard, fallback templates
  messaging_mock.py  DEMO-ONLY messaging (sends nothing)
  paytm_mock.py      placeholder - no Paytm integration exists (see Limitations)
scripts/             seed_data.py · test_sarvam_live.py · demo_check.py
tests/               pytest suite (65 tests)
```

### How each prediction is calculated

| Feature | Method |
|---|---|
| **Sales** | Daily revenue from transactions (IST days; today is partial so excluded from comparisons). Forecast: statsmodels **Holt-Winters** (damped additive trend + weekly seasonality) when ≥ 28 days of history; otherwise a documented **same-weekday moving average**. `sales_status = declining` if last-7-days vs previous-7-days **or** forecast vs "normal week" (average of the 4 weeks before) is below **−15 %**. |
| **Customers** | RFM per customer. Normal visit interval = **mean** gap between visit days. Risk: LOW ≤ 1.5×, MEDIUM > 1.5×, HIGH > 2× the normal interval. **At Risk** = MEDIUM/HIGH **and** away ≥ 14 days. Overdue but recently seen = *Early Warning*. Customers with < 4 visits or < 21 days of history are **New** and never flagged. |
| **Risk** | Z-score of log(amount) ≥ 3.5; hours holding < 0.5 % of history are "unusual hours"; daily transaction count / revenue Z-score vs same day-type. Wording is always **"Unusual Activity Detected"** – never a fraud claim. |
| **Growth** | Win-back (≥ 1 at-risk customer), weekend promotion (weekend avg ≥ 125 % of weekday), basket-size offer (≥ 5 customers with avg bill < 85 % of shop average). Target counts and reasons come from the data. |

All money is stored as integer **paise**; API responses show INR rupees.

### AI safeguards
1. Sarvam receives only aggregate facts (no names, no phone numbers).
2. Replies are JSON-validated with Pydantic.
3. **Number guard:** an explanation containing any figure not present in the supplied facts is rejected → template used.
4. Target segment / customer counts are set by rules, never by the LLM.
5. Any failure (no key, timeout, API error, bad JSON) → fallback templates; analysis never crashes.

### Campaign workflow

```
DRAFT ──approve──▶ APPROVED ──(mock send)──▶ SENT          DRAFT ──reject──▶ REJECTED
```
* Edit allowed only while DRAFT. Rejected campaigns can never be sent. Nothing is ever sent automatically.
* Every transition is an atomic `UPDATE … WHERE status = <expected>` and is written to `campaign_approval_history`.
* A unique constraint on `delivery_events.campaign_id` makes a duplicate send impossible even under races.
* If sending fails the campaign stays APPROVED (`send_failed` in history); approving again retries.

---

## 4. API reference

Base URL `http://localhost:8000`. Demo auth: optional header `X-Merchant-Id` (default `1`). All amounts are INR rupees.
Errors always look like `{"error": "...", "message": "...", "detail": ...}` (404 not found, 409 conflict, 422 validation, 502 delivery failed, 500 internal).

| Method & path | Purpose |
|---|---|
| `GET /health` | Liveness check |
| `GET /summary` | KPIs: today / total / last-7-days revenue, growth %, customers, at-risk, alert count, sales status |
| `GET /forecast?history_days=30` | `historical_sales`, `forecast_sales` (7 days), `actual_vs_predicted`, change %, status, alert message |
| `GET /churn?limit&offset&risk_level` | `summary`, `customer_segments`, paginated `at_risk_customers` (no phone numbers) |
| `GET /alerts?limit&offset&severity` | Stored alerts, HIGH first then newest (refreshed by `/analyze`) |
| `POST /analyze` | Full pipeline. Body `{"language": "Hindi\|Marathi\|English", "idempotency_key": "..."}`; header `Idempotency-Key` also accepted. Same key → stored result (`replayed: true`) |
| `GET /campaigns?limit&offset&status` | List campaigns |
| `GET /campaigns/{id}` | Detail + approval history |
| `PUT /campaigns/{id}` | Edit `title` / `message` (DRAFT only, else 409) |
| `POST /campaigns/{id}/approve` | Approve + send via mock (Demo Mode). Idempotent |
| `POST /campaigns/{id}/reject` | Reject a draft |
| `POST /ask` | `{"question": "...", "language": "English"}` – answer from the latest analysis (409 if `/analyze` was never run) |

Example (PowerShell):

```powershell
Invoke-RestMethod http://localhost:8000/summary
Invoke-RestMethod -Method Post http://localhost:8000/analyze -ContentType application/json -Body '{"language":"Hindi"}'
Invoke-RestMethod -Method Post http://localhost:8000/campaigns/1/approve
```

`POST /analyze` response keys: `analysis_run_id`, `sales_insights`, `customer_insights`,
`business_risk_insights`, `ai_explanation {text, source, language}`, `campaign_drafts`, `warnings`, `replayed`.

---

## 5. Demo guide (≈ 5 minutes)

Start the server (section 2), open **http://localhost:8000/docs**, then:

| # | Do | What to point out |
|---|---|---|
| 1 | `GET /health` | Backend is up |
| 2 | Run `python -m scripts.seed_data` (once, before the demo) | 150 customers, 90 days, ~2,500 transactions, re-runnable without duplicates |
| 3 | `GET /summary` | Revenue and customer KPIs, calculated live |
| 4 | `GET /forecast` | History + 7-day forecast; `sales_status: declining` and the % change |
| 5 | (same response) | The decline % is derived from data (≈ −20 % vs last week on the seeded data) |
| 6 | `GET /churn` | The at-risk regulars who have stopped visiting (≈ 29: the 20 planted plus others that dropped off) |
| 7 | `POST /analyze` with `{"language":"Hindi"}` | Alerts: Unusual Activity Detected; AI explanation; Hindi campaign drafts |
| 8 | `GET /alerts` | Sorted by severity |
| 9 | `GET /campaigns` | New campaigns are **draft** – nothing is sent automatically |
| 10 | `PUT /campaigns/{id}` | Merchant edits the wording |
| 11 | `POST /campaigns/{id}/approve` | **"Campaign sent successfully (Demo Mode)."** |
| 12 | Approve again | "Already sent – no duplicate message" (idempotent) |
| 13 | `POST /ask` "Why are my sales decreasing?" | Answer built from the stored analysis, no invented numbers |

Automated version of the same walkthrough (also cross-checks the API's growth % against an independent SQL calculation):

```powershell
python -m scripts.demo_check
```

Tip: every `POST /analyze` after the first re-uses existing drafts instead of duplicating them. To start a clean demo run `python -m scripts.seed_data --reset` (this deletes the demo merchant's previous campaigns and alerts too).

---

## 6. Honest limitations

* **Synthetic data only.** The seeded numbers (≈ −20 % sales, 20 planted lapsed customers) are engineered for the demo; the churn count (≈ 29) also includes real random drop-offs. Figures are recomputed from the database each time, never hardcoded.
* **Sarvam live output depends on your key.** The integration follows the official docs/SDK and is fully tested with mocks; the real-API call must be confirmed on your machine with `python -m scripts.test_sarvam_live`. Until then responses are labelled `"source": "fallback"`.
* **No model accuracy claims.** `actual_vs_predicted` shows in-sample fitted values, not a validated backtest. No accuracy/MAPE figure is reported.
* **No real Paytm integration and no real messaging.** `messaging_mock.py` sends nothing; `paytm_mock.py` is only a placeholder. No Paytm credentials are used or implied.
* **Demo authentication** (header-based merchant id) – replace with real auth before any production use.
* Anomalies are statistical outliers, not proof of fraud.
* Single-merchant seed data; SQLite suits a demo, not heavy concurrent production load.
