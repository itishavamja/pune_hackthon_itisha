"""HTTP-level tests of the REST API (seeded in-memory DB, Sarvam disabled by conftest)."""
import pytest
from fastapi.testclient import TestClient

import main
from database import get_db
from models import Campaign, Merchant
from scripts.seed_data import seed


@pytest.fixture()
def client(db):
    seed(db)                                   # real "now" - the API uses the real clock
    main.app.dependency_overrides[get_db] = lambda: db
    yield TestClient(main.app)
    main.app.dependency_overrides.clear()


def test_summary_is_calculated_from_data(client):
    r = client.get("/summary")
    assert r.status_code == 200
    d = r.json()
    assert d["currency"] == "INR" and d["total_customers"] == 150
    assert d["total_revenue"] > d["last_7_days_revenue"] > 0
    assert d["revenue_growth_percentage"] < -15 and d["sales_status"] == "declining"


def test_forecast_shape_for_charts(client):
    d = client.get("/forecast?history_days=30").json()
    assert len(d["historical_sales"]) == 30 and len(d["forecast_sales"]) == 7
    assert {"date", "revenue"} <= set(d["forecast_sales"][0])
    assert d["method"] == "holt_winters_exponential_smoothing"


def test_churn_pagination_filter_and_privacy(client):
    d = client.get("/churn?limit=5&offset=0").json()
    assert len(d["at_risk_customers"]) == 5
    assert d["pagination"]["total"] == d["summary"]["at_risk_customers"] > 5
    page2 = client.get("/churn?limit=5&offset=5").json()["at_risk_customers"]
    assert {c["customer_id"] for c in page2}.isdisjoint({c["customer_id"] for c in d["at_risk_customers"]})
    assert "phone" not in client.get("/churn?limit=100").text.lower()
    assert client.get("/churn?risk_level=BOGUS").status_code == 422


def test_alerts_empty_before_analyze_then_sorted(client):
    assert client.get("/alerts").json()["pagination"]["total"] == 0
    client.post("/analyze")
    alerts = client.get("/alerts").json()["alerts"]
    assert len(alerts) >= 3
    rank = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    assert [rank[a["severity"]] for a in alerts] == sorted(rank[a["severity"]] for a in alerts)
    assert client.get("/summary").json()["alerts_count"] == len(alerts)


def test_analyze_returns_everything_and_drafts(client):
    r = client.post("/analyze", json={"language": "Marathi"})
    assert r.status_code == 200
    d = r.json()
    assert d["sales_insights"]["sales_status"] == "declining"
    assert d["customer_insights"]["at_risk_customers"] > 0
    assert d["business_risk_insights"]["alert_count"] >= 1
    assert d["ai_explanation"]["source"] == "fallback" and d["ai_explanation"]["text"]
    assert d["campaign_drafts"] and all(c["status"] == "draft" and c["language"] == "Marathi"
                                        for c in d["campaign_drafts"])


def test_analyze_idempotency_header(client):
    a = client.post("/analyze", headers={"Idempotency-Key": "k1"}).json()
    b = client.post("/analyze", headers={"Idempotency-Key": "k1"}).json()
    assert a["analysis_run_id"] == b["analysis_run_id"] and b["replayed"] is True


def test_analyze_rejects_bad_language(client):
    r = client.post("/analyze", json={"language": "Klingon"})
    assert r.status_code == 422 and r.json()["error"] == "validation_error"


def test_campaign_list_get_edit(client):
    client.post("/analyze")
    lst = client.get("/campaigns?limit=2").json()
    assert len(lst["campaigns"]) == 2 and lst["pagination"]["total"] >= 3
    cid = lst["campaigns"][0]["id"]
    assert client.get("/campaigns?status=sent").json()["pagination"]["total"] == 0

    r = client.put(f"/campaigns/{cid}", json={"message": "Edited by merchant"})
    assert r.status_code == 200 and r.json()["message"] == "Edited by merchant"
    detail = client.get(f"/campaigns/{cid}").json()
    assert [h["action"] for h in detail["history"]] == ["created", "edited"]


