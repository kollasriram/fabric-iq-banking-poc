WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
BASE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Files"
paths = [
    "landing/payments/customers.csv","landing/payments/products.csv","landing/payments/branches.csv",
    "landing/payments/accounts.csv","landing/payments/cards.csv","landing/payments/merchants.csv",
    "landing/payments/transactions.csv","landing/payments/fraud_alerts.csv",
    "landing/lending/borrowers.csv","landing/lending/loan_applications.csv","landing/lending/loans.csv",
    "landing/lending/collateral.csv","landing/lending/delinquency_events.csv","landing/lending/risk_ratings.csv",
    "truth/_truth_customer_crosswalk.csv",
]
for rel in paths:
    try:
        df = spark.read.option("header", True).option("inferSchema", True).csv(f"{BASE}/{rel}")
        print(f"OK   {rel:44} count={df.count()}")
    except Exception as e:
        print(f"FAIL {rel:44} {type(e).__name__}: {str(e)[:80]}")
