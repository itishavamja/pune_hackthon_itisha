# Dukaan360 – Predict Before You Lose

AI-powered predictive intelligence for small merchants and kirana shop owners.
Paytm Build for India AI Hackathon (Pune) · Track 1: Merchant Growth AI · Team SYNTAX SQUAD

## The problem

Small merchants record transactions but can't read them. They notice a sales drop, a lapsed regular
customer or unusual activity only after the money is lost. Dashboards need analytics skills, and most
tools speak only English.

## The solution

Dukaan360 tells a merchant what is about to go wrong, and what to do about it:

* **Sales forecasting** – 7-day forecast with an early warning when sales are declining.
* **Churn prediction** – spots regular customers about to stop visiting, based on each customer's own visit pattern.
* **Risk detection** – flags unusual transactions and sudden changes (Z-score anomaly detection).
* **Growth campaigns** – picks who to target and drafts the message in English, Hindi or Marathi.
* **Ask in plain language** – the merchant asks a question and gets an explained answer.

> Statistical models calculate every number. Sarvam AI only explains the results and writes the
> wording, so the merchant never sees a made-up figure.

## Repository layout

| Folder | What it is |
|---|---|
| [backend/](backend/) | FastAPI service: forecasting, churn, risk and campaign agents, SQLite database |
| [frontend/](frontend/) | Flutter mobile app (Android) |

## Technology stack

* **Mobile:** Flutter (Dart), Riverpod, fl_chart, flutter_animate
* **Backend / API:** Python, FastAPI, Uvicorn, Pydantic, SQLAlchemy
* **Database:** SQLite (switchable to PostgreSQL via `DATABASE_URL`)
* **ML / statistics:** pandas, NumPy, statsmodels, scikit-learn
* **Generative AI:** Sarvam AI (explanations and multilingual campaign text; template fallback without a key)
* **Integrations:** Paytm data and messaging are mocks in this demo

## Quick start

```powershell
# 1. Backend
cd backend
python -m venv venv
.\venv\Scripts\python -m pip install -r requirements.txt
.\venv\Scripts\python -m scripts.seed_data
.\venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000

# 2. App on a USB-connected Android phone (new terminal)
adb reverse tcp:8000 tcp:8000
cd frontend
flutter run --dart-define=API_URL=http://localhost:8000
```

API docs: http://localhost:8000/docs. See [backend/README.md](backend/README.md) and
[frontend/README.md](frontend/README.md) for details.

## Notes

The demo data is synthetic and message sending is Demo Mode (nothing real is sent).
