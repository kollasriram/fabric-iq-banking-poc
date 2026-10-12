$ErrorActionPreference = "Stop"
$tid = "00000000-0000-0000-0000-000000000001"
$ws  = "00000000-0000-0000-0000-000000000003"
$lh  = "00000000-0000-0000-0000-000000000005"
$srcRoot = "YOUR_PROJECT_ROOT\data\generator\out"

$tok = (az account get-access-token --resource https://storage.azure.com --tenant $tid --query accessToken -o tsv)
$H = @{ Authorization = "Bearer $tok" }
$dfsBase = "https://onelake.dfs.fabric.microsoft.com/$ws/$lh/Files"

function Upload-File($localPath, $onelakeRelPath) {
    $bytes = [System.IO.File]::ReadAllBytes($localPath)
    $len = $bytes.Length
    $url = "$dfsBase/$onelakeRelPath"
    Invoke-RestMethod -Headers ($H + @{ "Content-Length" = "0" }) -Method Put -Uri "$url`?resource=file" | Out-Null
    Invoke-WebRequest -Headers $H -Method Patch -Uri "$url`?action=append&position=0" -Body $bytes -ContentType "application/octet-stream" | Out-Null
    Invoke-WebRequest -Headers $H -Method Patch -Uri "$url`?action=flush&position=$len" | Out-Null
    Write-Host ("  uploaded {0,-46} {1,8} bytes" -f $onelakeRelPath, $len)
}

# payments + lending CSVs -> Files/landing/<system>/<file>.csv ; truth -> Files/truth/
Get-ChildItem "$srcRoot\payments\*.csv" | ForEach-Object { Upload-File $_.FullName "landing/payments/$($_.Name)" }
Get-ChildItem "$srcRoot\lending\*.csv"  | ForEach-Object { Upload-File $_.FullName "landing/lending/$($_.Name)" }
Get-ChildItem "$srcRoot\*truth*.csv"    | ForEach-Object { Upload-File $_.FullName "truth/truth_customer_crosswalk.csv" }

Write-Host "=== UPLOAD DONE ===" | Out-File YOUR_LOCAL_WORK_ROOT\_iq_upload.txt -Encoding utf8 -Append
Write-Host "=== UPLOAD DONE ==="
