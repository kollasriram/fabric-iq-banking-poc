# Labs index — Fabric IQ Banking POC

Each lab has a **facilitator** track and an **attendee** track. Historical verification refers to the archived single-model deployment. Current-demo verification means evidence captured from tenant YOUR_TENANT workspace `YOUR_WORKSPACE_NAME`; do not treat the two statuses as interchangeable.

> **New here? Start with [00-GETTING-STARTED.md](00-GETTING-STARTED.md)** — a beginner runbook that installs prerequisites, generates the data, uploads it to the portal step by step, and shows how to run each lab.

| Lab | Module | Track | Status |
|---|---|---|---|
| [00-GETTING-STARTED.md](00-GETTING-STARTED.md) | setup + data upload + how to run | **beginner runbook** | start here |
| [lab-00-foundation.md](lab-00-foundation.md) | 0 — Gold + entity resolution | notebook | deterministic values historically verified |
| [lab-01-semantic-model.md](lab-01-semantic-model.md) | 1 — `IQModel` + LOB models | notebook + portal | 🟡 current validation pending |
| [lab-03-04-ontology.md](lab-03-04-ontology.md) | 3–4 — Ontology (2 subject areas + TS binding) | code/reference | historical definition verified; map to `DemoOntology` live |
| [lab-06-graph.md](lab-06-graph.md) | 6 — Fraud-ring & centrality (GQL) | code/reference | historical query results verified; rerun live |
| [lab-07-realtime-fraud.md](lab-07-realtime-fraud.md) | 7 — RTI fraud detection (KQL) | code + portal | detection historically verified; rerun live |
| [lab-08-data-agent.md](lab-08-data-agent.md) | 8 — Data agent | portal | 🟡 current publish/query pending |
| [portal-guides.md](portal-guides.md) | 2,5,7-action,9,10,11,12 | portal | 🟡 preview |
| [Fabric-IQ-Banking-POC-UI-Walkthrough.md](Fabric-IQ-Banking-POC-UI-Walkthrough.md) | 0–10 | **canonical current guide** | live `YOUR_WORKSPACE_NAME` mapping + isolated build path |
| [lab-13-enterprise-security.md](lab-13-enterprise-security.md) | 13 — Enterprise security capstone (24 surfaces) | Azure + Fabric + portal | 🟦 lab design |
| [Complete enterprise security guide](../../Microsoft-Fabric-Enterprise-Security-Complete-Guide.md) | Requirements + implementation + capstone in one file | reference + lab | 🟦 consolidated |

**The through-line:** every lab reinforces one governed context. The capstone is the **triple-engine = 13** proof (Labs 0, 1, 3–4).

> Current prerequisites are in [00-GETTING-STARTED.md](00-GETTING-STARTED.md). [../deploy/README.md](../deploy/README.md) contains archived deployment IDs and must not be used against shared `YOUR_WORKSPACE_NAME` without re-parameterization.
