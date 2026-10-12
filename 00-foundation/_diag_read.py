WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
BASE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Files"
import notebookutils
for i in notebookutils.fs.ls(f"{BASE}/landing/payments"):
    print(f"{i.name:20} size={i.size}")
print("--- try read customers.csv ---")
df = spark.read.option("header", True).csv(f"{BASE}/landing/payments/customers.csv")
print("cols:", df.columns)
print("count:", df.count())
