param(
    [Parameter(Mandatory = $true)][guid]$SubscriptionId,
    [Parameter(Mandatory = $true)][guid]$WorkspaceId,
    [Parameter(Mandatory = $true)][guid]$ModelId,
    [string]$OutputDirectory = "$PSScriptRoot\out"
)
$ErrorActionPreference = "Stop"
# Module tests — Prep for AI readiness (agent-editable TOM metadata), live via DAX INFO views.
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
    switch ($cmp) { "eq" { $ok = ($actual -eq $expected) } "gt" { $ok = ($actual -gt $expected) } "lt" { $ok = ($actual -lt $expected) } "ge" { $ok = ($actual -ge $expected) } "le" { $ok = ($actual -le $expected) } }
    $script:R += [pscustomobject]@{ id = $id; engine = "prep-ai"; kind = $kind; desc = $desc; expected = $expected; actual = $actual; cmp = $cmp; pass = [bool]$ok }
}

# ---------- POSITIVE (readiness metadata present) ----------
$m      = [int](DAXScalar 'EVALUATE ROW("v", COUNTROWS(INFO.VIEW.MEASURES()))')
$mDesc  = [int](DAXScalar 'EVALUATE ROW("v", COUNTROWS(FILTER(INFO.VIEW.MEASURES(), NOT ISBLANK([Description]))))')
$mFold  = [int](DAXScalar 'EVALUATE ROW("v", COUNTROWS(FILTER(INFO.VIEW.MEASURES(), NOT ISBLANK([DisplayFolder]))))')
$columns = [int](DAXScalar 'EVALUATE ROW("v", COUNTROWS(FILTER(INFO.VIEW.COLUMNS(), [IsHidden] = FALSE())))')
$colDsc = [int](DAXScalar 'EVALUATE ROW("v", COUNTROWS(FILTER(INFO.VIEW.COLUMNS(), [IsHidden] = FALSE() && NOT ISBLANK([Description]))))')
T "PA-P0" "pos" "Measure inventory is nonempty" 0 $m "gt"
T "PA-P1" "pos" "Every measure has a description" $m $mDesc
T "PA-P2" "pos" "Every measure has a display folder" $m $mFold
T "PA-PC0" "pos" "Visible column inventory is nonempty" 0 $columns "gt"
T "PA-P3" "pos" "Every visible column has a description" $columns $colDsc

# ---------- NEGATIVE (descriptions stay within Copilot's read window) ----------
$maxCol  = [int](DAXScalar 'EVALUATE ROW("v", MAXX(INFO.VIEW.COLUMNS(), LEN([Description])))')
$maxMeas = [int](DAXScalar 'EVALUATE ROW("v", MAXX(INFO.VIEW.MEASURES(), LEN([Description])))')
T "PA-N1" "neg" "No column description exceeds 200 chars" 200 $maxCol "le"
T "PA-N2" "neg" "No measure description exceeds 200 chars" 200 $maxMeas "le"

$R | ConvertTo-Json -Depth 4 | Out-File "$outDir\prep_ai.json" -Encoding utf8
$np = ($R | Where-Object pass).Count
Write-Host "PREP-AI $np/$($R.Count) passed"
$R | Format-Table id, kind, expected, actual, pass -AutoSize | Out-String | Write-Host
if ($np -ne $R.Count) { throw "Prep assertions failed; see $outDir/prep_ai.json" }
