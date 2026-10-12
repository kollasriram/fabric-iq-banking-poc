# Lab 01 — Semantic Model: Direct Lake + Banking KPIs

**Goal:** configure the combined Direct Lake `IQModel` over all 10 gold tables and prove the same cross-domain answer in **DAX** that Lab 0 proved in Spark.

**Duration:** ~25 min · **Track:** notebook + model editor · **Status:** 🟡 current YOUR_TENANT execution evidence pending

---

## Facilitator track

### Story
BI users need governed KPIs without moving data. Direct Lake reads the gold Delta tables in place. `IQModel` spans payments and lending, so it is the **second engine** in the triple-engine proof. The two narrower models remain available for line-of-business Copilot and Planning exercises.

### Expected results (DAX `executeQueries`)
| Check | Value |
|---|---|
| Transactions | 48,710 |
| Deposit balance | $126.8M |
| Loan book | $58.8M |
| Delinquency rate | 15.5% |
| **Delinquent With Fraud (`IQModel`)** | **13** — must match Lab 0 exactly |

### Gotchas (call these out — they are the demo's hidden traps)
- **SQL-endpoint metadata is stale after Spark writes** → Direct Lake DAX fails `Invalid object name 'gold.fact_transaction'` (it falls back to DirectQuery against the SQL endpoint). **Always** run the refresh step (`04b`) before creating/refreshing the model.
- TMDL structural rules: `ref table` and relationship declarations must sit at **column 0** (unindented) or you get `InvalidLineType`. Relationships go in a **separate** `relationships.tmdl`. Relationship names must start with a letter → prefixed `r` + guid.
- Run `%pip install semantic-link-labs` and wait for the session restart before importing `sempy_labs`.

### Realism note
Fraud Loss *Rate* reads ~77% because seeded cross-border fraud amounts are intentionally large so every rule fires. It's cosmetic — tune generator amounts for a realistic dashboard.

---

## Attendee track

### 1. Confirm or create IQModel
In tenant YOUR_TENANT, open workspace `YOUR_WORKSPACE_NAME` and confirm `IQModel` contains all 10 gold tables. In an isolated rebuild, create a Direct Lake semantic model from the gold Lakehouse, select all 10 tables, and name it `IQModel`.

### 2. Add relationships and refresh
Import [nb_iqmodel_relationships.ipynb](../01-semantic-model/nb_iqmodel_relationships.ipynb), run its install cell to completion, then run the remaining cells. Confirm nine active relationships and a successful full refresh.

### 3. Add and verify the cross-domain measure
Add the `[Delinquent With Fraud]` measure from the main [UI walkthrough §3.1](Fabric-IQ-Banking-POC-UI-Walkthrough.md#31-build-or-repair-iqmodel), then query it and confirm **13**.

### 4. Optional LOB models
Retain `PaymentsDepositsModel` and `LendingCreditRiskModel` for scoped Copilot exercises. Use [nb_create_payments_model.ipynb](../01-semantic-model/nb_create_payments_model.ipynb) only when the payments model must be rebuilt. The older [nb_create_semantic_model.ipynb](../01-semantic-model/nb_create_semantic_model.ipynb) rebuilds both LOB models and can overwrite same-named items.

### Check yourself
- If DAX errors with `Invalid object name`, re-run `04b_refresh_sql_endpoint.ps1`, wait ~25s, retry.
- Open `IQModel` in Power BI and confirm it reports **Direct Lake** storage mode.
- Do not call the current path verified until the notebook output and DAX result are captured from tenant YOUR_TENANT.

> The PowerShell scripts under `deploy/` and committed DAX test output describe the historical `NorthwindModel` reference deployment. They are retained as automation examples, not as this lab's current execution path.
