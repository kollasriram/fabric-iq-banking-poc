$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$server = "YOUR_SQL_ENDPOINT.datawarehouse.fabric.microsoft.com"
$db = "NorthwindLakehouse"
$tok = az account get-access-token --resource https://database.windows.net --subscription $sub --query accessToken -o tsv
Add-Type -AssemblyName System.Data
$cn = New-Object System.Data.SqlClient.SqlConnection
$cn.ConnectionString = "Server=$server;Database=$db;Encrypt=True;"
$cn.AccessToken = $tok
$cn.Open()
$cmd = $cn.CreateCommand()
$cmd.CommandText = "SELECT s.name AS sch, t.name AS tbl FROM sys.tables t JOIN sys.schemas s ON t.schema_id=s.schema_id ORDER BY s.name, t.name"
$r = $cmd.ExecuteReader()
while ($r.Read()) { Write-Host ("{0}.{1}" -f $r["sch"], $r["tbl"]) }
$cn.Close()
