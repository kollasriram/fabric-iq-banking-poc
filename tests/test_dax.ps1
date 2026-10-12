param(
    [Parameter(Mandatory = $true)][guid]$SubscriptionId,
    [Parameter(Mandatory = $true)][guid]$WorkspaceId,
    [Parameter(Mandatory = $true)][guid]$ModelId,
    [string]$OutputDirectory = "$PSScriptRoot\out"
)
$ErrorActionPreference = "Stop"
# Module tests — DAX / Direct Lake semantic model, positive & negative assertions.
$sub   = $SubscriptionId
$ws    = $WorkspaceId
$model = $ModelId
$outDir = $OutputDirectory; New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$tok = az account get-access-token --resource https://analysis.windows.net/powerbi/api --subscription $sub --query accessToken -o tsv
$PH  = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$ws/datasets/$model/executeQueries"

function DAXScalar($q) {
    $body = @{ queries = @(@{ query = $q }) } | ConvertTo-Json -Depth 5
    $r = Invoke-RestMethod -Headers $PH -Method Post -Uri $uri -Body $body
    $row = $r.results[0].tables[0].rows[0]
    if ($null -eq $row) { return 0 }
    return [double]($row.PSObject.Properties | Select-Object -First 1).Value
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
    $script:R += [pscustomobject]@{ id = $id; engine = "dax"; kind = $kind; desc = $desc; expected = $expected; actual = $actual; cmp = $cmp; pass = [bool]$ok }
}

$crossQ = 'EVALUATE ROW("v", [Delinquent With Fraud])'

# ---------- POSITIVE ----------
$cross = [int](DAXScalar $crossQ)
T "DX-P1" "pos" "Cross-domain DelinquentWithFraud = 13" 13 $cross
T "DX-P2" "pos" "Transaction Count = 48710" 48710 ([int](DAXScalar 'EVALUATE ROW("v",[Transaction Count])'))
T "DX-P3" "pos" "Deposit Balance = 126801285.56" 126801285.56 ([Math]::Round((DAXScalar 'EVALUATE ROW("v",[Deposit Balance])'), 2))

# ---------- NEGATIVE ----------
# Impossible region filter returns nothing
$atlantis = [int](DAXScalar 'EVALUATE ROW("v", CALCULATE([Transaction Count], dim_customer[region] = "Atlantis"))')
T "DX-N1" "neg" "Transactions for nonexistent region = 0" 0 $atlantis
# Cross-domain is a strict subset of all fraud customers (not returning everyone)
$fraudTotal = [int](DAXScalar 'EVALUATE ROW("v",[Customers With Fraud Alert])')
T "DX-N2" "neg" "Cross-domain 13 < total fraud customers" $cross $fraudTotal "gt"

$R | ConvertTo-Json -Depth 4 | Out-File "$outDir\dax.json" -Encoding utf8
$np = ($R | Where-Object pass).Count
Write-Host "DAX $np/$($R.Count) passed"
$R | Format-Table id, kind, expected, actual, pass -AutoSize | Out-String | Write-Host
if ($np -ne $R.Count) { throw "DAX assertions failed; see $outDir/dax.json" }
