$ErrorActionPreference = "Stop"
$sub = "00000000-0000-0000-0000-000000000002"
$ws  = "00000000-0000-0000-0000-000000000003"
$model = (Get-Content YOUR_LOCAL_WORK_ROOT\_iq_sm_id.txt -Raw).Trim()
$pbiTok = az account get-access-token --resource https://analysis.windows.net/powerbi/api --subscription $sub --query accessToken -o tsv
$PH = @{ Authorization = "Bearer $pbiTok"; "Content-Type" = "application/json" }
$uri = "https://api.powerbi.com/v1.0/myorg/groups/$ws/datasets/$model/executeQueries"

function DAX($q) {
    $body = @{ queries = @(@{ query = $q }) } | ConvertTo-Json -Depth 5
    try {
        $r = Invoke-RestMethod -Headers $PH -Method Post -Uri $uri -Body $body
        return $r.results[0].tables[0].rows
    } catch {
        Write-Host "DAX error: $($_.Exception.Message)"
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
        return $null
    }
}

Write-Host "=== Portfolio KPIs ==="
DAX 'EVALUATE ROW("Txns",[Transaction Count],"FraudLossRate",[Fraud Loss Rate],"FraudLoss$",[Fraud Loss Amount],"DepositBal",[Deposit Balance],"LoanBook",[Loan Book Balance],"DelinqRate",[Delinquency Rate],"NIM",[Net Interest Margin])' | ConvertTo-Json -Depth 5

Write-Host "=== Fraud loss rate by region ==="
DAX 'EVALUATE TOPN(6, SUMMARIZECOLUMNS(dim_customer[region], "FraudLoss", [Fraud Loss Amount], "LossRate", [Fraud Loss Rate]), [FraudLoss], DESC)' | ConvertTo-Json -Depth 5

Write-Host "=== Cross-domain: delinquent borrowers WITH fraud alerts ==="
DAX 'EVALUATE ROW("DelinquentWithFraud", CALCULATE(DISTINCTCOUNT(fact_loan[customerKey]), FILTER(VALUES(dim_customer[customerKey]), [Delinquency Rate] > 0 && [Customers With Fraud Alert] > 0)))' | ConvertTo-Json -Depth 5
