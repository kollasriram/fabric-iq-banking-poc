$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindTxnStream"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$es = (Invoke-RestMethod -Headers $H -Uri "$base/eventstreams").value | Where-Object displayName -eq $name
if (-not $es) {
    $r = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/eventstreams" -Body (@{ displayName = $name } | ConvertTo-Json)
    $op = $r.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
    Write-Host "HTTP $($r.StatusCode) op=$op"
    if ($op) { do { Start-Sleep 5; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); Write-Host "create=$($st.status)" }
    Start-Sleep 3
    $es = (Invoke-RestMethod -Headers $H -Uri "$base/eventstreams").value | Where-Object displayName -eq $name
}
Write-Host "ESID=$($es.id)"
$es.id | Out-File YOUR_LOCAL_WORK_ROOT\_iq_es_id.txt -Encoding utf8

# fetch the default topology definition
$H.Authorization = "Bearer $(Tok)"
$d = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/eventstreams/$($es.id)/getDefinition"
$op = $d.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
if ($d.StatusCode -eq 202 -and $op) {
    do { Start-Sleep 4; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted"))
    $def = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result"
} else { $def = $d.Content | ConvertFrom-Json }
$def.definition.parts | ForEach-Object { Write-Host "PART: $($_.path)"; if ($_.path -like "*.json") { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.payload)) | Out-File "YOUR_LOCAL_WORK_ROOT\_iq_es_$($_.path -replace '[\\/]','_').txt" -Encoding utf8 } }
Write-Host "definition parts written."
