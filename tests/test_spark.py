# Module tests — Spark (gold layer) positive & negative assertions.
# Emits a JSON array between markers so the orchestrator can aggregate results.
import json
from pyspark.sql import functions as F

R = []
def T(tid, kind, desc, expected, actual, cmp="eq"):
    a = actual
    if cmp == "eq":   ok = (a == expected)
    elif cmp == "gt": ok = (a > expected)
    elif cmp == "ge": ok = (a >= expected)
    elif cmp == "lt": ok = (a < expected)
    elif cmp == "ne": ok = (a != expected)
    else:             ok = False
    R.append({"id": tid, "engine": "spark", "kind": kind, "desc": desc,
              "expected": expected, "actual": a, "cmp": cmp, "pass": bool(ok)})

dc    = spark.table("gold.dim_customer")
loan  = spark.table("gold.fact_loan").where(F.col("customerKey").isNotNull()).select("customerKey").distinct()
fraud = spark.table("gold.fact_fraud_alert").where(F.col("customerKey").isNotNull()).select("customerKey").distinct()
delq  = spark.table("gold.fact_delinquency").where(F.col("customerKey").isNotNull()).select("customerKey").distinct()
cross = delq.intersect(fraud).intersect(loan)
cross_n = cross.count()

# ---------- POSITIVE ----------
T("SP-P1", "pos", "Mastered customers = 2300", 2300, dc.count())
both = dc.where(F.col("hasDeposits") & F.col("hasLoans")).count()
T("SP-P2", "pos", "Customers in BOTH LOBs (deposits+loans) = 600", 600, both)
T("SP-P3", "pos", "Cross-domain: delinquent borrowers WITH fraud alerts = 13", 13, cross_n)
T("SP-P4", "pos", "fact_transaction row count = 48710", 48710, spark.table("gold.fact_transaction").count())

# Entity-resolution ground truth: every crosswalk pair resolves to ONE customerKey
xw = spark.read.option("header", True).csv(
    "Files/NorthwindLakehouse/truth/truth_customer_crosswalk.csv"
).select(
    F.col("customerId").alias("x_pid"), F.col("borrowerId").alias("x_bid"))
kp = dc.select(F.col("paymentsCustomerId").alias("kp_pid"), F.col("customerKey").alias("ck_pay"))
kb = dc.select(F.col("borrowerId").alias("kb_bid"), F.col("customerKey").alias("ck_bor"))
j = (xw.join(kp, F.col("x_pid") == F.col("kp_pid"), "left")
        .join(kb, F.col("x_bid") == F.col("kb_bid"), "left"))
xw_total   = j.count()
xw_matched = j.where(F.col("ck_pay") == F.col("ck_bor")).count()
T("SP-P5", "pos", "Entity resolution: all 600 truth pairs resolve to same key", 600, xw_matched)
if xw_total != 600:
    raise AssertionError(f"Expected 600 truth pairs, got {xw_total}")

# ---------- NEGATIVE ----------
# No email maps to more than one master key (no accidental split)
split = dc.groupBy("email").agg(F.countDistinct("customerKey").alias("nk")).where(F.col("nk") > 1).count()
T("SP-N1", "neg", "No email split across >1 customerKey = 0", 0, split)
# No master key spans more than one email (no over-merge of distinct people)
overmerge = dc.groupBy("customerKey").agg(F.countDistinct("email").alias("ne")).where(F.col("ne") > 1).count()
T("SP-N2", "neg", "No customerKey over-merges >1 email = 0", 0, overmerge)
# No crosswalk pair resolves to DIFFERENT keys (mis-resolution)
mis = j.where(F.col("ck_pay").isNotNull() & F.col("ck_bor").isNotNull() &
              (F.col("ck_pay") != F.col("ck_bor"))).count()
T("SP-N3", "neg", "No truth pair mis-resolved to different keys = 0", 0, mis)
# Lending-only people are NOT merged with a payments customer (borrower, no payments id)
lend_only = dc.where(F.col("borrowerId").isNotNull() & F.col("paymentsCustomerId").isNull()).count()
T("SP-N4", "neg", "Lending-only customers correctly unmerged = 300", 300, lend_only)
# The 13 are a strict subset of fraud customers, and fraud-only (no loan) exist and are excluded
fraud_total = fraud.count()
T("SP-N5", "neg", "Cross-domain 13 is strict subset of fraud customers", cross_n, fraud_total, cmp="gt")
cross_nonborrowers = cross.join(loan, "customerKey", "left_anti").count()
T("SP-N6", "neg", "No cross-domain member is a non-borrower = 0", 0, cross_nonborrowers)
fraud_only = fraud.join(loan, "customerKey", "left_anti").count()
T("SP-N7", "neg", "Fraud-only customers (no loan) exist and are excluded > 0", 0, fraud_only, cmp="gt")

print("===TESTJSON_START===")
print(json.dumps(R))
print("===TESTJSON_END===")
npass = sum(1 for r in R if r["pass"])
print(f"SPARK {npass}/{len(R)} passed")
