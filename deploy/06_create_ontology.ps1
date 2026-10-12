$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws  = "00000000-0000-0000-0000-000000000003"
$name = "NorthwindOntology"
$partsRoot = "YOUR_PROJECT_ROOT\03-ontology\NorthwindOntology\parts"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }

# delete existing ontology of same name (idempotent)
$items = (Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/items?type=Ontology").value
$ex = $items | Where-Object { $_.displayName -eq $name }
if ($ex) { Invoke-RestMethod -Headers $H -Method Delete -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/items/$($ex.id)" | Out-Null; Write-Host "Deleted existing ontology $($ex.id)"; Start-Sleep 5 }

# build parts with forward-slash paths
$parts = @()
Get-ChildItem -Recurse -File $partsRoot | ForEach-Object {
    $rel = $_.FullName.Substring($partsRoot.Length + 1).Replace("\", "/")
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    $parts += @{ path = $rel; payload = $b64; payloadType = "InlineBase64" }
}
Write-Host "Parts: $($parts.Count)"
$body = @{ displayName = $name; type = "Ontology"; definition = @{ parts = $parts } } | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText("YOUR_LOCAL_WORK_ROOT\_iq_onto_envelope.json", $body, [System.Text.UTF8Encoding]::new($false))

$resp = Invoke-WebRequest -Headers $H -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/items" -Body $body
$op = $resp.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
Write-Host "HTTP $($resp.StatusCode)  op=$op"
if ($op) {
    do {
        Start-Sleep 5
        $H.Authorization = "Bearer $(Tok)"
        $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op"
        Write-Host "  status=$($st.status)"
    } while ($st.status -in @("Running", "NotStarted"))
    if ($st.status -ne "Succeeded") { $st | ConvertTo-Json -Depth 10 | Out-File YOUR_LOCAL_WORK_ROOT\_iq_onto_err.json -Encoding utf8; throw "Ontology create failed: $($st.status)" }
}
Start-Sleep 4
$onto = ((Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/items?type=Ontology").value | Where-Object displayName -eq $name)
Write-Host "ONTOLOGY_ID=$($onto.id)"
$onto.id | Out-File YOUR_LOCAL_WORK_ROOT\_iq_onto_id.txt -Encoding utf8
Write-Host "Companion items:"
(Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/workspaces/$ws/items").value | Where-Object { $_.displayName -like "*Northwind*Ontology*" -or $_.displayName -like "NorthwindOntology*" } | ForEach-Object { "  {0,-14} {1,-40} {2}" -f $_.type, $_.displayName, $_.id }
