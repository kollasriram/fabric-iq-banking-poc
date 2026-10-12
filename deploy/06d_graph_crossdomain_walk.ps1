$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$graph = "00000000-0000-0000-0000-000000000011"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"
function GQL($label, $q) {
    $H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
    $body = @{ query = $q } | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$base/GraphModels/$graph/executeQuery?preview=true" -Body $body
        Write-Host "=== $label ==="
        if ($r.status.code -eq "00000") { $r.result.data | ConvertTo-Json -Depth 6 }
        else { Write-Host "status: $($r.status | ConvertTo-Json -Compress)" }
    } catch {
        Write-Host "=== $label (ERROR) ==="; Write-Host $_.Exception.Message
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    }
}

# Entity resolution: customers spanning BOTH subject areas (deposits + lending)
GQL "Customers in BOTH LOBs (deposits + loans)" @"
MATCH (c:Customer)-[:CustomerHoldsAccount]->(:Account)
MATCH (c)-[:CustomerOwnsLoan]->(:Loan)
RETURN count(DISTINCT c.customerKey) AS both_lobs
"@

# HEADLINE cross-domain walk: fraud (Area A) -> customer -> loan -> delinquency (Area B)
GQL "Delinquent borrowers WITH fraud alerts (cross-domain walk)" @"
MATCH (fa:FraudAlert)-[:FraudAlertConcernsCustomer]->(c:Customer)-[:CustomerOwnsLoan]->(l:Loan)-[:LoanHasDelinquency]->(d:DelinquencyEvent)
RETURN count(DISTINCT c.customerKey) AS delinquent_borrowers_with_fraud
"@

# Same, with names + exposure (top few)
GQL "Cross-domain detail (names)" @"
MATCH (fa:FraudAlert)-[:FraudAlertConcernsCustomer]->(c:Customer)-[:CustomerOwnsLoan]->(l:Loan)-[:LoanHasDelinquency]->(d:DelinquencyEvent)
RETURN DISTINCT c.name AS name, c.paymentsCustomerId AS paymentsId, c.borrowerId AS borrowerId
LIMIT 8
"@
