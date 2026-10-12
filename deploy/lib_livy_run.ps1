param(
    [Parameter(Mandatory = $true)][string]$PyFile,
    [string]$SessionId = "",
    [switch]$KeepSession,
    [int]$StatementTimeoutSec = 1800,
    [ValidateRange(1, 3600)][int]$SessionTimeoutSec = 600,
    [string]$SubscriptionId = "00000000-0000-0000-0000-000000000002",
    [string]$WorkspaceId = "00000000-0000-0000-0000-000000000003",
    [string]$LakehouseId = "00000000-0000-0000-0000-000000000005",
    [string]$LogPath = "YOUR_LOCAL_WORK_ROOT\_livy_out.txt"
)
$ErrorActionPreference = "Stop"
$sub = $SubscriptionId
$ws  = $WorkspaceId
$lh  = $LakehouseId
function Get-Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
# Retry transient network faults (connection reset/timeout) common on long Livy polls.
function Invoke-Retry([scriptblock]$Action, [int]$Max = 5) {
    for ($i = 1; $i -le $Max; $i++) {
        try { return & $Action }
        catch { if ($i -eq $Max) { throw }; Write-Host "  transient error (attempt $i): $($_.Exception.Message)"; Start-Sleep ([Math]::Min(30, 4 * $i)) }
    }
}
$H = @{ Authorization = "Bearer $(Get-Tok)"; "Content-Type" = "application/json" }
$livy = "https://api.fabric.microsoft.com/v1/workspaces/$ws/lakehouses/$lh/livyapi/versions/2023-12-01/sessions"

$createdSession = $false
try {
if (-not $SessionId) {
    $body = @{ name = "iq-build-$((Get-Date).ToString('HHmmss'))"; driverMemory = "28g"; driverCores = 4; executorMemory = "28g"; executorCores = 4; conf = @{ "spark.dynamicAllocation.enabled" = "true"; "spark.fabric.pool.name" = "Starter Pool" } } | ConvertTo-Json
    $s = Invoke-RestMethod -Headers $H -Method Post -Uri $livy -Body $body
    $SessionId = $s.id
    $createdSession = $true
    Write-Host "Session $SessionId starting..."
    $startupDeadline = (Get-Date).AddSeconds($SessionTimeoutSec)
    do {
        Start-Sleep 8
        $H.Authorization = "Bearer $(Get-Tok)"
        $st = (Invoke-Retry { Invoke-RestMethod -Headers $H -Uri "$livy/$SessionId" }).state
        Write-Host "  state=$st"
    } while ($st -notin @("idle", "error", "dead", "killed") -and (Get-Date) -lt $startupDeadline)
    if ($st -ne "idle") { throw "Session failed to start: $st" }
}

$code = Get-Content $PyFile -Raw
$stmtBody = @{ code = $code; kind = "pyspark" } | ConvertTo-Json
$stmt = Invoke-RestMethod -Headers $H -Method Post -Uri "$livy/$SessionId/statements" -Body $stmtBody
$sid = $stmt.id
Write-Host "Statement $sid submitted..."
$deadline = (Get-Date).AddSeconds($StatementTimeoutSec)
do {
    Start-Sleep 6
    $H.Authorization = "Bearer $(Get-Tok)"
    $r = Invoke-Retry { Invoke-RestMethod -Headers $H -Uri "$livy/$SessionId/statements/$sid" }
} while ($r.state -notin @("available", "error", "cancelled") -and (Get-Date) -lt $deadline)

$log = $LogPath
if ($r.output.status -eq "ok") {
    $txt = $r.output.data.'text/plain'
    $txt | Out-File $log -Encoding utf8
    Write-Host "--- OUTPUT ---"; Write-Host $txt
} else {
    $err = "ERROR $($r.output.ename): $($r.output.evalue)`n" + ($r.output.traceback -join "`n")
    $err | Out-File $log -Encoding utf8
    Write-Host "--- ERROR ---"; Write-Host $err
    throw "Spark statement did not succeed (state=$($r.state)); see $log"
}
Write-Host "SESSION_ID=$SessionId"
} finally {
if ($createdSession -and -not $KeepSession) {
    $H.Authorization = "Bearer $(Get-Tok)"
    Invoke-RestMethod -Headers $H -Method Delete -Uri "$livy/$SessionId" | Out-Null
    Write-Host "Session deleted."
}
}
