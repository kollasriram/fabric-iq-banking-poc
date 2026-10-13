# Module 0 — Northwind medallion build (bronze -> silver -> gold) on NorthwindLakehouse.
# Entity resolution (payments customer + lending borrower -> one master customer by email)
# is done in GOLD for analytics; the ONTOLOGY later also resolves at its layer via identity keys.
from pyspark.sql import functions as F, Window

WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
BASE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Files"

def read_csv(rel):
    return (spark.read.option("header", True).option("inferSchema", True)
            .csv(f"{BASE}/{rel}"))

for s in ["bronze", "silver", "gold"]:
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {s}")

# ---------------- BRONZE (raw, as-ingested) ----------------
bronze = {
    "pay_customers":      "landing/payments/customers.csv",
    "pay_products":       "landing/payments/products.csv",
    "pay_branches":       "landing/payments/branches.csv",
    "pay_accounts":       "landing/payments/accounts.csv",
    "pay_cards":          "landing/payments/cards.csv",
    "pay_merchants":      "landing/payments/merchants.csv",
    "pay_transactions":   "landing/payments/transactions.csv",
    "pay_fraud_alerts":   "landing/payments/fraud_alerts.csv",
    "lend_borrowers":     "landing/lending/borrowers.csv",
    "lend_applications":  "landing/lending/loan_applications.csv",
    "lend_loans":         "landing/lending/loans.csv",
    "lend_collateral":    "landing/lending/collateral.csv",
    "lend_delinquencies": "landing/lending/delinquency_events.csv",
    "lend_risk_ratings":  "landing/lending/risk_ratings.csv",
    "truth_crosswalk":    "truth/truth_customer_crosswalk.csv",
}
for tbl, rel in bronze.items():
    read_csv(rel).write.mode("overwrite").format("delta").saveAsTable(f"bronze.{tbl}")

# ---------------- SILVER (typed / standardized) ----------------
tx = (spark.table("bronze.pay_transactions")
      .withColumn("timestamp", F.to_timestamp("timestamp"))
      .withColumn("isFraud", F.col("isFraud").cast("boolean"))
      .withColumn("amount", F.col("amount").cast("double")))
tx.write.mode("overwrite").format("delta").saveAsTable("silver.transactions")

(spark.table("bronze.pay_fraud_alerts")
 .withColumn("raisedAt", F.to_timestamp("raisedAt"))
 .write.mode("overwrite").format("delta").saveAsTable("silver.fraud_alerts"))

(spark.table("bronze.lend_loans")
 .withColumn("dpd", F.col("dpd").cast("int"))
 .withColumn("balance", F.col("balance").cast("double"))
 .withColumn("principal", F.col("principal").cast("double"))
 .write.mode("overwrite").format("delta").saveAsTable("silver.loans"))

for t in ["pay_customers", "pay_accounts", "pay_cards", "pay_merchants",
          "pay_products", "pay_branches", "lend_borrowers", "lend_applications",
          "lend_collateral", "lend_delinquencies", "lend_risk_ratings"]:
    spark.table(f"bronze.{t}").write.mode("overwrite").format("delta").saveAsTable(f"silver.{t.replace('pay_','').replace('lend_','')}")

# ---------------- GOLD ----------------
# Entity resolution: master customer keyed by email, unifying both source systems.
pay = spark.table("silver.customers").select(
    F.col("customerId").alias("paymentsCustomerId"),
    "name", "email", "segment", "region", "homeCountry", "riskScore")
bor = spark.table("silver.borrowers").select(
    F.col("borrowerId"), "name", "email", "segment", "region", "homeCountry")

emails = pay.select("email").union(bor.select("email")).distinct()
w = Window.orderBy("email")
master = emails.withColumn("customerKey", F.concat(F.lit("CUST-"), F.lpad(F.row_number().over(w).cast("string"), 6, "0")))

