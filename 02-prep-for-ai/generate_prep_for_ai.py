# Module 2 — Prep for AI: generate the "user-configured" readiness artifacts that the
# facilitator applies in the Power BI "Prep data for AI" experience. Per Microsoft guidance,
# AI instructions, AI Data Schema/synonyms and Verified Answers are NOT authored via the
# serialized model; this script drafts them for review and paste-in. (The agent-editable
# metadata — descriptions, display folders, isDefaultLabel — is already in the TMDL.)
import os, json

OUT = os.path.dirname(__file__)

AI_INSTRUCTIONS = """\
# Northwind Financial — Copilot AI Instructions (draft; apply in Prep data for AI)

Identity & grain
- A customer may exist in BOTH payments and lending; they are unified by customerKey.
  Always analyze customers by customerKey, never by paymentsCustomerId or borrowerId.
- Grain: fact_transaction = one transaction; fact_fraud_alert = one alert;
  fact_loan = one loan; fact_delinquency = one delinquency event.

Metric routing
- "delinquent borrowers who also had fraud alerts" -> [Delinquent With Fraud].
- Use the PaymentsDepositsModel for payments/deposit KPI questions.
- Use the LendingCreditRiskModel for lending/delinquency KPI questions.

Terminology
- DPD = days past due (30+ is delinquent). MCC = merchant category code.
- LOB = line of business: Payments & Deposits vs Lending & Credit Risk.

Cross-domain questions
- "Delinquent borrowers who also had fraud alerts" spans both LOBs. Use the
    [Delinquent With Fraud] measure in IQModel. The verified answer is 13.

Date disambiguation
- Primary date is the transaction timestamp / dateKey. originationDate is loan-specific;
  raisedAt is alert-specific; flaggedAt is delinquency-specific.

Clarification rules
- If a user asks about "balance", ask whether they mean Deposit Balance or Loan Book Balance.
- If a user asks for specialized KPI analysis, route them to the appropriate LOB model.
"""

# AI Data Schema synonyms: object -> alternative terms users may say.
SYNONYMS = {
    "tables": {
        "dim_customer": ["Customer", "client", "account holder", "borrower", "member"],
        "dim_merchant": ["Merchant", "retailer", "store", "acquirer"],
        "dim_account": ["Account", "deposit account"],
        "dim_product": ["Product", "offering"],
        "dim_branch": ["Branch", "location"],
        "fact_transaction": ["Transactions", "payments", "card spend", "purchases"],
        "fact_fraud_alert": ["Fraud alerts", "fraud cases", "alerts"],
        "fact_loan": ["Loans", "credit", "lending"],
        "fact_delinquency": ["Delinquencies", "past due", "arrears"],
    },
    "columns": {
        "fact_transaction[amount]": ["spend", "transaction value", "purchase amount"],
        "fact_loan[balance]": ["loan balance", "outstanding balance"],
        "dim_customer[homeCountry]": ["home country", "country of residence"],
        "fact_transaction[geoCountry]": ["transaction country", "where the purchase happened"],
    },
    "measures": {
        "Delinquent With Fraud": ["delinquent borrowers with fraud alerts", "fraud and delinquency overlap"],
    },
}

# AI Data Schema visibility: keep in model for reports, EXCLUDE from AI (technical/lineage).
AI_SCHEMA_EXCLUDE = [
    "dim_customer[paymentsCustomerId]", "dim_customer[borrowerId]",
    "dim_account[customerId]", "fact_transaction[customerId]", "fact_fraud_alert[customerId]",
    "fact_loan[borrowerId]", "fact_delinquency[borrowerId]",
    "fact_transaction[txnId]", "fact_fraud_alert[alertId]", "fact_loan[loanId]",
    "fact_loan[applicationId]", "fact_delinquency[eventId]", "fact_delinquency[loanId]",
    "fact_transaction[dateKey]", "fact_transaction[mcc]", "dim_merchant[mcc]",
    "dim_merchant[riskFlag]", "fact_transaction[cardId]", "fact_fraud_alert[cardId]",
]

# Verified Answer candidates (report visuals to pin in Prep data for AI).
VERIFIED_ANSWERS = [
    {"question": "Which delinquent borrowers also had fraud alerts?",
    "returns": "[Delinquent With Fraud] KPI card; expected value 13"},
]

payload = {
    "aiInstructions": AI_INSTRUCTIONS,
    "synonyms": SYNONYMS,
    "aiSchemaExclude": AI_SCHEMA_EXCLUDE,
    "verifiedAnswers": VERIFIED_ANSWERS,
}
with open(os.path.join(OUT, "prep_for_ai_draft.json"), "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)

# Human-readable paste-in sheet
lines = [AI_INSTRUCTIONS, "\n## Synonyms (AI Data Schema)\n"]
for kind, mp in SYNONYMS.items():
    lines.append(f"### {kind}")
    for obj, syns in mp.items():
        lines.append(f"- `{obj}`: {', '.join(syns)}")
    lines.append("")
lines.append("## AI Data Schema — exclude from AI (keep for reports)\n")
lines += [f"- `{c}`" for c in AI_SCHEMA_EXCLUDE]
lines.append("\n## Verified Answer candidates\n")
for i, va in enumerate(VERIFIED_ANSWERS, 1):
    lines.append(f"{i}. **{va['question']}** -> {va['returns']}")
with open(os.path.join(OUT, "prep_for_ai_draft.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print("Wrote prep_for_ai_draft.json and prep_for_ai_draft.md to", OUT)
