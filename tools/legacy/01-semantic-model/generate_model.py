# Module 1 — generate Direct Lake semantic model TMDL for the Northwind gold tables.
# Column types were normalized so every Spark type maps to a Fabric-safe sourceProviderType.
import os, json, uuid

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
OUT = os.path.join(REPO, "01-semantic-model", "NorthwindModel.SemanticModel")
DEF = os.path.join(OUT, "definition")
TBL = os.path.join(DEF, "tables")
CONN = "YOUR_SQL_ENDPOINT.datawarehouse.fabric.microsoft.com"
SQLEP_GUID = "00000000-0000-0000-0000-000000000006"
SCHEMA_NAME = "gold"

# (spark type) -> (TMDL dataType, sourceProviderType)
TYPEMAP = {
    "string":    ("string", "varchar(8000)"),
    "bigint":    ("int64", "bigint"),
    "double":    ("double", "float"),
    "boolean":   ("boolean", "bit"),
    "timestamp": ("dateTime", "datetime2"),
}

SCHEMAS = {
 "dim_customer": [["customerKey","string"],["email","string"],["name","string"],["segment","string"],["region","string"],["homeCountry","string"],["riskScore","double"],["paymentsCustomerId","string"],["borrowerId","string"],["hasDeposits","boolean"],["hasLoans","boolean"]],
 "dim_merchant": [["merchantId","string"],["name","string"],["category","string"],["mcc","bigint"],["country","string"],["riskFlag","bigint"]],
 "dim_account": [["accountId","string"],["customerId","string"],["productId","string"],["branchId","string"],["balance","double"],["status","string"],["openedDate","timestamp"]],
 "dim_product": [["productId","string"],["name","string"],["family","string"]],
 "dim_branch": [["branchId","string"],["name","string"],["region","string"]],
 "dim_date": [["date","timestamp"],["year","bigint"],["quarter","bigint"],["month","bigint"],["day","bigint"],["dateKey","bigint"]],
 "fact_transaction": [["txnId","string"],["cardId","string"],["accountId","string"],["customerId","string"],["merchantId","string"],["amount","double"],["currency","string"],["timestamp","timestamp"],["channel","string"],["geoCountry","string"],["mcc","bigint"],["isFraud","boolean"],["fraudType","string"],["customerKey","string"],["dateKey","bigint"]],
 "fact_fraud_alert": [["alertId","string"],["txnId","string"],["cardId","string"],["customerId","string"],["type","string"],["severity","string"],["status","string"],["raisedAt","timestamp"],["customerKey","string"]],
 "fact_loan": [["loanId","string"],["borrowerId","string"],["applicationId","string"],["principal","double"],["rate","double"],["termMonths","bigint"],["balance","double"],["dpd","bigint"],["originationDate","timestamp"],["customerKey","string"]],
 "fact_delinquency": [["loanId","string"],["eventId","string"],["dpdBucket","string"],["flaggedAt","timestamp"],["borrowerId","string"],["customerKey","string"]],
}

# measures: table -> list of (name, DAX)
MEASURES = {
 "fact_transaction": [
   ("Transaction Count", "COUNTROWS(fact_transaction)"),
   ("Transaction Amount", "SUM(fact_transaction[amount])"),
   ("Fraud Txn Count", "CALCULATE(COUNTROWS(fact_transaction), fact_transaction[isFraud] = TRUE())"),
   ("Fraud Loss Amount", "CALCULATE(SUM(fact_transaction[amount]), fact_transaction[isFraud] = TRUE())"),
   ("Fraud Loss Rate", "DIVIDE([Fraud Loss Amount], [Transaction Amount])"),
   ("Fee Income", "SUM(fact_transaction[amount]) * 0.015"),
 ],
 "dim_account": [
   ("Deposit Balance", "SUM(dim_account[balance])"),
 ],
 "fact_loan": [
   ("Loan Book Balance", "SUM(fact_loan[balance])"),
   ("Avg Loan Rate", "AVERAGE(fact_loan[rate])"),
   ("Delinquency Rate", "DIVIDE(CALCULATE(COUNTROWS(fact_loan), fact_loan[dpd] >= 30), COUNTROWS(fact_loan))"),
   ("Net Interest Margin", "DIVIDE(SUMX(fact_loan, fact_loan[balance] * fact_loan[rate] / 100) - [Deposit Balance] * 0.01, [Loan Book Balance] + [Deposit Balance])"),
 ],
 "fact_fraud_alert": [
   ("Open Fraud Alerts", "CALCULATE(COUNTROWS(fact_fraud_alert), fact_fraud_alert[status] = \"Open\")"),
   ("Customers With Fraud Alert", "DISTINCTCOUNT(fact_fraud_alert[customerKey])"),
 ],
}

