"""Sarvam integration tests - the real API is NEVER called here (all mocked)."""
import json
from types import SimpleNamespace

import pytest

import config
from integrations import sarvam_client as sc

FACTS = {"business_name": "Shree General Store", "preferred_language": "Hindi",
         "sales_status": "declining", "sales_change_percentage_vs_previous_week": 18.0,
         "at_risk_customers": 20, "average_basket_value_rupees": 450}

GOOD = {"business_explanation": "Sales fell 18% because 20 regular customers stopped visiting.",
        "campaigns": [{"title": "Welcome Back", "message": "Namaste! Special offer this week.",
                       "target_segment": "Inactive Regular Customers", "objective": "Customer Retention"}]}


class FakeClient:
    def __init__(self, content=None, exc=None):
        self.content, self.exc, self.calls = content, exc, []
        self.chat = SimpleNamespace(completions=self._completions)

    def _completions(self, **kw):
        self.calls.append(kw)
        if self.exc:
            raise self.exc
        msg = SimpleNamespace(content=self.content)
        return SimpleNamespace(choices=[SimpleNamespace(message=msg, finish_reason="stop")])


@pytest.fixture()
def with_key(monkeypatch):
    monkeypatch.setattr(config, "SARVAM_API_KEY", "test-key-not-real")
    sc.reset_client()
    yield
    sc.reset_client()


def _use(monkeypatch, fake):
    monkeypatch.setattr(sc, "get_client", lambda: fake)


def test_no_key_falls_back_without_calling_api(monkeypatch):
    monkeypatch.setattr(config, "SARVAM_API_KEY", "")
    sc.reset_client()
    ins, source = sc.generate_insights(FACTS)
    assert source == "fallback"
    assert len(ins.campaigns) >= 2
    assert "18" in ins.business_explanation and "20" in ins.business_explanation


def test_successful_ai_response(monkeypatch, with_key):
    fake = FakeClient(json.dumps(GOOD))
    _use(monkeypatch, fake)
    ins, source = sc.generate_insights(FACTS)
    assert source == "ai"
    assert ins.campaigns[0].title == "Welcome Back"
    call = fake.calls[0]
    assert call["model"] == config.SARVAM_MODEL
    assert call["response_format"] == {"type": "json_object"}


def test_invented_number_is_rejected(monkeypatch, with_key):
    bad = dict(GOOD, business_explanation="Sales will fall 47% next week.")
    _use(monkeypatch, FakeClient(json.dumps(bad)))
    _, source = sc.generate_insights(FACTS)
    assert source == "fallback"


def test_invalid_json_falls_back(monkeypatch, with_key):
    _use(monkeypatch, FakeClient("this is not json"))
    assert sc.generate_insights(FACTS)[1] == "fallback"


def test_wrong_schema_falls_back(monkeypatch, with_key):
    _use(monkeypatch, FakeClient(json.dumps({"business_explanation": "x", "campaigns": []})))
    assert sc.generate_insights(FACTS)[1] == "fallback"


def test_api_exception_falls_back(monkeypatch, with_key):
    _use(monkeypatch, FakeClient(exc=RuntimeError("boom")))
    assert sc.generate_insights(FACTS)[1] == "fallback"


def test_json_inside_code_fence_and_think_block_is_parsed():
    text = "<think>reasoning</think>\n```json\n" + json.dumps(GOOD) + "\n```"
    assert sc._extract_json(text)["campaigns"][0]["title"] == "Welcome Back"


def test_fallback_supports_all_languages():
    for lang in ("English", "Hindi", "Marathi"):
        ins = sc.fallback_insights(dict(FACTS, preferred_language=lang))
        assert ins.business_explanation and ins.campaigns


def test_api_key_never_logged(monkeypatch, with_key, caplog):
    _use(monkeypatch, FakeClient(exc=RuntimeError("fail test-key-not-real")))
    with caplog.at_level("DEBUG"):
        sc.generate_insights(FACTS)
    assert "test-key-not-real" not in caplog.text
