WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
BASE = f"abfss://{WS}@onelake.dfs.fabric.microsoft.com/{LH}/Files"
import notebookutils
for p in ["", "/landing", "/landing/payments"]:
    try:
        items = notebookutils.fs.ls(f"{BASE}{p}")
        print(f"LS {BASE}{p} -> " + ", ".join([i.name for i in items]))
    except Exception as e:
        print(f"LS {BASE}{p} FAILED: {e}")
