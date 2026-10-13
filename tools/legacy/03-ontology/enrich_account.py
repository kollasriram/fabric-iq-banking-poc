# Add customerKey to gold.dim_account so the ontology CustomerHoldsAccount relationship
# has a lakehouse link table containing both keys (customerKey + accountId).
from pyspark.sql import functions as F

acct = spark.table("gold.dim_account")
if "customerKey" not in acct.columns:
    keymap = spark.table("gold.dim_customer").where(F.col("paymentsCustomerId").isNotNull()) \
        .select("customerKey", F.col("paymentsCustomerId").alias("_pcid"))
    acct2 = acct.join(keymap, acct.customerId == F.col("_pcid"), "left").drop("_pcid")
    acct2.write.mode("overwrite").option("overwriteSchema", "true").format("delta").saveAsTable("gold.dim_account")
    print("added customerKey to gold.dim_account")
else:
    print("customerKey already present")

matched = spark.table("gold.dim_account").where(F.col("customerKey").isNotNull()).count()
total = spark.table("gold.dim_account").count()
print(f"dim_account rows={total} with customerKey={matched}")