dim_customer = (master
    .join(pay, "email", "left")
    .join(bor.select("email", F.col("name").alias("bname"),
                     F.col("segment").alias("bseg"), F.col("region").alias("breg"),
                     F.col("homeCountry").alias("bhome"), "borrowerId"), "email", "left")
    .select(
        "customerKey", "email",
        F.coalesce("name", "bname").alias("name"),
        F.coalesce("segment", "bseg").alias("segment"),
        F.coalesce("region", "breg").alias("region"),
        F.coalesce("homeCountry", "bhome").alias("homeCountry"),
        F.col("riskScore"),
        "paymentsCustomerId", "borrowerId",
        F.col("paymentsCustomerId").isNotNull().alias("hasDeposits"),
        F.col("borrowerId").isNotNull().alias("hasLoans")))
dim_customer.write.mode("overwrite").format("delta").saveAsTable("gold.dim_customer")

# crosswalks customerKey <-> source ids (distinct alias names avoid ambiguous joins)
key_by_pay = dim_customer.where(F.col("paymentsCustomerId").isNotNull()).select("customerKey", F.col("paymentsCustomerId").alias("_pcid"))
key_by_bor = dim_customer.where(F.col("borrowerId").isNotNull()).select("customerKey", F.col("borrowerId").alias("_bid"))

# Dimensions
spark.table("silver.merchants").write.mode("overwrite").format("delta").saveAsTable("gold.dim_merchant")
spark.table("silver.accounts").write.mode("overwrite").format("delta").saveAsTable("gold.dim_account")
spark.table("silver.products").write.mode("overwrite").format("delta").saveAsTable("gold.dim_product")
spark.table("silver.branches").write.mode("overwrite").format("delta").saveAsTable("gold.dim_branch")

# Date dimension from transaction span
dates = (spark.table("silver.transactions").select(F.to_date("timestamp").alias("date")).distinct())
dim_date = (dates
    .withColumn("year", F.year("date")).withColumn("quarter", F.quarter("date"))
    .withColumn("month", F.month("date")).withColumn("day", F.dayofmonth("date"))
    .withColumn("dateKey", F.date_format("date", "yyyyMMdd").cast("int")))
dim_date.write.mode("overwrite").format("delta").saveAsTable("gold.dim_date")

# Facts (attach master customerKey)
fact_txn = (spark.table("silver.transactions")
    .join(key_by_pay, F.col("customerId") == F.col("_pcid"), "left").drop("_pcid")
    .withColumn("dateKey", F.date_format("timestamp", "yyyyMMdd").cast("int")))
fact_txn.write.mode("overwrite").format("delta").saveAsTable("gold.fact_transaction")

fact_alert = (spark.table("silver.fraud_alerts")
    .join(key_by_pay, F.col("customerId") == F.col("_pcid"), "left").drop("_pcid"))
fact_alert.write.mode("overwrite").format("delta").saveAsTable("gold.fact_fraud_alert")

fact_loan = (spark.table("silver.loans")
    .join(key_by_bor, F.col("borrowerId") == F.col("_bid"), "left").drop("_bid"))
fact_loan.write.mode("overwrite").format("delta").saveAsTable("gold.fact_loan")

fact_delq = (spark.table("silver.delinquencies")
    .join(spark.table("silver.loans").select("loanId", "borrowerId"), "loanId", "left")
    .join(key_by_bor, F.col("borrowerId") == F.col("_bid"), "left").drop("_bid"))
fact_delq.write.mode("overwrite").format("delta").saveAsTable("gold.fact_delinquency")

# ---------------- VERIFY ----------------
out = []
for t in ["gold.dim_customer", "gold.fact_transaction", "gold.fact_fraud_alert",
          "gold.fact_loan", "gold.fact_delinquency", "gold.dim_merchant"]:
    out.append(f"{t}={spark.table(t).count()}")
res = dim_customer.agg(
    F.sum(F.col("hasDeposits").cast("int")).alias("with_deposits"),
    F.sum(F.col("hasLoans").cast("int")).alias("with_loans"),
    F.sum((F.col("hasDeposits") & F.col("hasLoans")).cast("int")).alias("both_lobs")).collect()[0]
out.append(f"customers with_deposits={res.with_deposits} with_loans={res.with_loans} BOTH_LOBS={res.both_lobs}")
print("BUILD_OK " + " | ".join(out))
