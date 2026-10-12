$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$onto = (Get-Content YOUR_LOCAL_WORK_ROOT\_iq_onto_id.txt -Raw).Trim()
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$d = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$onto/getDefinition"
$op = $d.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
if ($op) { do { Start-Sleep 3; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); $def = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result" } else { $def = $d.Content | ConvertFrom-Json }

$ts = @()
foreach ($p in ($def.definition.parts | Where-Object { $_.path -like "*DataBindings*" })) {
    $j = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.payload)) | ConvertFrom-Json
    if ($j.dataBindingConfiguration.dataBindingType -eq "TimeSeries") {
        $src = $j.dataBindingConfiguration.sourceTableProperties
        $ts += [pscustomobject]@{ path = $p.path; sourceType = $src.sourceType; db = $src.databaseName; table = $src.sourceTableName; timestamp = $j.dataBindingConfiguration.timestampColumnName }
    }
}
Write-Host "TimeSeries bindings (exact): $($ts.Count)"
$ts | Format-List
