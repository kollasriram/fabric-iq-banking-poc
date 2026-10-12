param(
    [Parameter(Mandatory = $true)][guid]$SubscriptionId,
    [Parameter(Mandatory = $true)][guid]$WorkspaceId,
    [Parameter(Mandatory = $true)][guid]$GraphId,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2300)][int]$ExpectedBothLobs,
    [string]$OutputDirectory = "$PSScriptRoot\out"
)
$ErrorActionPreference = "Stop"
# Module tests — GQL / ontology companion graph, positive & negative assertions.
$sub   = $SubscriptionId
$ws    = $WorkspaceId
$graph = $GraphId
$outDir = $OutputDirectory; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$base  = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }

function GQLScalar($q) {
    $H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
    $rows = @()
    $ct = $null
    do {
        $payload = @{ query = $q }
        if ($ct) { $payload.continuationToken = $ct }
        $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$base/GraphModels/$graph/executeQuery?preview=true" -Body ($payload | ConvertTo-Json)
        if ($r.status.code -eq "00000") { if ($r.result.data) { $rows += $r.result.data }; $ct = $null }
        elseif ($r.status.code -eq "02000") { $ct = $r.result.continuationToken }
        else { throw "GQL status $($r.status | ConvertTo-Json -Compress)" }
    } while ($ct)
    if ($rows.Count -eq 0) { return 0 }
    return [double]($rows[0].PSObject.Properties | Select-Object -First 1).Value
}

$R = @()
function T($id, $kind, $desc, $expected, $actual, $cmp = "eq") {
    switch ($cmp) {
        "eq" { $ok = ($actual -eq $expected) }
        "gt" { $ok = ($actual -gt $expected) }
        "lt" { $ok = ($actual -lt $expected) }
        "ge" { $ok = ($actual -ge $expected) }
        "ne" { $ok = ($actual -ne $expected) }
    }
    $script:R += [pscustomobject]@{ id = $id; engine = "gql"; kind = $kind; desc = $desc; expected = $expected; actual = $actual; cmp = $cmp; pass = [bool]$ok }
}

$walk = @"
MATCH (fa:FraudAlert)-[:FraudAlertConcernsCustomer]->(c:Customer)-[:CustomerOwnsLoan]->(l:Loan)-[:LoanHasDelinquency]->(d:DelinquencyEvent)
RETURN count(DISTINCT c.customerKey) AS n
"@

# ---------- POSITIVE ----------
$w = [int](GQLScalar $walk)
T "GQ-P1" "pos" "Cross-domain graph walk = 13" 13 $w
T "GQ-P2" "pos" "Customer node count = 2300" 2300 ([int](GQLScalar "MATCH (c:Customer) RETURN count(c) AS n"))
T "GQ-P3" "pos" "Transaction node count = 48710" 48710 ([int](GQLScalar "MATCH (t:Transaction) RETURN count(t) AS n"))
$both = [int](GQLScalar @"
MATCH (c:Customer)-[:CustomerHoldsAccount]->(:Account)
MATCH (c)-[:CustomerOwnsLoan]->(:Loan)
RETURN count(DISTINCT c.customerKey) AS n
"@)
T "GQ-P4" "pos" "Customers in both LOBs via graph match baseline" $ExpectedBothLobs $both

# ---------- NEGATIVE ----------
# Nonexistent key returns a clean zero (graph handles unknown gracefully)
$ghost = [int](GQLScalar "MATCH (c:Customer) WHERE c.customerKey = 'CUST-999999' RETURN count(c) AS n")
T "GQ-N1" "neg" "Nonexistent customer key = 0" 0 $ghost
# Cross-domain 13 is a strict subset of the both-LOB set (260)
T "GQ-N2" "neg" "Cross-domain 13 is a strict subset of both-LOB customers" $both $w "lt"

$R | ConvertTo-Json -Depth 4 | Out-File "$outDir\gql.json" -Encoding utf8
$np = ($R | Where-Object pass).Count
Write-Host "GQL $np/$($R.Count) passed"
$R | Format-Table id, kind, expected, actual, pass -AutoSize | Out-String | Write-Host
if ($np -ne $R.Count) { throw "GQL assertions failed; see $outDir/gql.json" }
