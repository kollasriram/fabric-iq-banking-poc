# Module 3-4 — generate the Fabric IQ Ontology definition tree for Northwind.
# Two subject areas (Payments&Deposits + Lending&Credit) unified by a shared Customer.
# Entities bind to curated GOLD lakehouse tables; relationships use gold link tables.
import os, json, hashlib, uuid, shutil

WS = "00000000-0000-0000-0000-000000000003"
LH = "00000000-0000-0000-0000-000000000005"
SCHEMA = "gold"
# Eventhouse (RTI) for the time-series binding
EH_ID = "00000000-0000-0000-0000-000000000012"
EH_CLUSTER = "https://YOUR_KQL_CLUSTER.kusto.fabric.microsoft.com"
EH_DB = "NorthwindRTI"
EH_TABLE = "LiveTransactions"
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
OUT = os.path.join(REPO, "03-ontology", "NorthwindOntology")
PARTS = os.path.join(OUT, "parts")

def big_id(name):  # deterministic positive 64-bit-safe integer id (as string)
    return str(int(hashlib.sha1(name.encode()).hexdigest()[:15], 16))

def guid(name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "northwind-onto/" + name))

# entity: (EntityName, sourceTable, keyProp, displayNameProp, [(propName, valueType, sourceColumn)])
ENTITIES = [
 ("Customer", "dim_customer", "customerKey", "name", [
    ("customerKey","String","customerKey"),("name","String","name"),("email","String","email"),
    ("segment","String","segment"),("region","String","region"),("homeCountry","String","homeCountry"),
    ("riskScore","Double","riskScore"),("hasDeposits","Boolean","hasDeposits"),("hasLoans","Boolean","hasLoans"),
    ("paymentsCustomerId","String","paymentsCustomerId"),("borrowerId","String","borrowerId")]),
 ("Account", "dim_account", "accountId", "accountId", [
    ("accountId","String","accountId"),("customerId","String","customerId"),("productId","String","productId"),
    ("branchId","String","branchId"),("balance","Double","balance"),("status","String","status"),
    ("customerKey","String","customerKey")]),
 ("Merchant", "dim_merchant", "merchantId", "name", [
    ("merchantId","String","merchantId"),("name","String","name"),("category","String","category"),
    ("mcc","BigInt","mcc"),("country","String","country"),("riskFlag","BigInt","riskFlag")]),
 ("Product", "dim_product", "productId", "name", [
    ("productId","String","productId"),("name","String","name"),("family","String","family")]),
 ("Branch", "dim_branch", "branchId", "name", [
    ("branchId","String","branchId"),("name","String","name"),("region","String","region")]),
 ("Transaction", "fact_transaction", "txnId", "txnId", [
    ("txnId","String","txnId"),("cardId","String","cardId"),("accountId","String","accountId"),
    ("customerId","String","customerId"),("merchantId","String","merchantId"),("amount","Double","amount"),
    ("currency","String","currency"),("channel","String","channel"),("geoCountry","String","geoCountry"),
    ("mcc","BigInt","mcc"),("isFraud","Boolean","isFraud"),("fraudType","String","fraudType"),
    ("customerKey","String","customerKey")]),
 ("FraudAlert", "fact_fraud_alert", "alertId", "alertId", [
    ("alertId","String","alertId"),("txnId","String","txnId"),("cardId","String","cardId"),
    ("customerId","String","customerId"),("alertType","String","type"),("severity","String","severity"),
    ("status","String","status"),("customerKey","String","customerKey")]),
 ("Loan", "fact_loan", "loanId", "loanId", [
    ("loanId","String","loanId"),("borrowerId","String","borrowerId"),("applicationId","String","applicationId"),
    ("principal","Double","principal"),("rate","Double","rate"),("termMonths","BigInt","termMonths"),
    ("balance","Double","balance"),("dpd","BigInt","dpd"),("customerKey","String","customerKey")]),
 ("DelinquencyEvent", "fact_delinquency", "eventId", "eventId", [
    ("eventId","String","eventId"),("loanId","String","loanId"),("dpdBucket","String","dpdBucket"),
    ("customerKey","String","customerKey")]),
]

# relationship: (RelName, SourceEntity, srcKeyCol, TargetEntity, tgtKeyCol, linkTable)
RELATIONSHIPS = [
 ("CustomerHoldsAccount","Customer","customerKey","Account","accountId","dim_account"),
 ("AccountRecordsTransaction","Account","accountId","Transaction","txnId","fact_transaction"),
 ("TransactionAtMerchant","Transaction","txnId","Merchant","merchantId","fact_transaction"),
 ("TransactionRaisesFraudAlert","Transaction","txnId","FraudAlert","alertId","fact_fraud_alert"),
 ("CustomerOwnsLoan","Customer","customerKey","Loan","loanId","fact_loan"),
 ("LoanHasDelinquency","Loan","loanId","DelinquencyEvent","eventId","fact_delinquency"),
 ("AccountOfProduct","Account","accountId","Product","productId","dim_account"),
 ("AccountAtBranch","Account","accountId","Branch","branchId","dim_account"),
 ("FraudAlertConcernsCustomer","FraudAlert","alertId","Customer","customerKey","fact_fraud_alert"),
]

# Time-series bindings: entity -> Eventhouse (KustoTable). Requires the static binding to already exist.
# Adds NEW timeseries property names (unique across the ontology) bound to the live Eventhouse table.
TS = {
 "Transaction": {
   "timestampCol": "eventTime",
   "tsProps": [("EventTime", "DateTime", "eventTime"), ("TsAmount", "Double", "amount")],
   "keyBinding": ("txnId", "txnId"),  # (sourceColumn, static key prop name)
 },
}

