$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$graph = "00000000-0000-0000-0000-000000000011"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"
# Handles the GQL continuation-token paging (status 02000 = more pages)
function GQL($label, $q) {
    Write-Host "`n=== $label ==="
    $rows = @(); $ct = $null; $guard = 0; $r = $null
    do {
        $H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
        $payload = @{ query = $q }; if ($ct) { $payload.continuationToken = $ct }
        $body = $payload | ConvertTo-Json
        try {
            $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$base/GraphModels/$graph/executeQuery?preview=true" -Body $body
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)"; if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }; return
        }
        if ($r.result.data) { $rows += $r.result.data }
        $ct = $r.result.continuationToken
        $guard++
    } while ($ct -and $guard -lt 20)
    if ($rows.Count) { $rows | ConvertTo-Json -Depth 6 } else { Write-Host "status: $($r.status | ConvertTo-Json -Compress)" }
}

# CENTRALITY — hub merchants by fraud transaction volume (light 2-hop)
GQL "Hub merchants by fraud txn volume" @"
MATCH (t:Transaction)-[:TransactionAtMerchant]->(m:Merchant)
WHERE t.isFraud = true
RETURN m.merchantId AS merchant, count(t) AS fraud_txns
GROUP BY merchant
ORDER BY fraud_txns DESC
LIMIT 8
"@

# RING detection — filter to seeded ring activity first (small), then distinct members per merchant
GQL "Fraud rings — shared merchants + distinct ring members" @"
MATCH (c:Customer)-[:CustomerHoldsAccount]->(:Account)-[:AccountRecordsTransaction]->(t:Transaction)-[:TransactionAtMerchant]->(m:Merchant)
WHERE t.fraudType CONTAINS 'Ring'
RETURN m.merchantId AS merchant, count(DISTINCT c.customerKey) AS ring_members
GROUP BY merchant
ORDER BY ring_members DESC
LIMIT 10
"@

# 2-hop impact — customers exposed to high-risk (flagged) merchants
GQL "Customers within 2 hops of a high-risk merchant" @"
MATCH (m:Merchant)<-[:TransactionAtMerchant]-(t:Transaction)<-[:AccountRecordsTransaction]-(:Account)<-[:CustomerHoldsAccount]-(c:Customer)
WHERE m.riskFlag = 1
RETURN count(DISTINCT c.customerKey) AS exposed_customers, count(DISTINCT m.merchantId) AS risky_merchants
"@
