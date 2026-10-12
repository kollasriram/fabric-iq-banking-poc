param(
    [Parameter(Mandatory = $true)][guid]$SubscriptionId,
    [Parameter(Mandatory = $true)][uri]$QueryUri,
    [Parameter(Mandatory = $true)][datetimeoffset]$StartTimeUtc,
    [Parameter(Mandatory = $true)][datetimeoffset]$EndTimeUtc,
    [ValidateSet("Seed", "Live")][string]$Mode = "Seed",
    [string]$DatabaseName = "NorthwindRTI",
    [int]$ExpectedEvents = 300,
    [string]$ReferenceTxnId,
    [datetimeoffset]$ReferenceTimeUtc,
    [double]$ReferenceAmount,
    [string]$ReferenceMerchantId,
    [string]$OutputDirectory = "$PSScriptRoot\out"
)
$ErrorActionPreference = "Stop"
# Module tests — KQL / Eventhouse fraud rules, positive & negative (specificity) assertions.
$sub   = $SubscriptionId
$query = $QueryUri.AbsoluteUri.TrimEnd('/')
$db    = $DatabaseName
if ($QueryUri.Scheme -ne "https" -or $QueryUri.Host -notlike "*.kusto.fabric.microsoft.com") { throw "Use the target Fabric KQL database's HTTPS query URI" }
if ($EndTimeUtc -lt $StartTimeUtc) { throw "EndTimeUtc must not precede StartTimeUtc" }
if ($Mode -eq "Live") {
    if ($ExpectedEvents -lt 1) { throw "ExpectedEvents must be positive" }
    foreach ($name in "ReferenceTxnId", "ReferenceTimeUtc", "ReferenceAmount", "ReferenceMerchantId") {
        if (-not $PSBoundParameters.ContainsKey($name)) { throw "Live verification requires $name" }
    }
}
$outDir = $OutputDirectory; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$start = $StartTimeUtc.ToUniversalTime().ToString("o")
$end = $EndTimeUtc.ToUniversalTime().ToString("o")
$stream = "(LiveTransactions | where eventTime between (datetime($start) .. datetime($end)))"

function KTok { az account get-access-token --resource https://api.kusto.windows.net --subscription $sub --query accessToken -o tsv }
function KScalar($csl) {
    $H = @{ Authorization = "Bearer $(KTok)"; "Content-Type" = "application/json" }
    $r = Invoke-RestMethod -Headers $H -Method Post -Uri "$query/v1/rest/query" -Body (@{ db = $db; csl = $csl } | ConvertTo-Json)
    return [double]$r.Tables[0].Rows[0][0]
}

$R = @()
function T($id, $kind, $desc, $expected, $actual, $cmp = "eq") {
    switch ($cmp) {
        "eq" { $ok = ($actual -eq $expected) }
        "gt" { $ok = ($actual -gt $expected) }
        "lt" { $ok = ($actual -lt $expected) }
        "ge" { $ok = ($actual -ge $expected) }
        "ne" { $ok = ($actual -ne $expected) }
    }
    $script:R += [pscustomobject]@{ id = $id; engine = "kql"; kind = $kind; desc = $desc; expected = $expected; actual = $actual; cmp = $cmp; pass = [bool]$ok }
}

$total = [int](KScalar "$stream | count")

# ---------- POSITIVE ----------
if ($Mode -eq "Seed") {
    T "KQ-P1" "pos" "Seed-window transactions = 6710" 6710 $total
    T "KQ-P2" "pos" "Rule1 cross-border high-value alerts = 500" 500 ([int](KScalar "$stream | where amount > 10000 and geoCountry != homeCountry | count"))
    T "KQ-P3" "pos" "Rule4 high-risk merchant txns = 1373" 1373 ([int](KScalar "$stream | where merchantRisk == true | count"))
    T "KQ-P4" "pos" "Rule2 velocity cards = 194" 194 ([int](KScalar "$stream | project cardId, merchantId, eventTime | join kind=inner ($stream | project cardId, m2=merchantId, t2=eventTime) on cardId | where t2 between (eventTime .. eventTime+5m) | summarize dm=dcount(m2) by cardId, anchor=eventTime | where dm>=3 | summarize count=dcount(cardId)"))
    T "KQ-P5" "pos" "Rule3 impossible-travel cards = 148" 148 ([int](KScalar "$stream | project cardId, geoCountry, eventTime | join kind=inner ($stream | project cardId, g2=geoCountry, t2=eventTime) on cardId | where t2 between (eventTime .. eventTime+30m) and g2 != geoCountry | summarize count=dcount(cardId)"))
} else {
    T "KQ-L1" "pos" "Live-window transactions match send count" $ExpectedEvents $total
    T "KQ-L2" "pos" "Live-window transaction IDs are distinct" $ExpectedEvents ([int](KScalar "$stream | summarize count=count_distinct(txnId)"))
    $txn = $ReferenceTxnId | ConvertTo-Json -Compress
    $merchant = $ReferenceMerchantId | ConvertTo-Json -Compress
    $referenceTime = $ReferenceTimeUtc.ToUniversalTime().ToString("o")
    $amount = $ReferenceAmount.ToString("R", [Globalization.CultureInfo]::InvariantCulture)
    T "KQ-L3" "pos" "Exact reference transaction/time/amount/merchant" 1 ([int](KScalar "$stream | where txnId == $txn and eventTime == datetime($referenceTime) and amount == $amount and merchantId == $merchant | count"))
    T "KQ-L4" "pos" "LiveTransactions schema has 15 columns" 15 ([int](KScalar "LiveTransactions | getschema | count"))
}

# ---------- NEGATIVE (rule specificity: safe traffic must NOT alert) ----------
# Rule1 never flags a domestic transaction
$r1domestic = [int](KScalar "$stream | where amount > 10000 and geoCountry != homeCountry | where geoCountry == homeCountry | count")
T "KQ-N1" "neg" "Rule1 flags zero domestic txns = 0" 0 $r1domestic
# A clearly-safe cohort produces zero high-value alerts
$safe = [int](KScalar "$stream | where amount < 50 and geoCountry == homeCountry and merchantRisk == false | where amount > 10000 | count")
T "KQ-N2" "neg" "Safe low-value domestic cohort raises 0 alerts = 0" 0 $safe
# Rule4 is selective (not every transaction is high-risk)
T "KQ-N3" "neg" "Rule4 high-risk transactions are a strict subset" $total ([int](KScalar "$stream | where merchantRisk == true | count")) "lt"

$R | ConvertTo-Json -Depth 4 | Out-File "$outDir\kql.json" -Encoding utf8
$np = ($R | Where-Object pass).Count
Write-Host "KQL $np/$($R.Count) passed"
$R | Format-Table id, kind, expected, actual, pass -AutoSize | Out-String | Write-Host
if ($np -ne $R.Count) { throw "KQL assertions failed; see $outDir/kql.json" }
