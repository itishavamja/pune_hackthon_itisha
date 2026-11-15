"""Sales Prediction Agent - pure statistics, no LLM.

Definitions (all computed from the merchant's transactions):
  * "completed days"  = every IST day before today (today is partial, so it is
                        reported separately and never used for comparisons).
  * last_7_days       = the 7 latest completed days.
  * previous_7_days   = the 7 completed days before that.
  * baseline_revenue  = average WEEKLY revenue over the 28 days that precede the
                        last 7 days (a "normal week" for this shop). Weekly totals
                        cancel out the weekday/weekend pattern.
  * predicted_revenue = sum of the 7-day forecast (tomorrow .. tomorrow+6).

Forecast method:
  * >= 28 completed days: Holt-Winters ExponentialSmoothing (damped additive trend,
    additive weekly seasonality) from statsmodels.
  * otherwise, or if fitting fails: "weekday_moving_average" fallback - each future
    day = average revenue of the same weekday over the last 4 weeks (or the mean of
    the last 7 days if there is not even one full week).

Alert rule: sales_status is "declining" when observed revenue change
(last 7 vs previous 7 days) OR projected change (forecast vs baseline) is below -15%.
"""
import logging
import warnings
from datetime import timedelta
from typing import Optional

import numpy as np
import pandas as pd
from sqlalchemy.orm import Session

from utils.calculations import load_transactions, pct_change, rupees, today_ist
from utils.helpers import utcnow

logger = logging.getLogger(__name__)

DECLINE_THRESHOLD_PCT = -15.0
MIN_DAYS_FOR_HOLT_WINTERS = 28
HORIZON = 7


def _weekday_average_forecast(history: pd.Series, dates) -> list[float]:
    """Fallback forecast: average of the same weekday in the last 4 weeks."""
    out = []
    for d in dates:
        same = history[(history.index.dayofweek == d.dayofweek)].iloc[-4:]
        out.append(float(same.mean()) if len(same) else float(history.iloc[-7:].mean()))
    return out


def _holt_winters(values: np.ndarray):
    from statsmodels.tsa.holtwinters import ExponentialSmoothing
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        fit = ExponentialSmoothing(values, trend="add", damped_trend=True, seasonal="add",
                                   seasonal_periods=7, initialization_method="estimated").fit()
    fc = np.asarray(fit.forecast(HORIZON + 1))      # step 0 = today (partial day, discarded)
    fitted = np.asarray(fit.fittedvalues)
    if not (np.isfinite(fc).all() and np.isfinite(fitted).all()):
        raise ValueError("non-finite model output")
    return fc[1:], fitted


