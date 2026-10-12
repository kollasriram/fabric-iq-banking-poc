# Lab 08 — Data Agent: Natural-Language Questions over the Ontology

**Goal:** reuse the working NorthwindDataAgent in YOUR_WORKSPACE_NAME and inspect in-portal answers over its governed IQModel source. Lakehouse-backed NorthwindOntology context is optional and not required for the current demo.

**Duration:** ~25 min · **Track:** UI-only · **Status:** demo complete through published direct-IQModel answers; optional ontology attachment blocked; further publication and external-tool testing skipped

---

## Facilitator track

### Story
NorthwindOntology provides lakehouse-backed business context. Ontology context, its companion graph, and IQModel are distinct sources: direct semantic-model questions execute DAX, while a directly connected graph executes GQL. Attaching ontology context does not prove GQL execution or federation. Inspect the actual query before accepting the cross-domain answer of 13.

### What is API-authorable vs portal
| Step | How | Status |
|---|---|---|
| Select/create the `DataAgent` item | Portal | reuse NorthwindDataAgent in YOUR_WORKSPACE_NAME |
| Set **AI instructions** | Portal or definition update | validate on the chosen item |
| Attach data sources | Portal | add ontology and `IQModel` |
| Ask | Portal | record answer, query, and execution source |
| Publish / external testing | Skipped | retain existing published version unchanged |

### Gotchas
- A data agent supports up to **5 sources** (lakehouse / warehouse / semantic model / KQL / ontology / graph / AI Search).
- For an **ontology** source you can set **Agent Instructions** + **Data Source Description** only (no schema selection / examples like other source types).
- Apply GQL guidance only to a directly connected graph. Use mastered customerKey for cross-domain identity and saved IQModel measures for governed KPI questions. If NorthwindOntology attachment fails, retain the working IQModel source and record the optional blocker; do not substitute another ontology or change permissions. Direct-model and direct-graph tests remain independent.

---

## Attendee track

### 1. Select the canonical agent
In **YOUR_WORKSPACE_NAME**, open the existing **NorthwindDataAgent**. Do not use YOUR_WORKSPACE_NAME, create duplicates, rename unrelated items, or publish again. Further publishing and external-tool testing are skipped at the user's request.

### 2. Optional ontology context (portal)
The current demo already works with IQModel; skip these steps when ontology attachment is unavailable. Preserve existing source selections and agent instructions.
1. Open the chosen data agent in the Fabric portal.
2. **Add a data source** -> select **NorthwindOntology**, bound directly to NorthwindLakehouse gold tables. Do not use DemoOntology or another comparison ontology.
3. Add a **Data Source Description** ("Governed banking ontology spanning payments, deposits, lending and fraud") and **Agent Instructions** (paste from `09b`).
4. Add `IQModel` as a second source for governed DAX measures. Optionally add the LOB models or `NorthwindRTI`, staying within the five-source limit.

### 3. Ask (portal)
Try:
- *"Which delinquent borrowers also had fraud alerts?"* → expect **13**.
- *"Which merchants are hubs for card fraud?"* → `MER-0026`.

### Check yourself
- Record the query, answer, and execution source. Validate ontology attachment, direct-model answers, and direct-graph answers separately; publication is not a gate for this reduced-scope run. See the UI walkthrough for observed results and the unresolved combined-KPI failure.
