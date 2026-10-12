$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$query = "https://YOUR_KQL_CLUSTER.kusto.fabric.microsoft.com"
$db = "NorthwindRTI"

# try candidate Kusto token audiences until one authenticates
$resources = @("https://kusto.fabric.microsoft.com", "https://api.kusto.windows.net", $query)
$tok = $null; $used = $null
foreach ($res in $resources) {
    $t = az account get-access-token --resource $res --subscription $sub --query accessToken -o tsv 2>$null
    if ($t) {
        $H = @{ Authorization = "Bearer $t"; "Content-Type" = "application/json" }
        try {
            $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$query/v1/rest/mgmt" -Body (@{ db = $db; csl = ".show database schema | count" } | ConvertTo-Json)
            $tok = $t; $used = $res; Write-Host "AUTH OK with resource: $res"; break
        } catch { Write-Host "resource $res -> $($_.Exception.Message)" }
    }
}
if (-not $tok) { throw "No Kusto audience worked" }
$used | Out-File YOUR_LOCAL_WORK_ROOT\_iq_rti_kustores.txt -Encoding utf8

$H = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }
function Kmgmt($csl) { Invoke-RestMethod -Headers $H -Method Post -Uri "$query/v1/rest/mgmt" -Body (@{ db = $db; csl = $csl } | ConvertTo-Json) }

$create = @'
.create table LiveTransactions (txnId:string, cardId:string, accountId:string, customerId:string, merchantId:string, amount:real, currency:string, eventTime:datetime, channel:string, geoCountry:string, mcc:long, homeCountry:string, merchantRisk:bool, isFraud:bool, fraudType:string)
'@
Kmgmt $create | Out-Null
Write-Host "Table created."
# enable streaming ingestion policy on the table
Kmgmt ".alter table LiveTransactions policy streamingingestion enable" | Out-Null
$r = Kmgmt ".show table LiveTransactions cslschema"
$r.Tables[0].Rows | ConvertTo-Json -Compress
