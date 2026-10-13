# Labs index — Fabric IQ Banking POC

## Attendee Path

1. [End-to-end walkthrough](Fabric-IQ-Banking-POC-UI-Walkthrough.md): the single guide for prerequisites, packaged data upload, notebook links, parameters, checkpoints, and optional branch exits. Start at section 0; local Python is optional.
2. [Notebook sequence](../README.md#start-here-notebooks-and-ui): a compact checklist distinguishing the combined IQModel route from alternative LOB model notebooks.

Import the supplied notebooks into Fabric; no local automation is required. Do not run both alternative model builders. Gold rebuilds, RTI reloads, and Eventstream replacement/event sends are mutating actions, not verification reruns.

## Supporting References

Use these for background or facilitator preparation; they are not a second required run order. Historical single-model results must not be treated as fresh evidence for your configured workspace. Acceptance results and owner-waived checks remain recorded in the walkthrough.

| Guide | Role |
|---|---|
| [Foundation](lab-00-foundation.md) | Gold tables and entity-resolution background |
| [Semantic models](lab-01-semantic-model.md) | Combined IQModel and alternative LOB model background |
| [Ontology](lab-03-04-ontology.md) | Historical generated-definition reference; use walkthrough section 6 for the hand-curated attendee build |
| [Graph](lab-06-graph.md) | Optional preview investigation and historical queries |
| [Real-time fraud](lab-07-realtime-fraud.md) | Historical ingestion/rule background; attendee notebooks are linked in the walkthrough |
| [Data agent](lab-08-data-agent.md) | Optional agent background |
| [Portal guides](portal-guides.md) | Additional portal-only exercises |
| [Enterprise security](lab-13-enterprise-security.md) | Separate optional security capstone |
| [Legacy automation](../tools/legacy/README.md) | Optional archived Python utilities and PowerShell runbook |

Replace public environment placeholders before use. Preserve existing shared items; use a disposable workspace for rebuilds and archived automation.
