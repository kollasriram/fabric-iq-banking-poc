param(
    [string]$PythonExecutable = "python"
)
$ErrorActionPreference = "Stop"
$repo = Split-Path $PSScriptRoot -Parent

foreach ($file in @((Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.ps1)) + (Get-Item "$repo\deploy\lib_livy_run.ps1")) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}
Write-Host "PASS: PowerShell test syntax"

foreach ($file in Get-ChildItem -LiteralPath $repo -Filter *.ipynb -Recurse) {
    Get-Content -LiteralPath $file.FullName -Raw | & $PythonExecutable -c 'import json,sys,nbformat; notebook=json.load(sys.stdin); ids=[cell.get("id") for cell in notebook["cells"]]; assert notebook.get("nbformat_minor",0)<5 or (all(ids) and len(set(ids))==len(ids)); nbformat.validate(notebook)'
    if ($LASTEXITCODE -ne 0) { throw "Notebook schema failed: $($file.FullName)" }
}
Write-Host "PASS: repository notebook schemas"

function Invoke-FixtureTest {
    param([string]$Name, [hashtable]$Arguments, [double[]]$Values, [int]$ExpectedAssertions, [switch]$ExpectFailure)
    $output = Join-Path ([IO.Path]::GetTempPath()) ("fabric-iq-test-" + [guid]::NewGuid())
    $Arguments.OutputDirectory = $output
    $responses = [Collections.Generic.Queue[double]]::new()
    foreach ($value in $Values) { $responses.Enqueue($value) }
    $requests = [Collections.Generic.List[object]]::new()
    function az { "offline-test-token" }
    function Invoke-RestMethod {
        param($Headers, $Method, $Uri, $Body)
        if ($responses.Count -eq 0) { throw "Unexpected query in $Name" }
        $payload = $Body | ConvertFrom-Json
        $queryText = if ($payload.csl) { $payload.csl } else { $payload.queries[0].query }
        $requests.Add([pscustomobject]@{ uri = $Uri; query = $queryText })
        $value = $responses.Dequeue()
        [pscustomobject]@{
            Tables = @([pscustomobject]@{ Rows = @(,@($value)) })
            results = @([pscustomobject]@{ tables = @([pscustomobject]@{ rows = @([pscustomobject]@{ value = $value }) }) })
        }
    }
    try {
        $failed = $false
        try { & (Join-Path $PSScriptRoot $Name) @Arguments }
        catch {
            if (-not $ExpectFailure -or $_.Exception.Message -notmatch 'assertions failed') { throw }
            $failed = $true
        }
        $resultName = switch ($Name) {
            "test_dax.ps1" { "dax.json" }
            "test_kql.ps1" { "kql.json" }
            "test_prep_ai.ps1" { "prep_ai.json" }
        }
        $results = @(Get-Content -LiteralPath (Join-Path $output $resultName) -Raw | ConvertFrom-Json)
        $failures = @($results | Where-Object { -not $_.pass }).Count
        if ($results.Count -ne $ExpectedAssertions -or ($ExpectFailure -and (-not $failed -or -not $failures)) -or (-not $ExpectFailure -and $failures)) { throw "Fixture assertions failed: $Name" }
        if ($responses.Count) { throw "Unused query fixtures: $Name" }
        if ($Name -eq "test_dax.ps1" -and $requests[0].query -notmatch '\[Delinquent With Fraud\]') { throw "DAX must query the saved headline measure" }
        if ($Name -eq "test_kql.ps1") {
            foreach ($request in $requests | Where-Object { $_.query -notmatch 'getschema' }) {
                if ($request.query -notmatch 'eventTime between') { throw "Unbounded KQL test query" }
            }
        }
        Write-Host "PASS: $Name $($Arguments.Mode) fixture assertions"
    } finally {
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
    }
}

