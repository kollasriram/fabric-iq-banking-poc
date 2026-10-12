$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws  = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindModel"
$root = "YOUR_PROJECT_ROOT\01-semantic-model\NorthwindModel.SemanticModel"
function Tok($res) { az account get-access-token --resource $res --subscription $sub --query accessToken -o tsv }
$fabTok = Tok "https://api.fabric.microsoft.com"
$H = @{ Authorization = "Bearer $fabTok"; "Content-Type" = "application/json" }

# Build definition parts (base64) from the local TMDL tree
$parts = @()
Get-ChildItem -Recurse -File $root | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $parts += @{ path = $rel; payload = $b64; payloadType = "InlineBase64" }
}
Write-Host "Parts: $($parts.Count)"

# Delete existing model of same name (idempotent)
$items = (Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels").value
$ex = $items | Where-Object { $_.displayName -eq $name }
if ($ex) { Invoke-RestMethod -Headers $H -Method Delete -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels/$($ex.id)" | Out-Null; Write-Host "Deleted existing $($ex.id)"; Start-Sleep 3 }

$body = @{ displayName = $name; definition = @{ parts = $parts } } | ConvertTo-Json -Depth 6
$resp = Invoke-WebRequest -Headers $H -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels" -Body $body
if ($resp.StatusCode -eq 202) {
    $op = $resp.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
    Write-Host "LRO op=$op"
    do {
        Start-Sleep 5
        $H.Authorization = "Bearer $(Tok 'https://api.fabric.microsoft.com')"
        $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op"
        Write-Host "  status=$($st.status)"
    } while ($st.status -in @("Running", "NotStarted"))
    if ($st.status -ne "Succeeded") { $st | ConvertTo-Json -Depth 8 | Out-File YOUR_LOCAL_WORK_ROOT\_iq_sm_err.json; throw "Create failed: $($st.status)" }
    $modelId = (Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result").id
} else {
    $modelId = ($resp.Content | ConvertFrom-Json).id
}
if (-not $modelId) {
    $modelId = ((Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/semanticModels").value | Where-Object displayName -eq $name).id
}
Write-Host "MODEL_ID=$modelId"
$modelId | Out-File YOUR_LOCAL_WORK_ROOT\_iq_sm_id.txt -Encoding utf8

# Direct Lake framing refresh (Power BI API)
$pbiTok = Tok "https://analysis.windows.net/powerbi/api"
$PH = @{ Authorization = "Bearer $pbiTok"; "Content-Type" = "application/json" }
try {
    Invoke-RestMethod -Headers $PH -Method Post -Uri "https://api.powerbi.com/v1.0/myorg/groups/$ws/datasets/$modelId/refreshes" -Body '{"type":"full"}' | Out-Null
    Write-Host "Refresh triggered."
} catch { Write-Host "Refresh trigger note: $($_.Exception.Message)" }
Start-Sleep 20
Write-Host "DONE"
