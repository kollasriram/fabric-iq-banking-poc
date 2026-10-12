$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindDataAgent"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$da = (Invoke-RestMethod -Headers $H -Uri "$base/items?type=DataAgent").value | Where-Object displayName -eq $name
if (-not $da) {
    $r = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items" -Body (@{ displayName = $name; type = "DataAgent" } | ConvertTo-Json)
    $op = $r.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
    Write-Host "HTTP $($r.StatusCode) op=$op"
    if ($op) { do { Start-Sleep 5; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); Write-Host "create=$($st.status)"; if ($st.status -ne 'Succeeded') { $st | ConvertTo-Json -Depth 8 } }
    Start-Sleep 3
    $da = (Invoke-RestMethod -Headers $H -Uri "$base/items?type=DataAgent").value | Where-Object displayName -eq $name
}
Write-Host "DATAAGENT_ID=$($da.id)"
$da.id | Out-File YOUR_LOCAL_WORK_ROOT\_iq_da_id.txt -Encoding utf8

# dump the default definition
$H.Authorization = "Bearer $(Tok)"
$d = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$($da.id)/getDefinition"
$op = $d.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
if ($d.StatusCode -eq 202 -and $op) {
    do { Start-Sleep 4; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted"))
    $def = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result"
} else { $def = $d.Content | ConvertFrom-Json }
$def.definition.parts | ForEach-Object {
    Write-Host "PART: $($_.path)"
    $safe = ($_.path -replace '[\\/]', '_')
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.payload)) | Out-File "YOUR_LOCAL_WORK_ROOT\_iq_da_$safe.txt" -Encoding utf8
}
