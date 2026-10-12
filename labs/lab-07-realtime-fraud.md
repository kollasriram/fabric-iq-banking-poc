# Lab 07 — Real-Time Intelligence: Fraud Detection (KQL)

**Goal:** stand up an Eventhouse, ingest a live-shaped transaction stream, and run **four real fraud-detection rules** in KQL — the RTI spine that feeds the ontology's time-series binding.

**Duration:** ~35 min · **Track:** KQL + portal · **Status:** historical counts verified · current YOUR_TENANT rerun required

---

## Facilitator track

### Story
Card fraud must be caught in seconds, not in the nightly batch. Fabric Real-Time Intelligence ingests the transaction stream into an Eventhouse where KQL rules score it continuously. The same Eventhouse table (`LiveTransactions`) is the **time-series binding** on the ontology's `Transaction` entity (Lab 03–04), so streaming truth flows into the governed context.

### What attendees build
- Eventhouse `NorthwindRTI` + KQL table `LiveTransactions` (streaming ingestion enabled).
- 6,710 events ingested (1,710 fraud + 5,000 normal), enriched with `homeCountry` + `merchantRisk`.
- **4 real fraud rules** (behavioral, not label-based).

### Expected results
| Rule | Logic | Result |
|---|---|---|
| R1 cross-border high-value | `amount > 10000 AND geo != home` | 500 alerts / $13.6M |
| R2 velocity | self-join, ≥3 distinct merchants in 5-min window | 194 cards |
| R3 impossible travel | 2 countries, same card, within 30 min | 148 cards |
| R4 high-risk merchant | `merchantRisk == true` | 1373 txns / 1035 cards / 11 merchants |

### Gotchas
- **Kusto data-plane auth token resource = `https://api.kusto.windows.net`** (NOT `kusto.fabric.microsoft.com`). Query: `POST {queryUri}/v1/rest/query {db,csl}`; mgmt: `POST {queryUri}/v1/rest/mgmt`.
- KQLDatabase can't be created standalone — it's created **inside** the Eventhouse.
- Ingest uses `.ingest inline into table ... with (format='csv') <|` batches (2000 rows each).
- The rules are **behavioral** — they'd catch fraud with the `isFraud` label removed. Emphasize this vs. "cheating" by filtering the label.

### Action layer (portal — see portal-guides.md)
Wire `NorthwindTxnStream` from a Custom Endpoint source to the `NorthwindRTI` destination, then configure an **Operations Agent** grounded in the ontology. It can notify Teams or invoke supported configured actions such as BlockCard/OpenFraudCase. Activator is optional for a separate event-driven workflow; it is not required for this lab checkpoint.

---

## Attendee track

### 1. Create the Eventhouse and table
```powershell
cd fabric-iq-banking-poc/deploy
./07_create_eventhouse.ps1
./07b_create_kql_table.ps1
```

### 2. Build events and ingest + run rules
```powershell
python ../07-realtime-fraud/build_rti_events.py     # -> _rti_batches.json
./08_ingest_rti_and_rules.ps1
```
The script ingests the batches and runs all four rules, printing each rule's counts.

### Check yourself
- `LiveTransactions` has 6,710 rows.
- R1 = 500 alerts, R4 = 1373 txns. If auth 401s, confirm the token resource is `https://api.kusto.windows.net`.
- Return to Lab 03–04 step 3 to bind this Eventhouse into the ontology as a time-series source.