def test_edit_non_draft_is_409_and_empty_edit_is_422(client, db):
    client.post("/analyze")
    c = db.query(Campaign).first()
    assert client.put(f"/campaigns/{c.id}", json={}).status_code == 422
    c.status = "approved"
    db.commit()
    r = client.put(f"/campaigns/{c.id}", json={"message": "too late"})
    assert r.status_code == 409 and r.json()["error"] == "conflict"


def test_approve_endpoint_demo_flow_and_duplicate_safety(client):
    cid = client.post("/analyze").json()["campaign_drafts"][0]["id"]
    assert client.get(f"/campaigns/{cid}").json()["status"] == "draft"
    r = client.post(f"/campaigns/{cid}/approve")
    assert r.status_code == 200
    d = r.json()
    assert d["message"] == "Campaign sent successfully (Demo Mode)."
    assert d["demo_mode"] is True and d["already_processed"] is False
    assert d["campaign"]["status"] == "sent" and d["campaign"]["sent_at"]
    assert [h["action"] for h in d["campaign"]["history"]] == ["created", "approved", "sent"]
    r2 = client.post(f"/campaigns/{cid}/approve")                       # duplicate click
    assert r2.status_code == 200 and r2.json()["already_processed"] is True
    assert len(r2.json()["campaign"]["history"]) == 3                    # nothing new recorded
    assert client.post(f"/campaigns/{cid}/reject").status_code == 409    # sent -> cannot reject
    assert client.put(f"/campaigns/{cid}", json={"message": "x"}).status_code == 409


def test_reject_endpoint_blocks_sending(client):
    cid = client.post("/analyze").json()["campaign_drafts"][0]["id"]
    r = client.post(f"/campaigns/{cid}/reject")
    assert r.status_code == 200 and r.json()["campaign"]["status"] == "rejected"
    r2 = client.post(f"/campaigns/{cid}/approve")
    assert r2.status_code == 409 and r2.json()["error"] == "conflict"
    assert client.get(f"/campaigns/{cid}").json()["sent_at"] is None


def test_approve_unknown_campaign_404(client):
    assert client.post("/campaigns/99999/approve").status_code == 404
    assert client.post("/campaigns/99999/reject").status_code == 404


def test_unknown_campaign_404_and_error_format(client):
    r = client.get("/campaigns/99999")
    assert r.status_code == 404
    assert set(r.json()) == {"error", "message", "detail"}


def test_merchant_isolation(client, db):
    client.post("/analyze")
    other = Merchant(business_name="Other", owner_name="O", phone="9111111111")
    db.add(other)
    db.commit()
    cid = db.query(Campaign).first().id
    h = {"X-Merchant-Id": str(other.id)}
    assert client.get(f"/campaigns/{cid}", headers=h).status_code == 404           # not theirs
    assert client.put(f"/campaigns/{cid}", json={"message": "hack"}, headers=h).status_code == 404
    assert client.get("/campaigns", headers=h).json()["pagination"]["total"] == 0
    assert client.get("/summary", headers={"X-Merchant-Id": "9999"}).status_code == 404


def test_ask_requires_analysis_then_answers_from_data(client):
    assert client.post("/ask", json={"question": "Why are my sales decreasing?"}).status_code == 409
    client.post("/analyze")
    r = client.post("/ask", json={"question": "Why are my sales decreasing?"})
    assert r.status_code == 200 and r.json()["source"] == "fallback"
    assert "down about" in r.json()["answer"]
    at_risk = client.get("/churn").json()["summary"]["at_risk_customers"]
    q2 = client.post("/ask", json={"question": "Which customers are likely to stop visiting?"}).json()
    assert str(at_risk) in q2["answer"]
    assert client.post("/ask", json={"question": "hi"}).status_code == 422


def test_cors_allows_local_frontend(client):
    r = client.options("/summary", headers={"Origin": "http://localhost:5173",
                                            "Access-Control-Request-Method": "GET"})
    assert r.headers.get("access-control-allow-origin") == "http://localhost:5173"
