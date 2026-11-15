"""Runs the hackathon demo against a RUNNING backend and checks every step.

    python -m scripts.demo_check                              # http://127.0.0.1:8000, db ./dukaan360.db
    python -m scripts.demo_check --base http://127.0.0.1:8001 --db demo_verify.db

It also recomputes the headline numbers straight from the SQLite file (independent of the
agents) and compares them with what the API reports - proof nothing is hardcoded.
"""
import argparse
import sqlite3
import sys
import uuid
from datetime import datetime, timedelta, timezone

import httpx

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

failures: list[str] = []


def check(ok: bool, label: str, detail: str = "") -> None:
    print(f"  [{'PASS' if ok else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))
    if not ok:
        failures.append(label)


def independent_numbers(db_path: str) -> dict:
    """Recompute last-7 / previous-7 revenue and the count of customers silent 14+ days from raw SQL."""
    con = sqlite3.connect(db_path)
    ist = lambda s: datetime.fromisoformat(s) + timedelta(hours=5, minutes=30)
    rows = [(ist(t).date(), a, c) for t, a, c in
            con.execute("select transaction_time, amount_minor, customer_id from transactions")]
    today = (datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(hours=5, minutes=30)).date()
    def rev(lo, hi):  # days_ago in [lo, hi]
        return sum(a for d, a, _ in rows if lo <= (today - d).days <= hi) / 100
    last_visit = {}
    for d, _, c in rows:
        if c is not None:
            last_visit[c] = max(last_visit.get(c, d), d)
    return {"last7": rev(1, 7), "prev7": rev(8, 14), "silent_14": sum(1 for d in last_visit.values() if (today - d).days >= 14),
            "customers": con.execute("select count(*) from customers").fetchone()[0]}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="http://127.0.0.1:8000")
    ap.add_argument("--db", default="dukaan360.db")
    args = ap.parse_args()
    c = httpx.Client(base_url=args.base, timeout=60)

    print("1. Backend is running")
    check(c.get("/health").json() == {"status": "ok"}, "GET /health")
    check(c.get("/docs").status_code == 200, "Swagger docs at /docs")

    print("2-3. Synthetic data loaded + dashboard KPIs")
    s = c.get("/summary").json()
    check(s["total_customers"] == 150, "150 customers", str(s["total_customers"]))
    check(s["last_7_days_revenue"] > 0 and s["total_revenue"] > 0, "revenue KPIs present",
          f"7d=Rs {s['last_7_days_revenue']:,.0f}")

    print("4-5. Sales forecast and decline (derived, not hardcoded)")
    f = c.get("/forecast").json()
    check(len(f["forecast_sales"]) == 7 and len(f["historical_sales"]) > 0, "history + 7-day forecast")
    check(f["sales_status"] == "declining" and f["revenue_change_percentage"] < -15, "decline detected",
          f"{f['revenue_change_percentage']}% vs previous week; forecast {f['projected_change_percentage']}% vs normal week")
    ind = independent_numbers(args.db)
    expect = round((ind["last7"] - ind["prev7"]) / ind["prev7"] * 100, 2)
    check(abs(expect - f["revenue_change_percentage"]) < 0.05, "API % change equals independent SQL recomputation",
          f"api={f['revenue_change_percentage']} sql={expect}")

    print("6. Inactive regular customers")
    ch = c.get("/churn?limit=100").json()
    n = ch["summary"]["at_risk_customers"]
    check(n > 0 and n <= ind["silent_14"], "at-risk customers found, all away 14+ days (cross-checked with SQL)",
          f"at_risk={n}, silent_14_plus_in_sql={ind['silent_14']}")
    check(all(r["days_inactive"] >= 14 for r in ch["at_risk_customers"]), "every listed customer inactive >= 14 days")
    check("phone" not in str(ch).lower(), "no phone numbers exposed")

    print("7-9. Analysis: alerts, AI explanation, Hindi campaign drafts")
    key = f"demo-{uuid.uuid4().hex[:8]}"
    a = c.post("/analyze", json={"language": "Hindi"}, headers={"Idempotency-Key": key}).json()
    check(a["business_risk_insights"]["alert_count"] >= 1, "unusual-activity alerts", str(a["business_risk_insights"]["alert_count"]))
    titles = [x["title"] for x in a["business_risk_insights"]["alerts"]]
    check(all("Unusual Activity Detected" in t for t in titles), "neutral wording (no fraud claims)")
    src = a["ai_explanation"]["source"]
    check(bool(a["ai_explanation"]["text"]), "AI explanation present", f"source={src}" + (
        "  <-- template text; add SARVAM_API_KEY for real Sarvam output" if src == "fallback" else ""))
    drafts = a["campaign_drafts"]
    check(len(drafts) >= 1 and all(d["status"] == "draft" and d["language"] == "Hindi" for d in drafts),
          "Hindi campaigns created as DRAFT", f"{len(drafts)} drafts")
    check(a["customer_insights"]["at_risk_customers"] == n, "analysis agrees with /churn")
    again = c.post("/analyze", json={"language": "Hindi"}, headers={"Idempotency-Key": key}).json()
    check(again["replayed"] and again["analysis_run_id"] == a["analysis_run_id"], "idempotent re-run")
    check(len(c.get("/alerts").json()["alerts"]) >= 1, "GET /alerts")

    print("10-11. Approve -> sent (Demo Mode)")
    cid = next(d["id"] for d in drafts if d["campaign_type"] == "win_back")
    check(c.get(f"/campaigns/{cid}").json()["status"] == "draft", "campaign shows as DRAFT")
    ok = c.post(f"/campaigns/{cid}/approve").json()
    check(ok["message"] == "Campaign sent successfully (Demo Mode).", "approval message", ok["message"])
    check(ok["campaign"]["status"] == "sent", "status is SENT")
    dup = c.post(f"/campaigns/{cid}/approve").json()
    check(dup["already_processed"] is True, "duplicate approval does not send again")

    print("Bonus: /ask grounded in stored analysis")
    q = c.post("/ask", json={"question": "Which customers are likely to stop visiting?"}).json()
    check(str(n) in q["answer"], "answer uses the real at-risk count", f"[{q['source']}] {q['answer'][:90]}")

    print()
    print("ALL DEMO CHECKS PASSED" if not failures else f"{len(failures)} CHECK(S) FAILED: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
