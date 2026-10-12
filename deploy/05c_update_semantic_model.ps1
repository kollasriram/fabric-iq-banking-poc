$ErrorActionPreference = "Stop"
# Updates NorthwindModel in place (updateDefinition) so the item id and any portal
# "Prep data for AI" state are preserved while the TMDL metadata is refreshed.
$sub  = "00000000-0000-0000-0000-000000000002"
$ws   = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindModel"
$root = "YOUR_PROJECT_ROOT\01-semantic-model\NorthwindModel.SemanticModel"
function Tok($res) { az account get-access-token --resource $res --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok 'https://api.fabric.microsoft.com')"; "Content-Type" = "application/json" }

$model = (Get-Content YOUR_LOCAL_WORK_ROOT\_iq_sm_id.txt -Raw).Trim()
if (-not $model) { $model = ((Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels").value | Where-Object displayName -eq $name).id }
Write-Host "Updating model $model"

$parts = @()
Get-ChildItem -Recurse -File $root | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $parts += @{ path = $rel; payload = $b64; payloadType = "InlineBase64" }
}
$body = @{ definition = @{ parts = $parts } } | ConvertTo-Json -Depth 6
$resp = Invoke-WebRequest -Headers $H -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels/$model/updateDefinition" -Body $body
Write-Host "updateDefinition HTTP $($resp.StatusCode)"
if ($resp.StatusCode -eq 202) {
    $op = $resp.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
    do {
        Start-Sleep 5
        $H.Authorization = "Bearer $(Tok 'https://api.fabric.microsoft.com')"
        $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op"
        Write-Host "  status=$($st.status)"
    } while ($st.status -in @("Running", "NotStarted"))
    if ($st.status -ne "Succeeded") { $st | ConvertTo-Json -Depth 8 | Out-File YOUR_LOCAL_WORK_ROOT\_iq_sm_err.json; throw "Update failed: $($st.status)" }
}

# Direct Lake framing refresh
$PH = @{ Authorization = "Bearer $(Tok 'https://analysis.windows.net/powerbi/api')"; "Content-Type" = "application/json" }
try {
    Invoke-RestMethod -Headers $PH -Method Post -Uri "https://api.powerbi.com/v1.0/myorg/groups/$ws/datasets/$model/refreshes" -Body '{"type":"full"}' | Out-Null
    Write-Host "Refresh triggered."
} catch { Write-Host "Refresh note: $($_.Exception.Message)" }
Start-Sleep 20
Write-Host "DONE $model"
