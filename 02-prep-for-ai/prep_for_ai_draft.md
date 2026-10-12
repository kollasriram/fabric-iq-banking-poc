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


## Synonyms (AI Data Schema)

### tables
- `dim_customer`: Customer, client, account holder, borrower, member
- `dim_merchant`: Merchant, retailer, store, acquirer
- `dim_account`: Account, deposit account
- `dim_product`: Product, offering
- `dim_branch`: Branch, location
- `fact_transaction`: Transactions, payments, card spend, purchases
- `fact_fraud_alert`: Fraud alerts, fraud cases, alerts
- `fact_loan`: Loans, credit, lending
- `fact_delinquency`: Delinquencies, past due, arrears

### columns
- `fact_transaction[amount]`: spend, transaction value, purchase amount
- `fact_loan[balance]`: loan balance, outstanding balance
- `dim_customer[homeCountry]`: home country, country of residence
- `fact_transaction[geoCountry]`: transaction country, where the purchase happened

### measures
- `Delinquent With Fraud`: delinquent borrowers with fraud alerts, fraud and delinquency overlap

## AI Data Schema — exclude from AI (keep for reports)

- `dim_customer[paymentsCustomerId]`
- `dim_customer[borrowerId]`
- `dim_account[customerId]`
- `fact_transaction[customerId]`
- `fact_fraud_alert[customerId]`
- `fact_loan[borrowerId]`
- `fact_delinquency[borrowerId]`
- `fact_transaction[txnId]`
- `fact_fraud_alert[alertId]`
- `fact_loan[loanId]`
- `fact_loan[applicationId]`
- `fact_delinquency[eventId]`
- `fact_delinquency[loanId]`
- `fact_transaction[dateKey]`
- `fact_transaction[mcc]`
- `dim_merchant[mcc]`
- `dim_merchant[riskFlag]`
- `fact_transaction[cardId]`
- `fact_fraud_alert[cardId]`

## Verified Answer candidates

1. **Which delinquent borrowers also had fraud alerts?** -> [Delinquent With Fraud] KPI card; expected value 13
