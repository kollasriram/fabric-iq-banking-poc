# Fabric IQ Banking POC

A synthetic banking lab for Microsoft Fabric: gold tables, semantic models, real-time fraud, ontology, and data agents.

## Start Here

Follow **[the lab instructions](LAB.md)**. They include setup, data upload, notebook execution, checkpoints, and optional branches. No local Python or PowerShell is required.

```text
fabric-iq-banking-poc/
├── README.md
├── LAB.md         # step-by-step lab instructions
├── Fabric-IQ-Banking-POC-Design.md  # current scope + historical appendix
├── notebooks/     # four ordered notebooks + two optional model builders
└── data/          # ready-to-upload synthetic data ZIP
```

## Notebook Order

| Notebook | Purpose |
|---|---|
| [01-load-gold-tables.ipynb](notebooks/01-load-gold-tables.ipynb) | Build gold tables from the uploaded sample data. |
| [02-configure-iqmodel.ipynb](notebooks/02-configure-iqmodel.ipynb) | Configure relationships after creating combined IQModel in the UI. |
| [03-load-rti.ipynb](notebooks/03-load-rti.ipynb) | Seed the real-time fraud table; apply the guide's KQL rules separately. |
| [04-create-eventstream.ipynb](notebooks/04-create-eventstream.ipynb) | Optional streaming branch: create the stream and send sample events. |

Optional LOB models: choose [Payments only](notebooks/optional-payments-model.ipynb) **or** [both LOB models](notebooks/optional-two-lob-models.ipynb), not both builders. Neither replaces combined IQModel.

## Before Running

- Use [the packaged data ZIP](data/NorthwindLakehouse-data.zip); upload instructions are in the walkthrough.
- Replace `YOUR_*` values and example GUIDs with your own environment, and configure notebook lakehouse attachments.
- Use a disposable lab workspace. Gold builds overwrite tables, RTI setup drops/reloads its target, and Eventstream setup replaces the same-name stream and sends 300 events once.
- Fabric IQ preview and AI branches require the permissions and capacity described in the guide. Do not upgrade capacity or enable notifications without authorization.

Reference values are checkpoints, not proof that your environment has been validated. The instructions retain the original acceptance limitations; waived checks are not passes.

## Design Reference

[Design document](Fabric-IQ-Banking-POC-Design.md): current architecture, Core / Optional / Not Implemented coverage, and acceptance limits, with the original broader vision preserved in a historical appendix. Use the lab instructions above for execution; the appendix is not a deployment plan.