# hierarchies: table -> (hierName, [(levelName, column), ...])
HIERARCHIES = {
 "dim_date": ("Calendar", [("Year", "year"), ("Quarter", "quarter"), ("Month", "month")]),
 "dim_branch": ("Geography", [("Region", "region"), ("Branch", "name")]),
 "dim_product": ("Product Hierarchy", [("Family", "family"), ("Product", "name")]),
}

# --- AI readiness metadata (Prep for AI, agent-editable route: TOM/TMDL) ---
# Descriptions front-load usage/units/disambiguation; Copilot reads the first ~200 chars.
TABLE_DESC = {
 "dim_customer": "Master customer, entity-resolved across the payments and lending systems. One row per person; join facts on customerKey.",
 "dim_merchant": "Merchant/acquirer where card transactions occur. Includes MCC and a risk flag for fraud analysis.",
 "dim_account": "Deposit account. Balances feed Deposit Balance. One row per account, linked to a customer, product and branch.",
 "dim_product": "Banking product catalog (deposit and loan product families).",
 "dim_branch": "Physical branch with its region; used for geographic rollups.",
 "dim_date": "Calendar date dimension for time intelligence. Join facts on dateKey.",
 "fact_transaction": "Card transactions. Grain: one row per transaction. Source of volume, spend and fraud measures.",
 "fact_fraud_alert": "Fraud alerts raised on transactions. Grain: one alert. Source of fraud counts and customer fraud exposure.",
 "fact_loan": "Originated loans with balance, rate and days-past-due. Grain: one loan. Source of lending and delinquency measures.",
 "fact_delinquency": "Delinquency events flagged on loans (past-due milestones). Grain: one event per loan bucket.",
}
COL_DESC = {
 ("dim_customer","customerKey"): "Master customer key from entity resolution; the join key across payments, lending and fraud. Use this, not source IDs.",
 ("dim_customer","email"): "Customer email; the identity attribute used to unify payments and lending records.",
 ("dim_customer","name"): "Customer full name. Default label for the customer.",
 ("dim_customer","segment"): "Customer segment (e.g., Retail, Wealth, SMB).",
 ("dim_customer","region"): "Customer region for geographic analysis.",
 ("dim_customer","homeCountry"): "Customer home country; compared against transaction geo for cross-border fraud.",
 ("dim_customer","riskScore"): "Model risk score 0-1; higher is riskier. Average, do not sum.",
 ("dim_customer","paymentsCustomerId"): "Source ID in the payments system (P-*). Lineage only; do not join facts on this.",
 ("dim_customer","borrowerId"): "Source ID in the lending system (B-*). Lineage only; do not join facts on this.",
 ("dim_customer","hasDeposits"): "True if the customer holds a deposit account (present in payments).",
 ("dim_customer","hasLoans"): "True if the customer is a borrower (present in lending).",
 ("dim_merchant","merchantId"): "Merchant key; join to transactions.",
 ("dim_merchant","name"): "Merchant name. Default label for the merchant.",
 ("dim_merchant","category"): "Merchant category description.",
 ("dim_merchant","mcc"): "Merchant Category Code (numeric). Not additive; do not sum.",
 ("dim_merchant","country"): "Merchant country.",
 ("dim_merchant","riskFlag"): "1 if the merchant is flagged high-risk, else 0. Not additive.",
 ("dim_account","accountId"): "Account key; join to transactions. Default label for the account.",
 ("dim_account","customerId"): "Payments source customer ID (lineage). Use dim_customer[customerKey] for joins.",
 ("dim_account","productId"): "Product held on the account; join to Product.",
 ("dim_account","branchId"): "Owning branch; join to Branch.",
 ("dim_account","balance"): "Current account balance in USD. Summed by Deposit Balance.",
 ("dim_account","status"): "Account status (e.g., Open, Closed).",
 ("dim_account","openedDate"): "Date the account was opened.",
 ("dim_product","productId"): "Product key; join to accounts.",
 ("dim_product","name"): "Product name. Default label for the product.",
 ("dim_product","family"): "Product family grouping (top of the product hierarchy).",
 ("dim_branch","branchId"): "Branch key; join to accounts.",
 ("dim_branch","name"): "Branch name. Default label for the branch.",
 ("dim_branch","region"): "Branch region (top of the geography hierarchy).",
 ("dim_date","date"): "Calendar date. Default label for the date.",
 ("dim_date","year"): "Calendar year. Not additive; do not sum.",
 ("dim_date","quarter"): "Quarter number 1-4. Not additive.",
 ("dim_date","month"): "Month number 1-12. Not additive.",
 ("dim_date","day"): "Day of month. Not additive.",
 ("dim_date","dateKey"): "Integer yyyymmdd surrogate key; join facts on this.",
 ("fact_transaction","txnId"): "Transaction identifier. Grain of this table.",
 ("fact_transaction","cardId"): "Card used for the transaction.",
 ("fact_transaction","accountId"): "Account funding the transaction; join to Account.",
 ("fact_transaction","customerId"): "Payments source customer ID (lineage); use customerKey for joins.",
 ("fact_transaction","merchantId"): "Merchant of the transaction; join to Merchant.",
 ("fact_transaction","amount"): "Transaction amount in USD. Summed by Transaction Amount.",
 ("fact_transaction","currency"): "ISO currency code of the transaction.",
 ("fact_transaction","timestamp"): "Transaction date-time.",
 ("fact_transaction","channel"): "Channel (e.g., POS, Online, ATM).",
 ("fact_transaction","geoCountry"): "Country where the transaction occurred; compared to home country for cross-border fraud.",
 ("fact_transaction","mcc"): "Merchant Category Code (numeric). Not additive.",
 ("fact_transaction","isFraud"): "True if the transaction is confirmed fraud. Drives fraud measures.",
 ("fact_transaction","fraudType"): "Fraud pattern label when isFraud is true (e.g., cross-border, velocity).",
 ("fact_transaction","customerKey"): "Master customer key; the join to Customer.",
 ("fact_transaction","dateKey"): "Integer yyyymmdd; join to Date.",
 ("fact_fraud_alert","alertId"): "Fraud alert identifier. Grain of this table.",
 ("fact_fraud_alert","txnId"): "Transaction that triggered the alert.",
 ("fact_fraud_alert","cardId"): "Card involved in the alert.",
 ("fact_fraud_alert","customerId"): "Payments source customer ID (lineage).",
 ("fact_fraud_alert","type"): "Alert type/category.",
 ("fact_fraud_alert","severity"): "Alert severity (e.g., Low, Medium, High).",
 ("fact_fraud_alert","status"): "Alert status; 'Open' counts toward Open Fraud Alerts.",
 ("fact_fraud_alert","raisedAt"): "Date-time the alert was raised.",
 ("fact_fraud_alert","customerKey"): "Master customer key; the join to Customer.",
 ("fact_loan","loanId"): "Loan identifier. Grain of this table.",
 ("fact_loan","borrowerId"): "Lending source borrower ID (lineage); use customerKey for joins.",
 ("fact_loan","applicationId"): "Originating loan application.",
 ("fact_loan","principal"): "Original loan principal in USD.",
 ("fact_loan","rate"): "Annual interest rate percent. Not additive; average, do not sum.",
 ("fact_loan","termMonths"): "Loan term in months. Not additive.",
 ("fact_loan","balance"): "Outstanding loan balance in USD. Summed by Loan Book Balance.",
 ("fact_loan","dpd"): "Days past due; 30+ counts as delinquent.",
 ("fact_loan","originationDate"): "Date the loan was originated.",
 ("fact_loan","customerKey"): "Master customer key; the join to Customer.",
 ("fact_delinquency","loanId"): "Loan the delinquency event belongs to.",
 ("fact_delinquency","eventId"): "Delinquency event identifier. Grain of this table.",
 ("fact_delinquency","dpdBucket"): "Days-past-due bucket (e.g., 30, 60, 90).",
 ("fact_delinquency","flaggedAt"): "Date-time the delinquency was flagged.",
 ("fact_delinquency","borrowerId"): "Lending source borrower ID (lineage).",
 ("fact_delinquency","customerKey"): "Master customer key; the join to Customer.",
}
MEASURE_DESC = {
 "Transaction Count": "Number of card transactions. Base volume metric.",
 "Transaction Amount": "Total transaction spend in USD.",
 "Fraud Txn Count": "Count of confirmed-fraud transactions.",
 "Fraud Loss Amount": "USD amount of confirmed-fraud transactions.",
 "Fraud Loss Rate": "Fraud Loss Amount / Transaction Amount. A lower rate is better.",
 "Fee Income": "Estimated fee income at 1.5% of transaction amount.",
 "Deposit Balance": "Total deposit balances across accounts in USD.",
 "Loan Book Balance": "Total outstanding loan balance in USD.",
 "Avg Loan Rate": "Average loan interest rate percent.",
 "Delinquency Rate": "Share of loans 30+ days past due. A lower rate is better.",
 "Net Interest Margin": "Net interest margin across loans and deposits. Higher is better.",
 "Open Fraud Alerts": "Count of fraud alerts currently in Open status.",
 "Customers With Fraud Alert": "Distinct customers with at least one fraud alert.",
}
MEASURE_FOLDER = {
 "Transaction Count": "Volumes", "Transaction Amount": "Volumes", "Fee Income": "Volumes",
 "Fraud Txn Count": "Fraud", "Fraud Loss Amount": "Fraud", "Fraud Loss Rate": "Fraud",
 "Open Fraud Alerts": "Fraud", "Customers With Fraud Alert": "Fraud",
 "Deposit Balance": "Balances",
 "Loan Book Balance": "Lending", "Avg Loan Rate": "Lending",
 "Delinquency Rate": "Lending", "Net Interest Margin": "Lending",
}
# Natural label column per dimension so Copilot knows the "name" of each entity.
ISDEFAULTLABEL = {
 "dim_customer": "name", "dim_merchant": "name", "dim_account": "accountId",
 "dim_product": "name", "dim_branch": "name", "dim_date": "date",
}

