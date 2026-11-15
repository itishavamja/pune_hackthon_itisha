"""Merchant Q&A: answers come from the latest STORED analysis, never from new LLM-made numbers."""
from sqlalchemy.orm import Session

from integrations import sarvam_client
from models import AnalysisRun, Merchant
from services.errors import ConflictError


def ask(db: Session, merchant_id: int, question: str, language: str) -> dict:
    run = (db.query(AnalysisRun).filter(AnalysisRun.merchant_id == merchant_id)
           .order_by(AnalysisRun.id.desc()).first())
    if run is None:
        raise ConflictError("No analysis found yet. Run POST /analyze first so answers are based on your data.")
    merchant = db.get(Merchant, merchant_id)
    facts = sarvam_client.build_facts(run.sales_result or {}, run.churn_result or {},
                                      merchant.business_name, language, run.risk_result)
    answer, source = sarvam_client.answer_question(question, facts)
    return {"answer": answer, "source": source, "based_on_analysis_run_id": run.id}
