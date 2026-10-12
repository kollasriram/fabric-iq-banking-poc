# Getting Started — Fabric IQ Banking POC (beginner runbook)

This is the **on-ramp**: it takes you from a fresh machine to a running lab — install prerequisites, generate the sample data, **upload it into the Fabric portal step by step**, and then run each lab. Every click and command is spelled out, with a "you'll know it worked when…" check after each step.

For the deep, per-module click steps, this runbook hands off to the [UI walkthrough](Fabric-IQ-Banking-POC-UI-Walkthrough.md). Read this file first, then follow the walkthrough module by module.

---

## Part A — One-time setup

### A1. Check you have Python (for the data generator only)
1. Open **PowerShell** (Start menu → type `PowerShell` → Enter).
2. Run:
   ```powershell
   python --version
   ```
   - ✅ **Worked when:** you see `Python 3.10` or higher.
   - ❌ If "not recognized": install Python from https://www.python.org/downloads/ (tick **"Add python.exe to PATH"** during install), then reopen PowerShell.

> The generator uses only Python's standard library — there is **nothing to `pip install`**.

### A2. Get the repo onto your machine
1. If you don't already have it, clone or copy the `fabric-iq-banking-poc` folder to disk (e.g. `YOUR_PROJECT_ROOT`).
2. In PowerShell, move into the repo:
   ```powershell
   cd YOUR_PROJECT_ROOT
   ```
   - ✅ **Worked when:** `dir` lists `data`, `00-foundation`, `labs`, `deploy`, etc.

### A3. Sign in to the Fabric portal
1. In a browser go to **https://app.fabric.microsoft.com**.
2. Sign in with your work account (for this POC: the `YOUR_TENANT.onmicrosoft.com` tenant admin).
   - ✅ **Worked when:** you land on the Fabric home page with a left rail (Home, Workspaces, …).

### A4. Turn on the preview features (tenant admin)
> Needs a **Fabric administrator**. If that's not you, ask your admin to enable these once.
1. Top-right **Settings (gear)** → **Admin portal** → **Tenant settings**.
2. Search and **Enable** each (for the whole org or a security group that includes you):
   - **Copilot and Azure OpenAI**
   - **Ontology (preview)**
   - **Data agent (preview)**
3. **Apply** on each.
   - ✅ **Worked when:** each toggle shows **Enabled**. (Tenant changes can take ~15 min to propagate.)

### A5. Make sure you have capacity
1. Left rail → **Workspaces**. For the Copilot portions of this lab, use a workspace backed by a paid **Fabric capacity (F2+)** or **Power BI Premium capacity (P1+)**.
2. PPU alone and trial capacity are not sufficient for the Copilot portions. Ask your admin to assign a supported paid capacity.
   - ✅ **Worked when:** in the next step the workspace's **License mode** offers a Fabric capacity.

### A6. Create the workspace
1. Left rail → **Workspaces** → **+ New workspace**.
2. **Name:** `Fabric-IQ-Banking-POC`.
3. Expand **Advanced** → **License mode** → pick the paid Fabric or Premium capacity.
4. **Apply**.
   - ✅ **Worked when:** an empty workspace opens. Keep this browser tab open — every lab item is created here.

---

## Part B — Generate the sample data

The two "source systems" (payments and lending) are synthetic. Generate them once.

1. In PowerShell (still in the repo folder):
   ```powershell
   cd data\generator
   python generate.py --scale demo --seed 42
   ```
2. Look at what it produced:
   ```powershell
   dir out ; dir out\payments ; dir out\lending
   ```
   - ✅ **Worked when:** you see `out\payments\*.csv` (customers, accounts, cards, merchants, transactions, fraud_alerts, …), `out\lending\*.csv` (borrowers, loans, delinquency_events, …), and `out\truth_customer_crosswalk.csv`.
   - The console also prints counts like `2000 customers`, `48710 transactions`, `overlap=600`.

> Remember the folder path — you'll drag these files into the portal next: `…\fabric-iq-banking-poc\data\generator\out`.