# relationships: (fromTable, fromCol, toTable, toCol)
RELATIONSHIPS = [
 ("fact_transaction", "customerKey", "dim_customer", "customerKey"),
 ("fact_transaction", "merchantId", "dim_merchant", "merchantId"),
 ("fact_transaction", "accountId", "dim_account", "accountId"),
 ("fact_transaction", "dateKey", "dim_date", "dateKey"),
 ("fact_fraud_alert", "customerKey", "dim_customer", "customerKey"),
 ("fact_loan", "customerKey", "dim_customer", "customerKey"),
 ("fact_delinquency", "customerKey", "dim_customer", "customerKey"),
 ("dim_account", "productId", "dim_product", "productId"),
 ("dim_account", "branchId", "dim_branch", "branchId"),
]

def lt(*parts):  # deterministic lineage tag
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "northwind/" + "/".join(parts)))

def col_block(table, name, sptype):
    dt, spt = TYPEMAP[sptype]
    lines = []
    desc = COL_DESC.get((table, name))
    if desc:
        lines.append(f"\t/// {desc}")
    lines.append(f"\tcolumn {q(name)}")
    lines.append(f"\t\tdataType: {dt}")
    lines.append(f"\t\tsourceProviderType: {spt}")
    lines.append(f"\t\tlineageTag: {lt(table, 'col', name)}")
    lines.append(f"\t\tsummarizeBy: none")
    if ISDEFAULTLABEL.get(table) == name:
        lines.append(f"\t\tisDefaultLabel")
    lines.append(f"\t\tsourceColumn: {name}")
    return "\n".join(lines) + "\n"

