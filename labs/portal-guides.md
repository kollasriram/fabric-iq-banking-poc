# Portal & Preview Guides — no-code / preview modules

These Fabric IQ capabilities are configured in the portal (by product design) rather than via API. Each guide builds on the artifacts the code labs already provisioned. Screens evolve during preview — treat these as the intent + the sequence, and adapt to the current UI.

**Current UI-only run:** work only in **YOUR_WORKSPACE_NAME**. Use **NorthwindLakehouse.gold -> NorthwindOntology** for every ontology-based module; reuse its existing companion graph and Eventhouse binding. IQModel is a separate BI/KPI source, not the ontology source. No scripts, CLI, API calls, or external agent-testing tools are part of the attendee route. Preserve existing items. Further publishing, Planning, and external grounding are skipped; Teams notifications/actions require approval. Automation commands below are historical reference only, not required steps for this run.

---

## Module 2 — Prep for AI (Power BI)
Make the semantic model AI-ready so Copilot and the data agent answer accurately.

The current cross-domain target is `IQModel`. Historical TOM metadata tests under `tests/out/` apply to the retired `NorthwindModel` deployment; validate current metadata before presenting it.

**User-configured (apply in the portal — draft generated for you):** run `python 02-prep-for-ai/generate_prep_for_ai.py` to produce `02-prep-for-ai/prep_for_ai_draft.md` (and `.json`), then:
1. Open `IQModel` → **Prep data for AI**.
2. **AI instructions:** state that `customerKey` is the mastered identity and route the cross-domain question to `[Delinquent With Fraud]`.
3. **Simplify the data schema:** exclude source IDs and technical keys while retaining the fields needed for relationships.
4. **Verified answers:** configure a card for the cross-domain **13**. Configure the two LOB models separately when demonstrating their specialized KPIs.
5. **Approve for Copilot.**
> Per Microsoft guidance these four items are user-authored state — the repo drafts them but does not serialize them into the model. Feeds Lab 08 — the same instructions improve the data agent's answers.

## Module 5 — Use the lakehouse-backed ontology
1. In **YOUR_WORKSPACE_NAME**, open the existing **NorthwindOntology**. If missing, create an Ontology item in the portal; do not choose **From semantic model**.
2. Follow UI walkthrough sections 6.2-6.3: bind the nine entities and nine relationship mappings directly to **NorthwindLakehouse.gold**, and define entity keys.
3. Use **Manage graph** to verify the static companion graph before adding the Eventhouse time-series binding. Continue with this ontology and graph for downstream tasks.

## Module 7 (action layer) — Eventstream and Operations Agent
Turn detection (Lab 07) into action.
1. **Eventstream** `NorthwindTxnStream`: add a **CustomEndpoint / Sample** source → route to the **Eventhouse** `NorthwindRTI` destination; start the stream.
2. Open **NorthwindFraudOpsAgent**, confirm **NorthwindOntology** as knowledge, and use a single basic property-value condition such as Transaction amount greater than 10000. Compound AND conditions and aggregate-window rules are not supported for ontology monitoring.
3. Generate and review a saved playbook before runtime validation. The current lab has not established one; leave the agent stopped. Lakehouse source eligibility does not prove playbook generation or monitoring works.
4. Teams notifications and actions require approval; do not enable them during setup-only work. Activator remains optional.
> KQL detection is independently verified. A fresh-event notification/action checkpoint remains separate and unverified.

## Module 9 — Planning (EPM)
**Skipped for this run.** The following steps are reference only.
Driver-based plan-vs-actuals over the same data.
1. Create a **Planning** solution; import gold facts as the actuals source.
2. Build a **driver-based operating plan** for Payments & Deposits and loan origination (PowerTable / model dimensions).
3. Wire **fraud-loss actuals from RTI** (Lab 07) into plan-vs-actual variance.
4. Explore scenarios, Intelligence/Predict, and SQL write-back for submitted plans.

## Module 10 — Agent grounding
**Skipped for this run**, including further publication and external-tool agent testing. The following integrations are reference only.
Ground external agents on the governed ontology.
- **Foundry IQ:** register the ontology/graph as a knowledge source for an Azure AI Foundry agent.
- **Copilot Studio:** add the Fabric data agent / ontology as a knowledge source in a custom copilot.
- **Custom agent:** use the published Fabric data agent's supported MCP endpoint and reproduce the cross-domain question.

## Module 11 — Governance
1. **RLS** on the semantic model (e.g. branch-scoped analysts).
2. **Sensitivity labels** on lakehouse/model/ontology; confirm label inheritance.
3. **Lineage view:** trace gold -> NorthwindOntology -> supported ontology consumers, separately from gold -> IQModel -> direct-model agent queries. Do not show the semantic model as NorthwindOntology's source.
4. **Provenance & temporal validity** on ontology entities (effective-dated relationships).
> Note: the ontology has **no versioning** in preview — call this out as a current limitation.

## Module 12 — ALM
1. Connect the workspace to **Git** (Azure DevOps / GitHub); commit the items.
2. Create a **deployment pipeline** (Dev → Test → Prod); deploy the semantic model, ontology, eventhouse, and data agent.
3. Show parameterized rebinding across stages.
