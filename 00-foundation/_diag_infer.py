WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
BASE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Files"
rel = "landing/payments/customers.csv"
print("with inferSchema:")
try:
    df = spark.read.option("header", True).option("inferSchema", True).csv(f"{BASE}/{rel}")
    print("  OK cols:", df.columns, "count:", df.count())
except Exception as e:
    print("  FAILED:", repr(e))