$subscription = "00000000-0000-0000-0000-000000000001"
Invoke-FixtureTest "test_dax.ps1" @{
    SubscriptionId = $subscription
    WorkspaceId = "00000000-0000-0000-0000-000000000002"
    ModelId = "00000000-0000-0000-0000-000000000003"
} @(13, 48710, 126801285.56, 0, 194) 5
Invoke-FixtureTest "test_prep_ai.ps1" @{
    SubscriptionId = $subscription
    WorkspaceId = "00000000-0000-0000-0000-000000000002"
    ModelId = "00000000-0000-0000-0000-000000000003"
} @(9, 9, 9, 68, 68, 160, 100) 7

$kql = @{
    SubscriptionId = $subscription
    QueryUri = "https://example.kusto.fabric.microsoft.com"
    StartTimeUtc = "2026-05-21T12:21:58Z"
    EndTimeUtc = "2026-09-19T11:09:48Z"
    Mode = "Seed"
}
Invoke-FixtureTest "test_kql.ps1" $kql @(6710, 500, 1373, 194, 148, 0, 0, 1373) 8
$kql.Mode = "Live"
$kql.StartTimeUtc = "2026-10-12T17:48:11.044178Z"
$kql.EndTimeUtc = "2026-10-12T17:48:11.692229Z"
$kql.ReferenceTxnId = "TX-00047000"
$kql.ReferenceTimeUtc = "2026-10-12T17:48:11.649361Z"
$kql.ReferenceAmount = 33130.5
$kql.ReferenceMerchantId = "MER-0003"
Invoke-FixtureTest "test_kql.ps1" $kql @(300, 300, 1, 15, 0, 0, 62) 7
Invoke-FixtureTest "test_dax.ps1" @{
    SubscriptionId = $subscription
    WorkspaceId = "00000000-0000-0000-0000-000000000002"
    ModelId = "00000000-0000-0000-0000-000000000003"
} @(0, 48710, 126801285.56, 0, 194) 5 -ExpectFailure
Invoke-FixtureTest "test_prep_ai.ps1" @{
    SubscriptionId = $subscription
    WorkspaceId = "00000000-0000-0000-0000-000000000002"
    ModelId = "00000000-0000-0000-0000-000000000003"
} @(0, 0, 0, 0, 0, 0, 0) 7 -ExpectFailure
Invoke-FixtureTest "test_kql.ps1" $kql @(299, 299, 1, 15, 0, 0, 62) 7 -ExpectFailure

function Test-LivyCleanup {
    param([switch]$FailStatement)
    $log = Join-Path ([IO.Path]::GetTempPath()) ("fabric-iq-livy-" + [guid]::NewGuid() + ".txt")
    $requests = [Collections.Generic.List[string]]::new()
    function az { "offline-test-token" }
    function Start-Sleep { }
    function Invoke-RestMethod {
        param($Headers, $Method, $Uri, $Body)
        $requests.Add("$Method $Uri")
        if ($Method -eq "Delete") { return }
        if ($Method -eq "Post") { return [pscustomobject]@{ id = 1 } }
        if ($Uri -match '/statements/1$') {
            return [pscustomobject]@{ state = "available"; output = @{ status = $(if ($FailStatement) { "error" } else { "ok" }); data = @{ "text/plain" = "fixture" }; ename = "FixtureError"; evalue = "expected failure" } }
        }
        return [pscustomobject]@{ state = "idle" }
    }
    try {
        $failed = $false
        try {
            & "$repo\deploy\lib_livy_run.ps1" -PyFile "$PSScriptRoot\test_spark.py" -SubscriptionId $subscription -WorkspaceId "00000000-0000-0000-0000-000000000002" -LakehouseId "00000000-0000-0000-0000-000000000003" -LogPath $log
        } catch {
            if (-not $FailStatement -or $_.Exception.Message -notmatch 'Spark statement did not succeed') { throw }
            $failed = $true
        }
        if ($failed -ne [bool]$FailStatement -or @($requests | Where-Object { $_ -like 'Delete */sessions/1' }).Count -ne 1) { throw "Livy failure signaling or cleanup failed" }
        Write-Host "PASS: Livy cleanup (statement failure=$FailStatement)"
    } finally {
        if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
    }
}
Test-LivyCleanup
Test-LivyCleanup -FailStatement
Write-Host "ALL OFFLINE TESTS PASSED"