> **Want to understand the data first?** The [UI walkthrough §1a](Fabric-IQ-Banking-POC-UI-Walkthrough.md#1a-understand-the-data-read-before-building) explains the two source systems, the gold star schema and relationships, and how entity resolution by email produces the shared `customerKey`.

---

## Part C — Upload the data into the portal (step by step)

### C1. Create the Lakehouse
1. In the `Fabric-IQ-Banking-POC` workspace → **+ New item** (top-left).
2. In the item picker, search **Lakehouse** → click it.
3. **Name:** `NorthwindLakehouse`.
4. Tick **Lakehouse schemas** so the notebook can create the `gold` schema.
5. **Create.**
   - ✅ **Worked when:** the Lakehouse **Explorer** opens with two roots: **Tables** and **Files** (both empty).

### C2. Create the folder structure under Files
1. In the Explorer, hover **Files** → click the **…** → **New subfolder** → name it `NorthwindLakehouse` → **Create**.
2. Under `NorthwindLakehouse`, create `payments`, `lending`, and `truth`.
   - ✅ **Worked when:** under **Files** you have `NorthwindLakehouse/payments`, `NorthwindLakehouse/lending`, and `NorthwindLakehouse/truth`.

### C3. Upload the payments CSVs
1. Click the **NorthwindLakehouse/payments** folder to select it.
2. Hover it → **…** → **Upload** → **Upload files**.
3. In the file dialog, browse to `…\data\generator\out\payments`, select **all** the CSVs (Ctrl+A), **Open**.
4. Wait for each file's progress to reach 100%.
   - ✅ **Worked when:** clicking **NorthwindLakehouse/payments** shows `customers.csv`, `accounts.csv`, `cards.csv`, `merchants.csv`, `transactions.csv`, `fraud_alerts.csv`, `products.csv`, `branches.csv`.

### C4. Upload the lending CSVs
1. Select **NorthwindLakehouse/lending** → **…** → **Upload** → **Upload files**.
2. Browse to `…\out\lending`, select all CSVs, **Open**.
   - ✅ **Worked when:** `borrowers.csv`, `loans.csv`, `loan_applications.csv`, `collateral.csv`, `delinquency_events.csv`, `risk_ratings.csv` are listed.

### C5. Upload the truth crosswalk
1. Select the **NorthwindLakehouse/truth** folder → **…** → **Upload** → **Upload files**.
2. Browse to `…\out`, pick **`truth_customer_crosswalk.csv`**, **Open**.
   - ✅ **Worked when:** `NorthwindLakehouse/truth/truth_customer_crosswalk.csv` is listed.

> ⚠️ Do **not** rename any file to start with an underscore (`_`). Spark treats `_name` files as hidden and will fail to read them.

**You now have all raw data in OneLake.** Everything from here is building Fabric items on top of it.

---

## Part D — How to run a lab (the mechanics)

Most labs are "create an item, paste a snippet, run, check a number." Here's the muscle memory you'll reuse:

### D1. How to run the foundation Notebook (used by Lab 0)
1. Workspace → **Import** → **Notebook** → **From this computer** → select [nb_load_files_to_tables.ipynb](../00-foundation/nb_load_files_to_tables.ipynb).
2. Left Explorer inside the notebook → **Add** → **Existing lakehouse** → pick `NorthwindLakehouse`.
3. Confirm `BASE = "Files/NorthwindLakehouse"` in the config cell.
4. Select **Run all** in the ribbon.
   - ✅ **Worked when:** the cell shows a green check and prints output below it.
5. Find your workspace/lakehouse GUIDs (some snippets need them): look at the browser URL — `…/groups/<workspaceId>/…/lakehouses/<lakehouseId>`. Paste those into the snippet's `WS`/`LH` variables, **or** delete those lines and use the attached-lakehouse relative paths.

### D2. How to run KQL in a Query set (used by Lab 7)
1. Open the KQL database → **+ New** → **KQL queryset** (or use the built-in **Explore your data**).
2. Paste a KQL statement, highlight it, click **Run** (or Shift+Enter).
   - ✅ **Worked when:** results appear in the grid below.

### D3. How to run DAX / ask Copilot (used by Lab 1 & 2)
1. Open `IQModel` → **… → Query with DAX** (DAX query view) for the cross-domain measure, or **Copilot** for natural language. Use the LOB models only for their scoped KPIs.
2. Paste the `EVALUATE …` and **Run**.

### D4. How to run a GQL graph query (used by Lab 6)
1. Open the ontology's **Graph** tab (or the `…_graph` item) → **Query**.
2. Paste the `MATCH … RETURN …` and **Run**.

---

## Part E — Run the labs in order

Do these in sequence — each builds on the previous. Full click detail is in the linked walkthrough sections; the table tells you what you're doing and the number to confirm.

| # | Lab | What you build (UI) | Confirm | Walkthrough section |
|---|---|---|---|---|
| 0 | Gold + entity resolution | Notebook builds 10 `gold` tables; unify the customer | `dim_customer`=**2300**, both-LOB=**600**, cross-domain=**13** | [§2](Fabric-IQ-Banking-POC-UI-Walkthrough.md#2-lakehouse-and-gold-build-module-0) |
| — | Refresh SQL endpoint | Refresh the Lakehouse SQL analytics endpoint | `gold.*` tables visible | [§2.4](Fabric-IQ-Banking-POC-UI-Walkthrough.md#24-refresh-the-sql-analytics-endpoint) |
| 1 | Semantic models | `IQModel` + relationships + cross-domain measure; retain LOB models | `IQModel` DAX=**13** | [§3](Fabric-IQ-Banking-POC-UI-Walkthrough.md#3-direct-lake-semantic-models-module-1) |
| 2 | Prep for AI | Configure `IQModel`; optionally configure LOB models | `IQModel` Copilot answers **13** | [§4](Fabric-IQ-Banking-POC-UI-Walkthrough.md#4-prep-for-ai-module-2) |
| 3–4 | Ontology | 9 entities, 9 relationships, time-series binding | node counts match gold | [§6](Fabric-IQ-Banking-POC-UI-Walkthrough.md#6-ontology-two-subject-areas-modules-3-4) |
| 6 | Graph | GQL ring/centrality + cross-domain walk | walk=**13** | [§9](Fabric-IQ-Banking-POC-UI-Walkthrough.md#9-graph-analysis-module-6) |
| 7 | Real-time fraud | Eventhouse, KQL table, ingest, 4 rules | rows=**6710**, rules 500/194/148/1373 | [§5](Fabric-IQ-Banking-POC-UI-Walkthrough.md#5-real-time-intelligence-fraud-module-7) |
| 8 | Data agent | Add ontology + `IQModel`, publish, ask | agent answers **13** | [§8](Fabric-IQ-Banking-POC-UI-Walkthrough.md#8-data-agent-module-8) |
| 9–10 | Planning / grounding | Portal modules | see walkthrough | [§10](Fabric-IQ-Banking-POC-UI-Walkthrough.md#10-planning-module-9) |

---

## Part F — Prove it worked (the headline)

The whole point of the POC is that **one governed answer holds across every engine you built**. After Labs 0, 1, 3–4, 6, and 8, ask the same question in each place:

> *"Which delinquent borrowers also had fraud alerts?"*

- Notebook (Spark SQL) → **13**
- `IQModel` (DAX / Copilot) → **13**
- Ontology graph (GQL walk) → **13**
- Data agent (natural language) → **13**

If all four say **13** and the outputs are captured from the current YOUR_TENANT workspace, your Fabric IQ POC is working end to end.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Notebook: `UNABLE_TO_INFER_SCHEMA` | A CSV name starts with `_`, or the folder is empty. Re-upload without the underscore. |
| DAX error `Invalid object name 'gold.X'` | The SQL endpoint metadata is stale — open the SQL analytics endpoint → **Refresh**, wait ~30s, retry (see §2.4). |
| Can't find **Ontology** / **Data agent** in **+ New** | Preview toggle not enabled or not propagated yet — recheck **A4** and wait ~15 min. |
| Copilot button greyed out | Check Copilot eligibility, model access, editing/viewing mode, and supported paid capacity. Have an authorized admin review existing Copilot settings (A4); do not change tenant settings without approval. |
| Numbers differ from the table | You generated with a different `--scale` or `--seed`. Use `--scale demo --seed 42`. |