def q(name):  # quote identifiers that contain spaces
    return f"'{name}'" if (" " in name) else name

def table_tmdl(table):
    lines = []
    tdesc = TABLE_DESC.get(table)
    if tdesc:
        lines.append(f"/// {tdesc}")
    lines += [f"table {table}", f"\tlineageTag: {lt(table)}", ""]
    for name, sptype in SCHEMAS[table]:
        lines.append(col_block(table, name, sptype).rstrip("\n"))
        lines.append("")
    for mname, dax in MEASURES.get(table, []):
        mdesc = MEASURE_DESC.get(mname)
        if mdesc:
            lines.append(f"\t/// {mdesc}")
        lines.append(f"\tmeasure {q(mname)} = {dax}")
        if mname in MEASURE_FOLDER:
            lines.append(f"\t\tdisplayFolder: {MEASURE_FOLDER[mname]}")
        lines.append(f"\t\tlineageTag: {lt(table, 'measure', mname)}")
        lines.append("")
    if table in HIERARCHIES:
        hname, levels = HIERARCHIES[table]
        lines.append(f"\thierarchy {q(hname)}")
        lines.append(f"\t\tlineageTag: {lt(table, 'hier', hname)}")
        for lvl, col in levels:
            lines.append(f"\t\tlevel {q(lvl)}")
            lines.append(f"\t\t\tlineageTag: {lt(table, 'hier', hname, lvl)}")
            lines.append(f"\t\t\tcolumn: {col}")
        lines.append("")
    lines.append(f"\tpartition {table} = entity")
    lines.append("\t\tmode: directLake")
    lines.append("\t\tsource")
    lines.append(f"\t\t\tentityName: {table}")
    lines.append(f"\t\t\tschemaName: {SCHEMA_NAME}")
    lines.append("\t\t\texpressionSource: DatabaseQuery")
    return "\n".join(lines) + "\n"

