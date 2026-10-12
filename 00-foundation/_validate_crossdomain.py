# Validate the headline cross-domain question on GOLD:
# "delinquent borrowers who ALSO had card-fraud alerts" — only answerable across both subject areas.
q = """
SELECT COUNT(DISTINCT c.customerKey) AS delinquent_borrowers_with_fraud,
       ROUND(SUM(DISTINCT_l.balance), 2) AS combined_loan_exposure
FROM gold.dim_customer c
JOIN (SELECT DISTINCT customerKey FROM gold.fact_delinquency WHERE customerKey IS NOT NULL) d
     ON c.customerKey = d.customerKey
JOIN (SELECT DISTINCT customerKey FROM gold.fact_fraud_alert  WHERE customerKey IS NOT NULL) f
     ON c.customerKey = f.customerKey
JOIN (SELECT customerKey, SUM(balance) AS balance FROM gold.fact_loan GROUP BY customerKey) DISTINCT_l
     ON c.customerKey = DISTINCT_l.customerKey
"""
spark.sql(q).show(truncate=False)

# Also list a few, with their fraud + loan context
q2 = """
SELECT c.customerKey, c.name, c.paymentsCustomerId, c.borrowerId,
       MAX(fa.severity) AS worst_fraud_sev, ROUND(SUM(DISTINCT ln.balance),0) AS loan_bal
FROM gold.dim_customer c
JOIN gold.fact_delinquency dq ON dq.customerKey = c.customerKey
JOIN gold.fact_fraud_alert fa ON fa.customerKey = c.customerKey
JOIN gold.fact_loan ln        ON ln.customerKey = c.customerKey
GROUP BY c.customerKey, c.name, c.paymentsCustomerId, c.borrowerId
ORDER BY loan_bal DESC
LIMIT 8
"""
spark.sql(q2).show(truncate=False)
print("VALIDATE_DONE")
