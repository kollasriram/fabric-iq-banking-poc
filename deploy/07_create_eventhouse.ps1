$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws  = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindRTI"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$eh = (Invoke-RestMethod -Headers $H -Uri "$base/eventhouses").value | Where-Object displayName -eq $name
if (-not $eh) {
    $resp = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/eventhouses" -Body (@{ displayName = $name } | ConvertTo-Json)
    $op = $resp.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
    if ($op) {
        do { Start-Sleep 5; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running","NotStarted"))
        Write-Host "create status=$($st.status)"
    }
    Start-Sleep 4
    $eh = (Invoke-RestMethod -Headers $H -Uri "$base/eventhouses").value | Where-Object displayName -eq $name
}
Write-Host "EVENTHOUSE_ID=$($eh.id)"

# discover the KQL database
$kdb = (Invoke-RestMethod -Headers $H -Uri "$base/kqlDatabases").value | Where-Object { $_.properties.parentEventhouseItemId -eq $eh.id }
Write-Host "KQLDB_ID=$($kdb.id)  name=$($kdb.displayName)"
$kdb.properties | ConvertTo-Json -Depth 6 | Out-File YOUR_LOCAL_WORK_ROOT\_iq_rti_kdb.json -Encoding utf8
Get-Content YOUR_LOCAL_WORK_ROOT\_iq_rti_kdb.json -Raw
@{ eventhouseId = $eh.id; kqlDbId = $kdb.id; kqlDbName = $kdb.displayName; queryUri = $kdb.properties.queryServiceUri; ingestionUri = $kdb.properties.ingestionServiceUri } | ConvertTo-Json | Out-File YOUR_LOCAL_WORK_ROOT\_iq_rti_ids.json -Encoding utf8
