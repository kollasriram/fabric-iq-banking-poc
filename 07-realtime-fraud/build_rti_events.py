# Build enriched "live" transaction events for the Eventhouse and emit KQL inline-ingest batches.
# Denormalizes homeCountry (from customers) and merchantRisk (from merchants) so the KQL fraud
# rules are self-contained on the event stream.
import csv, json, os

OUT = os.path.join(os.path.dirname(__file__), "..", "data", "generator", "out")
def load(p):
    with open(os.path.join(OUT, p), encoding="utf-8") as f:
        return list(csv.DictReader(f))

home = {c["customerId"]: c["homeCountry"] for c in load("payments/customers.csv")}
mrisk = {m["merchantId"]: (m["riskFlag"] == "1") for m in load("payments/merchants.csv")}
txns = load("payments/transactions.csv")

# all fraud + a sample of normal for realistic volume
fraud = [t for t in txns if t["isFraud"] == "1"]
normal = [t for t in txns if t["isFraud"] != "1"]
sample = fraud + normal[:5000]
print(f"events: {len(sample)} (fraud={len(fraud)}, normal_sample=5000)")

COLS = ["txnId","cardId","accountId","customerId","merchantId","amount","currency",
        "eventTime","channel","geoCountry","mcc","homeCountry","merchantRisk","isFraud","fraudType"]

def row_csv(t):
    vals = [t["txnId"], t["cardId"], t["accountId"], t["customerId"], t["merchantId"],
            t["amount"], t["currency"], t["timestamp"], t["channel"], t["geoCountry"],
            t["mcc"], home.get(t["customerId"], ""),
            "true" if mrisk.get(t["merchantId"], False) else "false",
            "true" if t["isFraud"] == "1" else "false", t["fraudType"]]
    return ",".join(str(v) for v in vals)

batches = []
B = 2000
for i in range(0, len(sample), B):
    rows = "\n".join(row_csv(t) for t in sample[i:i+B])
    batches.append(".ingest inline into table LiveTransactions with (format='csv') <|\n" + rows)

with open(os.path.join(os.path.dirname(__file__), "_rti_batches.json"), "w", encoding="utf-8") as f:
    json.dump(batches, f)
print(f"wrote {len(batches)} ingest batches")
