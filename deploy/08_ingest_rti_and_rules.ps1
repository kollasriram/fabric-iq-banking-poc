$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$query = "https://YOUR_KQL_CLUSTER.kusto.fabric.microsoft.com"
$db = "NorthwindRTI"
function KTok { az account get-access-token --resource https://api.kusto.windows.net --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(KTok)"; "Content-Type" = "application/json" }
function Kmgmt($csl) { Invoke-RestMethod -Headers $H -Method Post -Uri "$query/v1/rest/mgmt" -Body (@{ db = $db; csl = $csl } | ConvertTo-Json) }
function Kq($csl) { Invoke-RestMethod -Headers $H -Method Post -Uri "$query/v1/rest/query" -Body (@{ db = $db; csl = $csl } | ConvertTo-Json) }

# clear + ingest
Kmgmt ".clear table LiveTransactions data" | Out-Null
$batches = Get-Content YOUR_PROJECT_ROOT\07-realtime-fraud\_rti_batches.json -Raw | ConvertFrom-Json
$i = 0
foreach ($b in $batches) { $i++; $H.Authorization = "Bearer $(KTok)"; Kmgmt $b | Out-Null; Write-Host "  ingested batch $i/$($batches.Count)" }
Start-Sleep 3
$H.Authorization = "Bearer $(KTok)"
$cnt = (Kq "LiveTransactions | count").Tables[0].Rows[0][0]
Write-Host "LiveTransactions rows = $cnt"

function Rule($label, $csl) {
    $H.Authorization = "Bearer $(KTok)"
    Write-Host "`n=== $label ==="
    (Kq $csl).Tables[0].Rows | ConvertTo-Json -Compress
}

Rule "Rule1 High-value cross-border (amount>10k, geo<>home)" @"
LiveTransactions | where amount > 10000 and geoCountry != homeCountry
| summarize alerts=count(), exposure=round(sum(amount),0)
"@

Rule "Rule2 Card velocity (>=3 merchants in 5 min)" @"
let W=5m;
LiveTransactions | project cardId, merchantId, eventTime
| join kind=inner (LiveTransactions | project cardId, m2=merchantId, t2=eventTime) on cardId
| where t2 between (eventTime .. eventTime+W)
| summarize distinctMerch=dcount(m2) by cardId, anchor=eventTime
| where distinctMerch >= 3
| summarize velocity_cards=dcount(cardId)
"@

Rule "Rule3 Impossible travel (2 countries same card in 30 min)" @"
let W=30m;
LiveTransactions | project cardId, geoCountry, eventTime
| join kind=inner (LiveTransactions | project cardId, g2=geoCountry, t2=eventTime) on cardId
| where t2 between (eventTime .. eventTime+W) and g2 != geoCountry
| summarize impossible_travel_cards=dcount(cardId)
"@

Rule "Rule4 High-risk merchant transactions" @"
LiveTransactions | where merchantRisk == true
| summarize alerts=count(), distinct_cards=dcount(cardId), distinct_merchants=dcount(merchantId)
"@
