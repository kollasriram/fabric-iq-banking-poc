$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws = "00000000-0000-0000-0000-000000000003"
$da = (Get-Content YOUR_LOCAL_WORK_ROOT\_iq_da_id.txt -Raw).Trim()
function Tok { az account get-access-token --resource https://api.fabric.microsoft.com --subscription $sub --query accessToken -o tsv }
$H = @{ Authorization = "Bearer $(Tok)"; "Content-Type" = "application/json" }
$base = "https://api.fabric.microsoft.com/v1/workspaces/$ws"

$instr = @"
This agent answers questions about Northwind Financial across TWO subject areas that share one resolved Customer: (A) Payments & Deposits and (B) Lending & Credit Risk. Ground answers in the NorthwindOntology. For cross-domain questions such as 'which delinquent borrowers also had card-fraud alerts', traverse FraudAlert -> Customer -> Loan -> DelinquencyEvent. Support group by in GQL for aggregations. When a question is about KPIs (fraud loss rate, deposit balance, NIM, delinquency rate) prefer the NorthwindModel semantic model.
"@

$stage = @{ '$schema' = "https://developer.microsoft.com/json-schemas/fabric/item/dataAgent/definition/stageConfiguration/1.0.0/schema.json"; aiInstructions = $instr.Trim() } | ConvertTo-Json
$dataAgent = @{ '$schema' = "https://developer.microsoft.com/json-schemas/fabric/item/dataAgent/definition/dataAgent/2.1.0/schema.json" } | ConvertTo-Json
$platform = Get-Content YOUR_LOCAL_WORK_ROOT\_iq_da_.platform.txt -Raw

function B64($s) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
$parts = @(
    @{ path = "Files/Config/data_agent.json"; payload = B64 $dataAgent; payloadType = "InlineBase64" },
    @{ path = "Files/Config/draft/stage_config.json"; payload = B64 $stage; payloadType = "InlineBase64" },
    @{ path = ".platform"; payload = B64 $platform; payloadType = "InlineBase64" }
)
$body = @{ definition = @{ parts = $parts } } | ConvertTo-Json -Depth 8
$r = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$da/updateDefinition" -Body $body
$op = $r.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
Write-Host "updateDefinition HTTP $($r.StatusCode) op=$op"
if ($op) { do { Start-Sleep 4; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); Write-Host "status=$($st.status)"; if ($st.status -ne 'Succeeded') { $st | ConvertTo-Json -Depth 8 } }

# round-trip verify
Start-Sleep 3
$H.Authorization = "Bearer $(Tok)"
$d = Invoke-WebRequest -Headers $H -Method Post -Uri "$base/items/$da/getDefinition"
$op = $d.Headers["x-ms-operation-id"]; if ($op -is [array]) { $op = $op[0] }
if ($op) { do { Start-Sleep 3; $H.Authorization = "Bearer $(Tok)"; $st = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op" } while ($st.status -in @("Running", "NotStarted")); $def = Invoke-RestMethod -Headers $H -Uri "https://api.fabric.microsoft.com/v1/operations/$op/result" } else { $def = $d.Content | ConvertFrom-Json }
$sc = $def.definition.parts | Where-Object path -eq "Files/Config/draft/stage_config.json"
Write-Host "`n=== stage_config.json after update ==="
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($sc.payload))
