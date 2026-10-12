$ErrorActionPreference = "Continue"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$sqlep = "00000000-0000-0000-0000-000000000006"
$tok = (az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv)
$H = @{ Authorization = "Bearer $tok"; "Content-Type" = "application/json" }
$uri = "https://api.fabric.microsoft.com/v1/workspaces/$ws/sqlEndpoints/$sqlep/refreshMetadata?preview=true"
try {
    $r = Invoke-WebRequest -Headers $H -Method Post -Uri $uri -Body '{}'
    "refreshMetadata HTTP $($r.StatusCode)"
    $loc = $r.Headers["Location"]; if ($loc) { "Location=$loc" }
    $r.Content
} catch {
    "ERR: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message }
}