# ---- assign IDs ----
ent = {}   # name -> {id, keyPropId, dispPropId, props:{name->{id,valueType,col}}, table}
for ename, table, keycol, dispcol, props in ENTITIES:
    pmap = {}
    for pn, vt, col in props:
        pmap[pn] = {"id": big_id(f"{ename}.{pn}"), "valueType": vt, "col": col}
    ent[ename] = {"id": big_id(f"ET.{ename}"), "table": table,
                  "keyPropId": pmap[keycol]["id"], "dispPropId": pmap[dispcol]["id"],
                  "props": pmap, "keycol": keycol, "dispcol": dispcol}

# assign IDs for time-series properties
for ename, cfg in TS.items():
    tsmap = {}
    for pn, vt, col in cfg["tsProps"]:
        tsmap[pn] = {"id": big_id(f"{ename}.TS.{pn}"), "valueType": vt, "col": col}
    ent[ename]["tsProps"] = tsmap

def lake_source(table):
    return {"sourceType": "LakehouseTable", "workspaceId": WS, "itemId": LH,
            "sourceTableName": table, "sourceSchema": SCHEMA}

# ---- write parts ----
if os.path.exists(OUT):
    shutil.rmtree(OUT)
os.makedirs(PARTS, exist_ok=True)

def write(relpath, obj):
    full = os.path.join(PARTS, relpath.replace("/", os.sep))
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=2)

write(".platform", {"metadata": {"type": "Ontology", "displayName": "NorthwindOntology"}})
write("definition.json", {})

for ename, e in ent.items():
    etid = e["id"]
    props = [{"id": p["id"], "name": pn, "valueType": p["valueType"]}
             for pn, p in e["props"].items()]
    et_def = {
        "id": etid, "namespace": "usertypes", "name": ename,
        "entityIdParts": [e["keyPropId"]], "displayNamePropertyId": e["dispPropId"],
        "namespaceType": "Custom", "visibility": "Visible", "properties": props}
    if "tsProps" in e:
        et_def["timeseriesProperties"] = [{"id": p["id"], "name": pn, "valueType": p["valueType"]}
                                          for pn, p in e["tsProps"].items()]
    write(f"EntityTypes/{etid}/definition.json", et_def)
    # single NonTimeSeries static binding to the gold table
    binding_id = guid(f"{ename}.static")
    write(f"EntityTypes/{etid}/DataBindings/{binding_id}.json", {
        "id": binding_id,
        "dataBindingConfiguration": {
            "dataBindingType": "NonTimeSeries",
            "propertyBindings": [{"sourceColumnName": p["col"], "targetPropertyId": p["id"]}
                                  for p in e["props"].values()],
            "sourceTableProperties": lake_source(e["table"])}})
    # optional TimeSeries binding to the Eventhouse
    if ename in TS:
        cfg = TS[ename]
        keycol, keyprop = cfg["keyBinding"]
        pbinds = [{"sourceColumnName": p["col"], "targetPropertyId": p["id"]} for p in e["tsProps"].values()]
        pbinds.append({"sourceColumnName": keycol, "targetPropertyId": e["props"][keyprop]["id"]})
        ts_id = guid(f"{ename}.timeseries")
        write(f"EntityTypes/{etid}/DataBindings/{ts_id}.json", {
            "id": ts_id,
            "dataBindingConfiguration": {
                "dataBindingType": "TimeSeries",
                "timestampColumnName": cfg["timestampCol"],
                "propertyBindings": pbinds,
                "sourceTableProperties": {
                    "sourceType": "KustoTable", "workspaceId": WS, "itemId": EH_ID,
                    "clusterUri": EH_CLUSTER, "databaseName": EH_DB, "sourceTableName": EH_TABLE}}})

for rname, se, scol, te, tcol, link in RELATIONSHIPS:
    rid = big_id(f"REL.{rname}")
    write(f"RelationshipTypes/{rid}/definition.json", {
        "namespace": "usertypes", "id": rid, "name": rname, "namespaceType": "Custom",
        "source": {"entityTypeId": ent[se]["id"]},
        "target": {"entityTypeId": ent[te]["id"]}})
    cid = guid(f"CTX.{rname}")
    write(f"RelationshipTypes/{rid}/Contextualizations/{cid}.json", {
        "id": cid,
        "dataBindingTable": lake_source(link),
        "sourceKeyRefBindings": [{"sourceColumnName": scol, "targetPropertyId": ent[se]["keyPropId"]}],
        "targetKeyRefBindings": [{"sourceColumnName": tcol, "targetPropertyId": ent[te]["keyPropId"]}]})

# persist id map
idmap = {"ontologyName": "NorthwindOntology",
         "entityTypes": {n: {"id": e["id"], "table": e["table"], "key": e["keycol"],
                             "properties": {pn: p["id"] for pn, p in e["props"].items()}}
                          for n, e in ent.items()},
         "relationshipTypes": {r[0]: big_id(f"REL.{r[0]}") for r in RELATIONSHIPS}}
with open(os.path.join(OUT, "ontology_ids.json"), "w", encoding="utf-8") as f:
    json.dump(idmap, f, indent=2)

n = sum(len(files) for _, _, files in os.walk(PARTS))
print(f"Generated {n} ontology parts under {PARTS}")
print(f"Entities: {len(ENTITIES)}  Relationships: {len(RELATIONSHIPS)}")
