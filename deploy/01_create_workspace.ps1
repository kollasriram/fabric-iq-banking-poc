$ErrorActionPreference = "Stop"
$tid = "00000000-0000-0000-0000-000000000001"
$capId = "00000000-0000-0000-0000-000000000004"
$name = "Fabric-IQ-Banking-POC"
$log = "YOUR_LOCAL_WORK_ROOT\_iq_ws_create.txt"

$tok = (az account get-access-token --resource https://api.fabric.microsoft.com --tenant $tid --query accessToken -o tsv)
$h = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }

$existing = (Invoke-RestMethod -Headers $h -Uri "https://api.fabric.microsoft.com/v1/workspaces").value
$match = $existing | Where-Object { $_.displayName -eq $name }
if ($match) {
    $out = "ALREADY EXISTS: id=$($match.id)"
}
else {
    $body = @{ displayName = $name; capacityId = $capId; description = "Fabric IQ hands-on POC - Northwind Financial" } | ConvertTo-Json
    $r = Invoke-RestMethod -Headers $h -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces" -Body $body
    $out = "CREATED: $($r.displayName) id=$($r.id) capacityId=$($r.capacityId)"
}
$out | Out-File -FilePath $log -Encoding utf8
Write-Host $out
