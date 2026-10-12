# Lab 00 — Foundation: Gold + Entity Resolution

**Goal:** land two synthetic source systems in OneLake, build the 10 gold Delta tables, and **resolve one shared `Customer`** so the two lines of business become one governed context.

**Duration:** ~30 min · **Track:** Fabric notebook · **Status:** deterministic values historically verified; rerun in the selected workspace

---

## Facilitator track

### Story
Northwind's payments platform and its loan-origination system each have their own customer key (`paymentsCustomerId` = `P-*`, `borrowerId` = `B-*`). The same human is two rows. Fabric IQ can only reason across the two LOBs if we first **resolve** them into one `Customer`. This lab is the bedrock for the triple-engine = 13 proof.

### What attendees build
- Deterministic synthetic data (2 source systems + a hidden truth crosswalk).
- Ten typed gold dimensions/facts written directly from the uploaded CSV files.
- **Entity resolution** in `gold.dim_customer`: master keyed by email, unifying both systems.

### Expected results (demo scale, seed default)
| Metric | Value |
|---|---|
| Unique mastered customers | 2300 |
| …with deposits | 2000 |
| …with loans (borrowers) | 900 |
| **…in BOTH LOBs** | **600** |
| Transactions | 48710 (1710 fraud) |
| Loans / delinquencies | 472 / 73 |
| **Cross-domain headline** (delinquent borrowers with fraud alerts) | **13**, $2.32M exposure |

### Talking points / gotchas
- **Why email as the master key:** the crosswalk is deliberately *not* used for resolution — it's the ground truth to *score against*. Show `truth_customer_crosswalk.csv` only at the end to validate.
- **Spark ignores `_`-prefixed files** (treated as hidden) → schema-inference failure. The truth file is uploaded without the underscore for that reason.
- **AMBIGUOUS_REFERENCE** when joining on same-named columns → we alias key columns (`_pcid`/`_bid`), join explicitly, then drop.
- This "600 in both LOBs" number is what makes the whole cross-domain narrative possible — call it out.

---

## Attendee track

### 1. Generate the data
```powershell
cd fabric-iq-banking-poc/data/generator
python generate.py --scale demo --seed 42
```
Produces `payments/`, `lending/`, and `truth_customer_crosswalk.csv`.

### 2. Upload to OneLake
Follow [Getting Started Part C](00-GETTING-STARTED.md#part-c--upload-the-data-into-the-portal-step-by-step). The required layout is `Files/NorthwindLakehouse/{payments,lending,truth}` for an isolated build.

### 3. Build gold
Import [nb_load_files_to_tables.ipynb](../00-foundation/nb_load_files_to_tables.ipynb), attach the target Lakehouse, confirm the `BASE` setting, and run all cells.

### 4. Refresh the SQL endpoint
Open the Lakehouse SQL analytics endpoint and select **Refresh** after the Spark write completes.

### 5. Validate the headline
The notebook's final checks must report **2300** mastered customers, **600** in both LOBs, and **13** delinquent borrowers who also had fraud alerts.

### Check yourself
- `gold.dim_customer` has 2300 rows; 600 have both `hasDeposits` and `hasLoans`.
- Re-running is idempotent (same seed → same data).

> The `build_medallion.py` and PowerShell/Livy flow is retained as historical automation. It is not the canonical attendee path.
