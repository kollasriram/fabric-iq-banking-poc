# Lab 03–04 — Ontology: Two Subject Areas + Time-Series Binding

**Goal:** author a governed ontology spanning **both** lines of business (unified by the shared `Customer`), bind entities to gold **and** to the real-time Eventhouse, and prove the cross-domain answer a **third** way — a GQL graph walk.

**Duration:** ~40 min · **Track:** UI-only for this run · **Status:** NorthwindOntology graph verified in YOUR_WORKSPACE_NAME; Operations Agent validation remains separate

**Canonical source:** bind **NorthwindOntology** directly to **NorthwindLakehouse.gold** Delta tables through the Fabric portal. Do not generate the working ontology from IQModel. No generated comparison ontology is required. Use [the UI walkthrough](Fabric-IQ-Banking-POC-UI-Walkthrough.md), sections 6.2-6.6 and 9, for the current attendee steps.

---

## Facilitator track

### Story
The semantic model is great for BI, but agents and operational apps need a **graph of business concepts with relationships and actions**. The ontology is that shared brain: 9 entity types, 9 relationships, spanning Payments & Deposits and Lending & Credit Risk. Because `Customer` is entity-resolved (Lab 0), a single walk crosses both LOBs. This is the **third engine** — and the finale of the triple-engine proof.

### What attendees build
- Current run: **NorthwindOntology** in **YOUR_WORKSPACE_NAME**, with `Customer, Account, Merchant, Products, Branch, Transaction, FraudAlert, Loan, DelinquencyEvent` and nine relationships. Use `Products` because `PRODUCT` is reserved in GQL. Historical DemoOntology is not this run's target.
- A **static** binding (LakehouseTable, gold) **and** a **time-series** binding (KustoTable → Eventhouse `NorthwindRTI`) on `Transaction`. This ties RTI into the ontology.

### Expected results
| Check | Value |
|---|---|
| Node counts (Customer/Account/Transaction/Merchant/Loan/FraudAlert/DelinquencyEvent) | 2300 / 3026 / 48710 / 50 / 472 / 1710 / 73 (match gold) |
| **Cross-domain GQL walk** `FraudAlert → Customer → Loan → DelinquencyEvent` | **13** ✅ matches Labs 0 & 1 |
| Both-LOBs via graph (Account AND approved Loan node) | 260 |
| Time-series bindings (exact) | 1 · KustoTable · NorthwindRTI · LiveTransactions · eventTime |

### Gotchas
- **Ontology create auto-provisions** a companion `<name>_lh` lakehouse + `<name>_graph` graph. Deleting the ontology cascades to both — never hand-delete companions.
- Item names must **start with a letter**, only letters/numbers/underscores.
- **Graph must be materialized before querying:** run a `RefreshGraph` job (~2 min) after create/update.
- **GQL node label = entity type name** (`Customer`, not the source table).
- **Time-series binding rules:** the static binding must pre-exist; TS property names must be **new/unique** (we use `TsAmount`, not `amount`); apply via **updateDefinition** (not recreate — preserves the item + graph).
- Verify TS with an **exact** `dataBindingType == "TimeSeries"` filter — `"NonTimeSeries"` contains `"TimeSeries"` as a substring, so `-like` matching over-counts.
- Note the **260 vs 600** difference: graph counts customers with an *actual approved Loan node* (472 exist), while the gold `has_loans` flag = *is a borrower* (600). Both correct under their definitions — a nice teaching moment about semantics.

---

## Attendee track

**UI-only steps:** open the existing NorthwindOntology; verify the nine direct lakehouse entity bindings and keys, then the nine lakehouse relationship mappings; materialize and query the static companion graph before adding the Eventhouse time-series binding. Use NorthwindOntology for Operations Agent knowledge and optional Data Agent ontology context. Keep IQModel separate for DAX KPIs. Do not change existing bindings, rerun creation scripts, or enable messages/actions without approval.

**Historical automation reference only:** the commands below are not part of this UI-only run. Their targets and ordering must be reviewed before any separately approved execution. In particular, verify the static graph before adding a second source binding: Eventhouse sources and multi-table entities are ineligible for graph projection. The UI walkthrough provides the working order; do not follow the historical numbered script sequence against existing items.

### 1. Enrich gold for the relationship link
```powershell
cd fabric-iq-banking-poc/deploy
./lib_livy_run.ps1 -PyFile ../03-ontology/enrich_account.py   # adds customerKey to gold.dim_account
```

### 2. Generate and create the ontology
```powershell
python ../03-ontology/generate_ontology.py
./06_create_ontology.ps1
```

### 3. Materialize and query the static lakehouse-backed graph
Do this before adding a second source binding to Transaction.
```powershell
./06c_refresh_graph.ps1
./06d_graph_crossdomain_walk.ps1
```
Expect **13**. Capture the current GQL output before marking the live demo verified.

### 4. Add the Eventhouse time-series binding
> Run **after** static graph verification and Lab 07. Preserve the verified graph and check projection eligibility before any later refresh.
```powershell
./06b_update_ontology.ps1
./06e_verify_timeseries_binding.ps1
```

### Check yourself
- Node counts equal the gold table counts.
- The TS-binding verify prints exactly **1** binding for `LiveTransactions`.
