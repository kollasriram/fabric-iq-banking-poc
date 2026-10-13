# Optional Legacy Automation

The attendee path is [notebooks plus the Fabric UI](../../README.md#start-here-notebooks-and-ui), explained in the [single walkthrough](../../labs/Fabric-IQ-Banking-POC-UI-Walkthrough.md). None of these utilities is required to complete that path.

These scripts preserve the historical single-model deployment for facilitator reference. They are not a production deployment toolchain. Replace every environment placeholder and use a disposable workspace before executing them. Spark/Livy utilities can rebuild or alter gold tables; definition generators overwrite local reference artifacts.

| Utility | Historical purpose |
|---|---|
| [build_medallion.py](00-foundation/build_medallion.py) | Bronze/silver/gold build and entity resolution |
| [_validate_crossdomain.py](00-foundation/_validate_crossdomain.py) | Spark cross-domain diagnostics |
| [normalize_gold.py](01-semantic-model/normalize_gold.py) | Type normalization before reference model deployment |
| [generate_model.py](01-semantic-model/generate_model.py) | Generate the reference NorthwindModel TMDL, not combined IQModel |
| [generate_prep_for_ai.py](02-prep-for-ai/generate_prep_for_ai.py) | Draft Prep for AI material for explicit owner review |
| [enrich_account.py](03-ontology/enrich_account.py) | Alter the gold account table for reference ontology bindings |
| [generate_ontology.py](03-ontology/generate_ontology.py) | Generate reference ontology definitions, not the attendee's hand-curated ontology |
| [build_rti_events.py](07-realtime-fraud/build_rti_events.py) | Build historical KQL inline-ingest batches from sample CSVs |

Run local generators from the repository root, for example:

```powershell
python tools/legacy/02-prep-for-ai/generate_prep_for_ai.py
```

Generator inputs and outputs remain under the original top-level data/module folders, not under this archive. The historical [PowerShell deployment runbook](../../deploy/README.md) stays in `deploy/`; its Livy helper is also used by the test suite, so its path is intentionally unchanged. [Graph query automation](../../06-graph/graph_ring_queries.ps1) is another optional reference tool.

Developer-only utilities remain separate: [synthetic data generator](../../data/generator/generate.py), [Spark tests](../../tests/test_spark.py), and [offline tests](../../tests/test_offline.ps1). Historical results and owner-waived checks are not fresh validation of a new environment.