def run_sales_analysis(db: Session, merchant_id: int, now=None) -> dict:
    now = now or utcnow()
    today = today_ist(now)
    df = load_transactions(db, merchant_id)
    df = df[df["date"] <= today] if not df.empty else df

    if df.empty:
        return _empty_result("No transactions found for this merchant.")

    daily = df.groupby("date")["amount"].sum()
    today_revenue = float(daily.get(today, 0.0))
    first_day = daily.index.min()
    if first_day >= today:
        return _empty_result("Not enough completed days of history yet.", today_revenue)
    full_index = pd.date_range(first_day, today - timedelta(days=1), freq="D")
    completed = daily.reindex(full_index, fill_value=0.0)

    n = len(completed)
    last7 = float(completed.iloc[-7:].sum())
    prev7 = float(completed.iloc[-14:-7].sum()) if n >= 14 else None
    base_window = completed.iloc[-35:-7]
    baseline = float(base_window.sum() / (len(base_window) / 7.0)) if len(base_window) >= 7 else None

    # ---- weekday / weekend pattern (last 8 weeks) ----
    recent = completed.iloc[-56:]
    is_weekend = recent.index.dayofweek >= 5
    weekday_avg = float(recent[~is_weekend].mean()) if (~is_weekend).any() else 0.0
    weekend_avg = float(recent[is_weekend].mean()) if is_weekend.any() else 0.0
    names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    by_dow = recent.groupby(recent.index.dayofweek).mean()
    weekday_pattern = [{"day": names[i], "average_revenue": rupees(by_dow.get(i, 0.0))} for i in range(7)]

    # ---- forecast ----
    future_dates = pd.date_range(today + timedelta(days=1), periods=HORIZON, freq="D")
    method, fitted = None, None
    if n >= MIN_DAYS_FOR_HOLT_WINTERS:
        try:
            fc, fitted = _holt_winters(completed.values.astype(float))
            method = "holt_winters_exponential_smoothing"
        except Exception as exc:  # fall back, never crash
            logger.warning("Holt-Winters failed (%s); using weekday moving average", exc)
    if method is None:
        fc = np.array(_weekday_average_forecast(completed, future_dates))
        method = "weekday_moving_average"
    fc = np.clip(fc, 0, None)
    predicted = float(fc.sum())

    # ---- actual vs fitted for the last 14 days (in-sample, NOT a forecast backtest) ----
    avp = []
    for d in completed.index[-14:]:
        if fitted is not None:
            pred = float(max(fitted[completed.index.get_loc(d)], 0))
        else:
            past = completed[completed.index < d]
            same = past[past.index.dayofweek == d.dayofweek].iloc[-4:]
            if not len(same):
                continue
            pred = float(same.mean())
        avp.append({"date": d.strftime("%Y-%m-%d"), "actual": rupees(completed[d]), "predicted": rupees(pred)})

    observed_change = pct_change(last7, prev7) if prev7 is not None else None
    projected_change = pct_change(predicted, baseline) if baseline is not None else None
    signals = [c for c in (observed_change, projected_change) if c is not None]
    worst = min(signals) if signals else 0.0
    best = max(signals) if signals else 0.0
    if worst < DECLINE_THRESHOLD_PCT:
        status = "declining"
    elif best > -DECLINE_THRESHOLD_PCT:
        status = "growing"
    else:
        status = "stable"

    alert = None
    if status == "declining":
        parts = []
        if observed_change is not None and observed_change < DECLINE_THRESHOLD_PCT:
            parts.append(f"revenue in the last 7 days (Rs {last7:,.0f}) is {abs(observed_change):.1f}% "
                         f"lower than the 7 days before (Rs {prev7:,.0f})")
        if projected_change is not None and projected_change < DECLINE_THRESHOLD_PCT:
            parts.append(f"next 7 days are forecast at Rs {predicted:,.0f}, "
                         f"{abs(projected_change):.1f}% below your normal week (Rs {baseline:,.0f})")
        alert = "Sales decline warning: " + "; ".join(parts) + "."

    return {
        "merchant_id": merchant_id,
        "method": method,
        "days_of_history": int(n),
        "today_revenue": rupees(today_revenue),
        "last_7_days_revenue": rupees(last7),
        "previous_7_days_revenue": rupees(prev7) if prev7 is not None else None,
        "average_daily_revenue": rupees(completed.mean()),
        "weekday_average_revenue": rupees(weekday_avg),
        "weekend_average_revenue": rupees(weekend_avg),
        "weekday_pattern": weekday_pattern,
        "revenue_change_percentage": observed_change,
        "projected_change_percentage": projected_change,
        "predicted_revenue": rupees(predicted),
        "baseline_revenue": rupees(baseline) if baseline is not None else None,
        "sales_status": status,
        "alert_message": alert,
        "historical_sales": [{"date": d.strftime("%Y-%m-%d"), "revenue": rupees(v)}
                             for d, v in completed.items()],
        "forecast_sales": [{"date": d.strftime("%Y-%m-%d"), "revenue": rupees(v)}
                           for d, v in zip(future_dates, fc)],
        "actual_vs_predicted": avp,
    }


def _empty_result(message: str, today_revenue: float = 0.0) -> dict:
    return {
        "method": None, "days_of_history": 0, "today_revenue": rupees(today_revenue),
        "last_7_days_revenue": 0.0, "previous_7_days_revenue": None, "average_daily_revenue": 0.0,
        "weekday_average_revenue": 0.0, "weekend_average_revenue": 0.0, "weekday_pattern": [],
        "revenue_change_percentage": None, "projected_change_percentage": None,
        "predicted_revenue": 0.0, "baseline_revenue": None, "sales_status": "insufficient_data",
        "alert_message": None, "insufficient_data_reason": message,
        "historical_sales": [], "forecast_sales": [], "actual_vs_predicted": [],
    }
