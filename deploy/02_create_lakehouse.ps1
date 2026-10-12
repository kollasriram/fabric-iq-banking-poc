$ErrorActionPreference = "Stop"
# Creates the schema-enabled NorthwindLakehouse in the POC workspace.
$sub = "00000000-0000-0000-0000-000000000002"     # <-- target subscription (pins az identity)
$ws  = "00000000-0000-0000-0000-000000000003"     # <-- POC workspace id
$name = "NorthwindLakehouse"
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$lh = (Invoke-RestMethod -Headers $H -Uri "$base/items").value | Where-Object { $_.displayName -eq $name -and $_.type -eq "Lakehouse" }
if ($lh) { Write-Host "EXISTS: $($lh.id)"; return }
$body = @{ displayName = $name; type = "Lakehouse"; creationPayload = @{ enableSchemas = $true } } | ConvertTo-Json
$r = Invoke-RestMethod -Headers $H -Method Post -Uri "$base/items" -Body $body
Write-Host "CREATED Lakehouse: $($r.id)"
