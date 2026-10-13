# Historical deployment runbook — Fabric IQ Banking POC

These PowerShell scripts reproduce the earlier single-model `NorthwindModel` reference deployment. They were executed successfully in tenant YOUR_TENANT, but their workspace and item IDs are **not** the current `YOUR_WORKSPACE_NAME` demo. For the current hands-on path, use the [UI walkthrough](../labs/Fabric-IQ-Banking-POC-UI-Walkthrough.md).

> **Do not run these scripts or `reset_all.ps1` against `YOUR_WORKSPACE_NAME` without reviewing and replacing every workspace/item ID.** The current canonical workspace is `YOUR_WORKSPACE_NAME` (`00000000-0000-0000-0000-000000000003`) and contains unrelated artifacts as well as the banking demo.

## Archived reference config

| Variable | Value |
|---|---|
| Tenant | `YOUR_TENANT.onmicrosoft.com` (`00000000-0000-0000-0000-000000000001`) |
| Subscription (`$sub`) | `00000000-0000-0000-0000-000000000002` |
| Workspace (`$ws`) | `00000000-0000-0000-0000-000000000003` (`Fabric-IQ-Banking-POC`) |
| Capacity | `YOUR_CAPACITY_NAME` F8 (`00000000-0000-0000-0000-000000000004`) |
| Lakehouse | `00000000-0000-0000-0000-000000000005` |
| SQL endpoint | `00000000-0000-0000-0000-000000000006` (`YOUR_SQL_ENDPOINT.datawarehouse.fabric.microsoft.com`) |
| Semantic model | `00000000-0000-0000-0000-000000000007` (`NorthwindModel`) |
| Ontology | `00000000-0000-0000-0000-000000000010` (`NorthwindOntology`) |
| Companion graph | `00000000-0000-0000-0000-000000000011` |
| Eventhouse | `00000000-0000-0000-0000-000000000012` (`NorthwindRTI`), KQL cluster `YOUR_KQL_CLUSTER.kusto.fabric.microsoft.com` |
| Data agent | `00000000-0000-0000-0000-000000000014` (`NorthwindDataAgent`) |

## Current semantic models in YOUR_WORKSPACE_NAME

| Model | Item ID | Role |
|---|---|---|
| `IQModel` | `00000000-0000-0000-0000-000000000007` | canonical combined model |
| `PaymentsDepositsModel` | `00000000-0000-0000-0000-000000000008` | payments/deposits LOB model |
| `LendingCreditRiskModel` | `00000000-0000-0000-0000-000000000009` | lending/credit-risk LOB model |

These scripts do not build or validate the current `IQModel` workflow.

> **Auth gotcha:** this machine has multiple az logins — always pin `--subscription $sub` (not `--tenant`) or tokens resolve to the wrong identity.

## Run order

| Step | Script | Notes |
|---|---|---|
| 1 | `01_create_workspace.ps1` | workspace on the IQ-enabled capacity |
| 2 | `02_create_lakehouse.ps1` | schema-enabled `NorthwindLakehouse` |
| 3 | `../data/generator/generate.py` → `03_upload_data.ps1` (+ `03b_upload_truth.ps1`) | synthetic data → OneLake Files |
| 4 | `lib_livy_run.ps1 -PyFile ../tools/legacy/00-foundation/build_medallion.py` | bronze/silver/gold + entity resolution |
| 4b | `04b_refresh_sql_endpoint.ps1` | **required** — SQL endpoint metadata sync after Spark writes |
| 5 | `lib_livy_run.ps1 -PyFile ../tools/legacy/01-semantic-model/normalize_gold.py` → `05_create_semantic_model.ps1` | Direct Lake model + KPIs |
| 5b | `05b_verify_semantic_model.ps1` | DAX KPIs + cross-domain = 13 |
| 6 | `lib_livy_run.ps1 -PyFile ../tools/legacy/03-ontology/enrich_account.py` → `06_create_ontology.ps1` | ontology (9 entities / 9 rels, static bindings) |
| 6b | `06b_update_ontology.ps1` | adds the **Eventhouse time-series binding** (run after step 7) |
| 6c | `06c_refresh_graph.ps1` | materialize the companion graph |
| 6d | `06d_graph_crossdomain_walk.ps1` | GQL cross-domain walk = 13 |
| 6e | `06e_verify_timeseries_binding.ps1` | confirm the KustoTable TS binding |
| 7 | `07_create_eventhouse.ps1` → `07b_create_kql_table.ps1` | Eventhouse + `LiveTransactions` table |
| 8 | `../tools/legacy/07-realtime-fraud/build_rti_events.py` → `08_ingest_rti_and_rules.ps1` | ingest + run the 4 KQL fraud rules |
| 9 | `09_create_dataagent.ps1` → `09b_dataagent_instructions.ps1` | data agent + AI instructions |
| 10 | `10_create_eventstream.ps1` | Eventstream item (topology wiring is portal) |

Utilities: `util_sqlcheck.ps1` (query the lakehouse SQL endpoint), `06-graph/graph_ring_queries.ps1` (fraud-ring / centrality GQL).

## Historical verification
The archived deployment returned cross-domain **13** from all three engines:
- Spark: `../tools/legacy/00-foundation/_validate_crossdomain.py` (via `lib_livy_run.ps1`)
- DAX: `05b_verify_semantic_model.ps1`
- GQL: `06d_graph_crossdomain_walk.ps1`

## Reset
Use reset only in a disposable workspace created specifically by these scripts. Never workspace-scope a reset against shared `YOUR_WORKSPACE_NAME`; delete only explicitly reviewed item IDs.
