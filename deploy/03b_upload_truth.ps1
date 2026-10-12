$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$lh = "00000000-0000-0000-0000-000000000005"
$src = "YOUR_PROJECT_ROOT\data\generator\out\truth_customer_crosswalk.csv"
$tok = (az account get-access-token --resource https://storage.azure.com --subscription $sub --query accessToken -o tsv)
$H = @{ Authorization = "Bearer $tok" }
$bytes = [System.IO.File]::ReadAllBytes($src); $len = $bytes.Length
$url = "https://onelake.dfs.fabric.microsoft.com/$ws/$lh/Files/truth/truth_customer_crosswalk.csv"
Invoke-RestMethod -Headers ($H + @{ "Content-Length" = "0" }) -Method Put -Uri "$url`?resource=file" | Out-Null
Invoke-WebRequest -Headers $H -Method Patch -Uri "$url`?action=append&position=0" -Body $bytes -ContentType "application/octet-stream" | Out-Null
Invoke-WebRequest -Headers $H -Method Patch -Uri "$url`?action=flush&position=$len" | Out-Null
Write-Host "uploaded truth_customer_crosswalk.csv ($len bytes)"
