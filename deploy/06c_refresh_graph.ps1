$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$graph = "00000000-0000-0000-0000-000000000011"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

# Trigger graph materialization
Write-Host "Refreshing graph..."
$r = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$graph/jobs/instances?jobType=RefreshGraph" -Body '{}'
$loc = $r.Headers["Location"]; if ($loc -is [array]) { $loc = $loc[0] }
$jobId = ($loc -split "/")[-1]
Write-Host "  job=$jobId"
do {
    Start-Sleep 6
    $H.Authorization = "Bearer $(Tok)"
    $j = Invoke-RestMethod -Headers $H -Uri "$base/items/$graph/jobs/instances/$jobId"
    Write-Host "  $($j.status)"
} while ($j.status -in @("NotStarted", "InProgress", "Running"))
Write-Host "Graph refresh: $($j.status)"

# Query the graph via GQL
function GQL($q) {
    $H.Authorization = "Bearer $(Tok)"
    $body = @{ query = $q } | ConvertTo-Json
    try {
        $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$base/GraphModels/$graph/executeQuery?preview=true" -Body $body
        return $r
    } catch {
        Write-Host "GQL error: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
        return $null
    }
}

Write-Host "`n=== node counts (try entity-name labels) ==="
foreach ($lbl in @("Customer", "Account", "Transaction", "Merchant", "Loan", "FraudAlert", "DelinquencyEvent")) {
    $res = GQL "MATCH (n:$lbl) RETURN count(n) AS c"
    if ($res -and $res.status.code -eq "00000") {
        Write-Host ("  {0,-18} {1}" -f $lbl, ($res.result.data | ConvertTo-Json -Compress))
    }
}