def model_tmdl():
    # NOTE: relationships live in a separate relationships.tmdl; `ref table` lines must be at column 0.
    lines = ["model Model", "\tculture: en-US",
             "\tdefaultPowerBIDataSourceVersion: powerBI_V3",
             "\tdiscourageImplicitMeasures", "\tsourceQueryCulture: en-US", "",
             '\tannotation PBI_QueryOrder = ["DatabaseQuery"]', ""]
    for t in SCHEMAS:
        lines.append(f"ref table {t}")
    lines.append("")
    return "\n".join(lines) + "\n"

def relationships_tmdl():
    lines = []
    for ft, fc, tt, tc in RELATIONSHIPS:
        rid = "r" + lt("rel", ft, fc, tt, tc).replace("-", "")
        lines.append(f"relationship {rid}")
        lines.append(f"\tfromColumn: {ft}.{fc}")
        lines.append(f"\ttoColumn: {tt}.{tc}")
        lines.append("")
    return "\n".join(lines) + "\n"

def expressions_tmdl():
    expr = f'expression DatabaseQuery = let database = Sql.Database("{CONN}", "{SQLEP_GUID}") in database'
    return (f"{expr}\n"
            f"\tlineageTag: {lt('expr','DatabaseQuery')}\n"
            f"\tannotation PBI_IncludeFutureArtifacts = False\n"
            f"\tannotation PBI_ResultType = Table\n")

os.makedirs(TBL, exist_ok=True)
open(os.path.join(OUT, "definition.pbism"), "w", encoding="utf-8").write(
    '{"version":"4.2","settings":{}}')
open(os.path.join(DEF, "database.tmdl"), "w", encoding="utf-8").write(
    "database\n\tcompatibilityLevel: 1604\n")
open(os.path.join(DEF, "model.tmdl"), "w", encoding="utf-8").write(model_tmdl())
open(os.path.join(DEF, "relationships.tmdl"), "w", encoding="utf-8").write(relationships_tmdl())
open(os.path.join(DEF, "expressions.tmdl"), "w", encoding="utf-8").write(expressions_tmdl())
for t in SCHEMAS:
    open(os.path.join(TBL, f"{t}.tmdl"), "w", encoding="utf-8").write(table_tmdl(t))

print("Generated TMDL under", OUT)
for root, _, files in os.walk(OUT):
    for f in sorted(files):
        print("  ", os.path.relpath(os.path.join(root, f), OUT))
