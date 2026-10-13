# Module 1 prep — normalize GOLD Delta column types so Direct Lake TMDL maps cleanly:
#   IntegerType->long, DateType->timestamp, Float/Decimal->double.
# Then emit each gold table's final schema as JSON for the TMDL generator.
import json
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType, DateType, FloatType, DecimalType, ShortType, ByteType

GOLD = ["dim_customer", "dim_merchant", "dim_account", "dim_product", "dim_branch",
        "dim_date", "fact_transaction", "fact_fraud_alert", "fact_loan", "fact_delinquency"]

def normalize(df):
    for f in df.schema.fields:
        t = f.dataType
        if isinstance(t, (IntegerType, ShortType, ByteType)):
            df = df.withColumn(f.name, F.col(f.name).cast("long"))
        elif isinstance(t, DateType):
            df = df.withColumn(f.name, F.col(f.name).cast("timestamp"))
        elif isinstance(t, (FloatType, DecimalType)):
            df = df.withColumn(f.name, F.col(f.name).cast("double"))
    return df

schemas = {}
for t in GOLD:
    df = normalize(spark.table(f"gold.{t}"))
    df.write.mode("overwrite").option("overwriteSchema", "true").format("delta").saveAsTable(f"gold.{t}")
    schemas[t] = [[f.name, spark.table(f"gold.{t}").schema[f.name].dataType.simpleString()] for f in spark.table(f"gold.{t}").schema.fields]

print("SCHEMAS_JSON " + json.dumps(schemas))
