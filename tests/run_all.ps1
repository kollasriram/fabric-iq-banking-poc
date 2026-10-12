param(
    [Parameter(Mandatory = $true)][guid]$SubscriptionId,
    [Parameter(Mandatory = $true)][guid]$WorkspaceId,
    [Parameter(Mandatory = $true)][guid]$LakehouseId,
    [Parameter(Mandatory = $true)][guid]$ModelId,
    [Parameter(Mandatory = $true)][guid]$PrepModelId,
    [Parameter(Mandatory = $true)][uri]$QueryUri,
    [Parameter(Mandatory = $true)][datetimeoffset]$SeedStartUtc,
    [Parameter(Mandatory = $true)][datetimeoffset]$SeedEndUtc,
    [switch]$IncludeGraph,
    [guid]$GraphId,
    [int]$ExpectedBothLobs,
    [string]$OutputDirectory = "$PSScriptRoot\out\run-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'))"
)
$ErrorActionPreference = "Stop"
# Orchestrates the full positive/negative test suite across all four engines,
# aggregates PASS/FAIL, adds a cross-engine consistency check, writes results.json.
#
# Matrix:
#   Spark (gold)  SP-P1..P5 positive, SP-N1..N7 negative (entity resolution, no over-merge, subset)
#   DAX  (model)  DX-P1..P3 positive, DX-N1..N2 negative (impossible filter, strict subset)
#   GQL  (graph)  GQ-P1..P4 positive, GQ-N1..N2 negative (nonexistent key, subset)
#   KQL  (RTI)    KQ-P1..P3 positive, KQ-N1..N3 negative (rule specificity, selectivity)
#   Prep-AI       PA-P1..P3 positive (descriptions/folders present), PA-N1..N2 negative (<=200 chars)
#   Cross-engine  XE-1 the cross-domain answer (13) is identical on Spark == DAX == GQL

$root   = $PSScriptRoot
$repo   = Split-Path $root -Parent
$outDir = $OutputDirectory
if (Test-Path -LiteralPath $outDir) { throw "Use a new OutputDirectory; existing results must not be reused" }
if ($IncludeGraph -and ($GraphId -eq [guid]::Empty -or $ExpectedBothLobs -lt 1)) { throw "IncludeGraph requires GraphId and ExpectedBothLobs" }
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$livyOut = Join-Path $outDir "livy.txt"
$target = @{ SubscriptionId = $SubscriptionId; WorkspaceId = $WorkspaceId; OutputDirectory = $outDir }

Write-Host "==================== SPARK (gold) ===================="
& "$repo\deploy\lib_livy_run.ps1" -PyFile "$root\test_spark.py" -SubscriptionId $SubscriptionId -WorkspaceId $WorkspaceId -LakehouseId $LakehouseId -LogPath $livyOut
$raw = Get-Content $livyOut -Raw
$m = [regex]::Match($raw, "===TESTJSON_START===\s*(.+?)\s*===TESTJSON_END===", "Singleline")
if (-not $m.Success) { throw "Spark test JSON markers not found in $livyOut" }
$m.Groups[1].Value | Out-File "$outDir\spark.json" -Encoding utf8

Write-Host "`n==================== DAX (semantic model) ===================="
& "$root\test_dax.ps1" @target -ModelId $ModelId
if ($IncludeGraph) {
    Write-Host "`n==================== GQL (ontology graph) ===================="
    & "$root\test_gql.ps1" @target -GraphId $GraphId -ExpectedBothLobs $ExpectedBothLobs
} else {
    Write-Host "GQL skipped: graph checks require explicit IncludeGraph"
}
Write-Host "`n==================== KQL (Eventhouse RTI) ===================="
& "$root\test_kql.ps1" -SubscriptionId $SubscriptionId -QueryUri $QueryUri -StartTimeUtc $SeedStartUtc -EndTimeUtc $SeedEndUtc -OutputDirectory $outDir
Write-Host "`n==================== PREP FOR AI (semantic model metadata) ===================="
& "$root\test_prep_ai.ps1" @target -ModelId $PrepModelId

# ---------- Aggregate ----------
$all = @()
$engines = @("spark", "dax", "kql", "prep_ai")
if ($IncludeGraph) { $engines += "gql" }
foreach ($f in $engines) {
    $j = Get-Content "$outDir\$f.json" -Raw | ConvertFrom-Json
    $all += $j
}

# ---------- Cross-engine consistency ----------
$sp = ($all | Where-Object id -eq "SP-P3").actual
$dx = ($all | Where-Object id -eq "DX-P1").actual
$xeOk = ($sp -eq 13 -and $dx -eq 13 -and $sp -eq $dx)
$actual = "$sp/$dx"
$expected = "13/13"
if ($IncludeGraph) {
    $gq = ($all | Where-Object id -eq "GQ-P1").actual
    $xeOk = $xeOk -and $gq -eq 13
    $actual += "/$gq"
    $expected += "/13"
}
$all += [pscustomobject]@{ id = "XE-1"; engine = "cross"; kind = "pos"
    desc = "Cross-domain answer identical on selected engines (=13)"
    expected = $expected; actual = $actual; cmp = "eq"; pass = [bool]$xeOk }

# ---------- Report ----------
$all | ConvertTo-Json -Depth 4 | Out-File "$outDir\results.json" -Encoding utf8

Write-Host "`n==================== SUMMARY ===================="
$all | Format-Table id, engine, kind, expected, actual, pass -AutoSize | Out-String | Write-Host
$total = $all.Count
$passed = ($all | Where-Object pass).Count
$pos = ($all | Where-Object kind -eq "pos")
$neg = ($all | Where-Object kind -eq "neg")
Write-Host ("POSITIVE: {0}/{1}" -f ($pos | Where-Object pass).Count, $pos.Count)
Write-Host ("NEGATIVE: {0}/{1}" -f ($neg | Where-Object pass).Count, $neg.Count)
Write-Host ("OVERALL : {0}/{1}" -f $passed, $total)
if ($passed -lt $total) {
    Write-Host "`nFAILURES:" -ForegroundColor Red
    $all | Where-Object { -not $_.pass } | Format-Table id, engine, desc, expected, actual -AutoSize | Out-String | Write-Host
    exit 1
}
Write-Host "`nALL TESTS GREEN" -ForegroundColor Green
