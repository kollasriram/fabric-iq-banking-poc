$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$onto = (Get-Content YOUR_LOCAL_WORK_ROOT\_iq_onto_id.txt -Raw).Trim()
$partsRoot = "YOUR_PROJECT_ROOT\03-ontology\NorthwindOntology\parts"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$parts = @()
Get-ChildItem -Recurse -File $partsRoot | ForEach-Object {
    $rel = $_.FullName.Substring($partsRoot.Length + 1).Replace("\", "/")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $parts += @{ path = $rel; payload = $b64; payloadType = "InlineBase64" }
}
Write-Host "Parts: $($parts.Count)"
$body = @{ definition = @{ parts = $parts } } | ConvertTo-Json -Depth 10
$r = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$onto/updateDefinition" -Body $body
$op = $r.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
Write-Host "updateDefinition HTTP $($r.StatusCode) op=$op"
if ($op) {
    do { Start-Sleep 5; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted"))
    Write-Host "status=$($st.status)"
    if ($st.status -ne 'Succeeded') { $st | ConvertTo-Json -Depth 10 | Out-File YOUR_LOCAL_WORK_ROOT\_iq_onto_upd_err.json -Encoding utf8; throw "update failed" }
}

# verify the TS binding is present via getDefinition round-trip
Start-Sleep 3
$H.Authorization = "Bearer $(Tok)"
$d = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$onto/getDefinition"
$op = $d.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
if ($op) { do { Start-Sleep 3; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); $def = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result" } else { $def = $d.Content | ConvertFrom-Json }
$tsParts = $def.definition.parts | Where-Object { $_.path -like "*DataBindings*" } | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.payload)) } | Where-Object { $_ -like "*TimeSeries*" }
Write-Host "`n=== TimeSeries binding(s) found: $($tsParts.Count) ==="
$tsParts
