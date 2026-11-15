"""ONE real Sarvam call, to confirm your key works.   python -m scripts.test_sarvam_live

Sends only example numbers (no merchant data). Never prints the API key.
"""
import json
import sys

import config
from integrations import sarvam_client as sc

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")   # Hindi/Marathi text on Windows consoles

config.setup_logging()
if not sc.is_configured():
    sys.exit("SARVAM_API_KEY is empty. Put it in backend/.env and run again.")

facts = {"business_name": "Shree General Store", "preferred_language": "Hindi",
         "sales_status": "declining", "sales_change_percentage_vs_previous_week": 18,
         "at_risk_customers": 20, "average_basket_value_rupees": 450}

print(f"Model: {config.SARVAM_MODEL}")
insights, source = sc.generate_insights(facts, num_campaigns=2)
print(f"Source: {source}  (\"ai\" = real Sarvam response, \"fallback\" = template used)")
print(json.dumps(insights.model_dump(), ensure_ascii=False, indent=2))
