param(
    [string]$MarkdownPath = (Join-Path $PSScriptRoot 'Fabric-Graph-Customer-Demo-Deck.md'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'Fabric-Graph-Customer-Demo-Deck.pptx')
)

$ErrorActionPreference = 'Stop'
$script:Colors = @{
    Ink = 2434088
    Teal = 7567360
    Amber = 2863583
    Muted = 7364958
    Pale = 16381424
    White = 16777215
    Line = 14803162
}

function Convert-PlainText([string]$Value) {
    $Value = $Value -replace '\*\*', '' -replace '`', ''
    $Value = $Value -replace '(?m)^- ', '' -replace '(?m)^\d+\. ', ''
    return $Value.Trim()
}

function Add-Text($Slide, [string]$Text, [double]$Left, [double]$Top, [double]$Width, [double]$Height, [double]$Size = 20, [int]$Color = $script:Colors.Ink, [bool]$Bold = $false) {
    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.TextFrame.MarginLeft = 0
    $shape.TextFrame.MarginRight = 0
    $shape.TextFrame.MarginTop = 0
    $shape.TextFrame.MarginBottom = 0
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame.TextRange.Text = $Text
    $shape.TextFrame.TextRange.Font.Name = 'Aptos'
    $shape.TextFrame.TextRange.Font.Size = $Size
    $shape.TextFrame.TextRange.Font.Color.RGB = $Color
    $shape.TextFrame.TextRange.Font.Bold = $(if ($Bold) { -1 } else { 0 })
    $shape.TextFrame.TextRange.ParagraphFormat.SpaceAfter = 5
    return $shape
}

function Add-Box($Slide, [string]$Text, [double]$Left, [double]$Top, [double]$Width = 130, [double]$Height = 48, [int]$Fill = $script:Colors.Pale, [int]$FontColor = $script:Colors.Ink) {
    $shape = $Slide.Shapes.AddShape(1, $Left, $Top, $Width, $Height)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Line.Visible = 0
    $shape.TextFrame.MarginLeft = 8
    $shape.TextFrame.MarginRight = 8
    $shape.TextFrame.VerticalAnchor = 3
    $shape.TextFrame.WordWrap = -1
    $shape.TextFrame.TextRange.Text = $Text
    $shape.TextFrame.TextRange.Font.Name = 'Aptos'
    $shape.TextFrame.TextRange.Font.Size = 14
    $shape.TextFrame.TextRange.Font.Color.RGB = $FontColor
    $shape.TextFrame.TextRange.ParagraphFormat.Alignment = 2
    return $shape
}

function Add-Arrow($Slide, [double]$StartX, [double]$StartY, [double]$EndX, [double]$EndY, [string]$Label = '', [double]$LabelX = 0, [double]$LabelY = 0, [double]$LabelWidth = 120) {
    $line = $Slide.Shapes.AddLine($StartX, $StartY, $EndX, $EndY)
    $line.Line.ForeColor.RGB = $script:Colors.Teal
    $line.Line.Weight = 1.8
    $line.Line.EndArrowheadStyle = 3
    if ($Label) { $null = Add-Text $Slide $Label $LabelX $LabelY $LabelWidth 28 11 $script:Colors.Muted }
}

function Add-Node($Slide, [string]$Label, [double]$CenterX, [double]$CenterY, [int]$Fill = $script:Colors.Teal) {
    $shape = $Slide.Shapes.AddShape(9, ($CenterX - 26), ($CenterY - 26), 52, 52)
    $shape.Fill.ForeColor.RGB = $Fill
    $shape.Line.Visible = 0
    $null = Add-Text $Slide $Label ($CenterX - 65) ($CenterY + 35) 130 42 14 $script:Colors.Ink $true
}

function Add-Table($Slide, [string]$Markdown, [double]$FontSize = 19, [double]$Height = 265, [double[]]$ColumnWidths = @()) {
    $rows = @($Markdown -split '\r?\n' | Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|\s*---' })
    $columnCount = @($rows[0].Trim('|').Split('|')).Count
    $table = $Slide.Shapes.AddTable($rows.Count, $columnCount, 48, 145, 864, $Height).Table
    if ($columnCount -eq 2) { $table.Columns.Item(1).Width = 432; $table.Columns.Item(2).Width = 432 }
    if ($ColumnWidths.Count -eq $columnCount) {
        for ($columnIndex = 1; $columnIndex -le $columnCount; $columnIndex++) { $table.Columns.Item($columnIndex).Width = $ColumnWidths[$columnIndex - 1] }
    }
    for ($rowIndex = 1; $rowIndex -le $rows.Count; $rowIndex++) {
        $cells = $rows[$rowIndex - 1].Trim('|').Split('|')
        for ($columnIndex = 1; $columnIndex -le $columnCount; $columnIndex++) {
            $cell = $table.Cell($rowIndex, $columnIndex).Shape
            $cell.Fill.ForeColor.RGB = $(if ($rowIndex -eq 1) { $script:Colors.Teal } else { $script:Colors.Pale })
            $cell.TextFrame.MarginLeft = 16
            $cell.TextFrame.MarginRight = 16
            $cell.TextFrame.VerticalAnchor = 3
            $cell.TextFrame.TextRange.Text = Convert-PlainText $cells[$columnIndex - 1]
            $cell.TextFrame.TextRange.Font.Name = 'Aptos'
            $cell.TextFrame.TextRange.Font.Size = $FontSize
            $cell.TextFrame.TextRange.Font.Bold = $(if ($rowIndex -eq 1) { -1 } else { 0 })
            $cell.TextFrame.TextRange.Font.Color.RGB = $(if ($rowIndex -eq 1) { $script:Colors.White } else { $script:Colors.Ink })
        }
    }
}

function Add-Illustration($Slide, [int]$Number) {
    if ($Number -ne 7) { $null = Add-Text $Slide 'ILLUSTRATIVE MODEL' 635 137 277 22 10 $script:Colors.Muted $true }
    switch ($Number) {
        1 {
            Add-Arrow $Slide 696 225 846 225
            Add-Arrow $Slide 870 251 870 344
            Add-Arrow $Slide 844 370 696 370
            Add-Node $Slide 'Merchant' 670 225 $script:Colors.Amber
            Add-Node $Slide 'Transaction' 870 225
            Add-Node $Slide 'Customer' 870 370
            Add-Node $Slide 'Loan' 670 370
        }
        2 {
            Add-Arrow $Slide 706 213 782 290
            Add-Arrow $Slide 848 213 810 290
            Add-Arrow $Slide 766 406 794 341
            Add-Node $Slide 'Payments' 680 190
            Add-Node $Slide 'Fraud' 870 190 $script:Colors.Amber
            Add-Node $Slide 'Lending' 755 430
            Add-Node $Slide 'Customer' 800 315
        }
        4 {
            foreach ($entry in @(@('Model', 185), @('Explore', 275), @('Query', 365))) {
                $null = Add-Box $Slide $entry[0] 650 $entry[1] 230 52
            }
            Add-Arrow $Slide 765 237 765 269
            Add-Arrow $Slide 765 327 765 359
        }
        5 {
            $labels = @('Source tables', 'Graph model', 'Save / refresh', 'Queryable graph', 'Insights')
            for ($stepIndex = 0; $stepIndex -lt $labels.Count; $stepIndex++) {
                $stepTop = 173 + $stepIndex * 58
                $null = Add-Box $Slide $labels[$stepIndex] 655 $stepTop 225 40
                if ($stepIndex -lt 4) { Add-Arrow $Slide 767 ($stepTop + 40) 767 ($stepTop + 55) }
            }
        }
        6 {
            Add-Arrow $Slide 748 242 700 348
            Add-Arrow $Slide 784 242 852 348
            Add-Node $Slide 'Transaction' 765 215
            Add-Node $Slide 'Customer' 680 375
            Add-Node $Slide 'Merchant' 870 375 $script:Colors.Amber
            $null = Add-Text $Slide "Key: txnId`nProperty: amount" 690 285 190 60 15 $script:Colors.Muted
        }
        7 {
            $null = Add-Text $Slide 'ILLUSTRATIVE SCHEMA / SEVEN DIRECTED RELATIONSHIPS' 395 133 517 22 10 $script:Colors.Muted $true
            Add-Arrow $Slide 477 220 614 220 'on transaction' 488 190
            Add-Arrow $Slide 667 220 814 220 'made by customer' 674 190 145
            $route = $Slide.Shapes.AddLine(450, 193, 450, 165)
            $route.Line.ForeColor.RGB = $script:Colors.Teal
            $route.Line.Weight = 1.8
            $route = $Slide.Shapes.AddLine(450, 165, 840, 165)
            $route.Line.ForeColor.RGB = $script:Colors.Teal
            $route.Line.Weight = 1.8
            Add-Arrow $Slide 840 165 840 193
            $null = Add-Text $Slide 'concerns customer' 563 145 170 20 10 $script:Colors.Muted
            Add-Arrow $Slide 614 220 450 364 'at merchant' 390 298 105
            Add-Arrow $Slide 840 247 840 364 'owns loan' 850 310 85
            Add-Arrow $Slide 814 390 667 390 'has delinquency' 680 356 135
            Add-Arrow $Slide 640 364 814 220 'concerns customer' 725 315 145
            Add-Node $Slide 'FraudAlert' 450 220 $script:Colors.Amber
            Add-Node $Slide 'Transaction' 640 220
            Add-Node $Slide 'Customer' 840 220
            Add-Node $Slide 'Merchant' 450 390 $script:Colors.Amber
            Add-Node $Slide 'Loan' 840 390
            Add-Node $Slide "Delinquency`nEvent" 640 390
        }
        { $_ -in 9, 11 } {
            foreach ($entry in @(@('01  Prioritize', 190), @('02  Explain', 280), @('03  Connect domains', 370))) {
                $null = Add-Box $Slide $entry[0] 645 $entry[1] 250 55
            }
        }
        10 {
            $null = Add-Box $Slide 'Transaction' 640 205 125 50
            $null = Add-Box $Slide 'Merchant' 795 205 115 50 $script:Colors.Amber
            Add-Arrow $Slide 765 230 790 230
            $null = Add-Text $Slide "MATCH  connection`nWHERE  riskFlag = true`nRETURN  distinct keys" 640 300 270 130 18 $script:Colors.Teal $true
        }
        12 {
            $null = Add-Box $Slide 'Business question' 650 190 230 50
            $null = Add-Box $Slide 'Data Agent -> GQL' 650 280 230 50
            $null = Add-Box $Slide 'Graph evidence' 650 370 230 50
            Add-Arrow $Slide 765 240 765 275
            Add-Arrow $Slide 765 330 765 365
        }
        15 {
            foreach ($entry in @(@('Correctness', 183), @('Investigation time', 250), @('Freshness', 317), @('Capacity usage', 384))) {
                $null = Add-Box $Slide $entry[0] 650 $entry[1] 230 46
            }
        }
        16 {
            Add-Node $Slide 'Question' 685 205
            Add-Node $Slide 'Dataset' 875 305
            Add-Node $Slide 'Pilot' 690 415 $script:Colors.Amber
            Add-Arrow $Slide 710 218 850 292
            Add-Arrow $Slide 850 320 713 400
        }
    }
}

function Add-IntroIllustration($Slide, [int]$Number) {
    $null = Add-Text $Slide 'ILLUSTRATIVE CONCEPT' 640 137 272 22 10 $script:Colors.Muted $true
    switch ($Number) {
        { $_ -in 1, 5, 10 } {
            $labels = $(if ($Number -eq 1) { @('Customer', 'Transaction', 'Merchant') } elseif ($Number -eq 5) { @('Source tables', 'Nodes and edges', 'Save / refresh', 'Explore') } else { @('Business question', 'Connected data', 'Explainable path') })
            for ($stepIndex = 0; $stepIndex -lt $labels.Count; $stepIndex++) {
                $top = 183 + $stepIndex * 75
                $null = Add-Box $Slide $labels[$stepIndex] 650 $top 230 50
                if ($stepIndex -lt ($labels.Count - 1)) { Add-Arrow $Slide 765 ($top + 50) 765 ($top + 70) }
            }
        }
        2 {
            $null = Add-Box $Slide 'Account' 630 190 125 55
            $null = Add-Box $Slide 'Merchant' 795 190 125 55 $script:Colors.Amber
            $null = Add-Box $Slide 'Customer' 705 292 130 60 $script:Colors.Teal $script:Colors.White
            $null = Add-Box $Slide 'Transaction' 630 410 125 55
            $null = Add-Box $Slide 'Loan' 795 410 125 55
            Add-Arrow $Slide 744 292 710 250
            Add-Arrow $Slide 800 292 840 250
            Add-Arrow $Slide 744 352 710 405
            Add-Arrow $Slide 800 352 840 405
        }
        4 {
            $null = Add-Box $Slide 'Customer A' 630 180 120 50
            $null = Add-Box $Slide 'Transaction A' 790 180 120 50
            $null = Add-Box $Slide 'Merchant' 715 280 150 65 $script:Colors.Amber
            $null = Add-Box $Slide 'Customer B' 630 390 120 50
            $null = Add-Box $Slide 'Transaction B' 790 390 120 50
            Add-Arrow $Slide 750 205 785 205
            Add-Arrow $Slide 850 230 825 275
            Add-Arrow $Slide 750 415 785 415
            Add-Arrow $Slide 850 390 825 350
        }
        6 {
            $null = Add-Box $Slide 'Visual query builder' 645 185 245 55
            $null = Add-Box $Slide 'GQL code editor' 645 280 245 55
            $null = Add-Box $Slide "Natural language`nData Agent (preview)" 645 375 245 65
        }
        8 {
            $null = Add-Box $Slide 'Customer' 710 185 130 55 $script:Colors.Teal $script:Colors.White
            $null = Add-Box $Slide 'Transaction' 625 285 125 55
            $null = Add-Box $Slide 'Loan' 795 285 125 55
            $null = Add-Box $Slide 'Merchant' 625 400 125 55 $script:Colors.Amber
            $null = Add-Box $Slide "Delinquency`nrecord" 795 400 125 55 $script:Colors.Amber
            Add-Arrow $Slide 738 240 700 280
            Add-Arrow $Slide 808 240 845 280
            Add-Arrow $Slide 687 340 687 395
            Add-Arrow $Slide 857 340 857 395
        }
        9 {
            $null = Add-Box $Slide "Connections and paths`nGraph" 640 200 250 85 $script:Colors.Teal $script:Colors.White
            $null = Add-Box $Slide "Totals and reporting`nSQL / BI" 640 340 250 85
        }
    }
}

function Get-GuideSection([string]$Guide, [string]$Heading) {
    $pattern = '(?ms)^' + [regex]::Escape($Heading) + '\r?\n(.*?)(?=^## |\z)'
    $match = [regex]::Match($Guide, $pattern)
    if (-not $match.Success) { throw "Missing guide heading: $Heading" }
    return $match.Groups[1].Value.Trim()
}

function Get-GuideQuestion([string]$Section, [int]$Number) {
    $pattern = '(?ms)^### Question ' + $Number + ': [^\r\n]+\r?\n(.*?)(?=^### Question |\z)'
    $match = [regex]::Match($Section, $pattern)
    if (-not $match.Success) { throw "Missing guide question: $Number" }
    return $match.Groups[1].Value.Trim()
}

function Add-GuideDiagram($Slide, [bool]$Lending = $false) {
    $null = Add-Text $Slide 'ILLUSTRATIVE SCHEMA / NOT A LIVE RESULT' 48 147 800 22 11 $script:Colors.Muted $true
    if ($Lending) {
        $null = Add-Box $Slide 'Customer' 100 260 180 65 $script:Colors.Teal $script:Colors.White
        $null = Add-Box $Slide 'Loan' 390 260 180 65 $script:Colors.Teal $script:Colors.White
        $null = Add-Box $Slide "Delinquency`nEvent" 680 260 180 65 $script:Colors.Amber
        Add-Arrow $Slide 280 292 382 292 'ownsLoan' 295 250 90
        Add-Arrow $Slide 570 292 672 292 'hasDelinquency' 575 250 110
        $null = Add-Text $Slide 'Extend the existing Customer node; keep payments relationships unchanged.' 100 380 760 60 21
    } else {
        $null = Add-Box $Slide 'Customer' 100 230 180 65 $script:Colors.Teal $script:Colors.White
        $null = Add-Box $Slide 'Transaction' 390 230 180 65 $script:Colors.Teal $script:Colors.White
        $null = Add-Box $Slide 'Merchant' 680 230 180 65 $script:Colors.Amber
        $null = Add-Box $Slide 'FraudAlert' 390 385 180 65 $script:Colors.Amber
        Add-Arrow $Slide 280 262 382 262 'makesTransaction' 283 197 150
        Add-Arrow $Slide 570 262 672 262 'atMerchant' 580 220 100
        Add-Arrow $Slide 480 295 480 377 'hasAlert' 494 328 100
    }
}

$markdown = Get-Content -LiteralPath $MarkdownPath -Raw
$isBuildGuide = $markdown.StartsWith('# Build a Customer Graph Demo Using FabricIQ')
$isIntroduction = $markdown.StartsWith('# Microsoft Fabric Graph: A Simple Introduction')
$guideSlides = @()
if ($isBuildGuide) {
    $model = Get-GuideSection $markdown '## 1. Understand the Small Demo Model'
    $questions = Get-GuideSection $markdown '## 7. Rehearse Three Simple Questions'
    $nodeTable = [regex]::Match($model, '(?ms)^### Node Mapping\r?\n\s*(\|.*?)(?=\r?\n\r?\n)').Groups[1].Value
    if (-not $nodeTable) { throw 'Node mapping table not found' }
    $edgeRows = [regex]::Matches($model, '(?m)^\| (makesTransaction|atMerchant|hasAlert) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|')
    if ($edgeRows.Count -ne 3) { throw 'Expected three core edge mappings' }
    $edgeTable = @('| Edge | Source table | Origin / source key | Target / source key |', '| --- | --- | --- | --- |')
    foreach ($edge in $edgeRows) {
        $edgeTable += "| $($edge.Groups[1].Value.Trim()) | $($edge.Groups[2].Value.Trim()) | $($edge.Groups[3].Value.Trim()) / $($edge.Groups[4].Value.Trim()) | $($edge.Groups[5].Value.Trim()) / $($edge.Groups[6].Value.Trim()) |"
    }
    $guideSlides = @(
        @{ Title = 'FabricIQ Customer Graph Demo'; Text = "Trace a transaction to its customer and merchant.`nFollow a recorded fraud alert through the same connections.`nBuild before the meeting; explore during the demo.`nCustomer session: 10-15 minutes."; Notes = (Get-GuideSection $markdown '## Recommended Demo') },
        @{ Title = 'Use the Existing Lakehouse'; Text = "Workspace: YOUR_WORKSPACE_NAME`nLakehouse: FabricIQ | Schema: gold`nFour source tables; no ontology or source-data rewrite.`nMetadata and samples checked; graph execution still needs rehearsal."; Notes = (Get-GuideSection $markdown '## Recommended Demo') + "`n" + (Get-GuideSection $markdown '## 2. Check the Source Data') },
        @{ Title = 'The Four-Node Demo Model'; Diagram = 'Core'; Notes = $model },
        @{ Title = 'Configure the Node Types'; Table = $nodeTable; Notes = $model + "`n" + (Get-GuideSection $markdown '## 4. Add the Four Node Types') },
        @{ Title = 'Configure the Relationships'; Table = ($edgeTable -join "`n"); Notes = $model + "`n" + (Get-GuideSection $markdown '## 5. Add the Three Edge Types') },
        @{ Title = 'Create the Graph Model'; Text = "YOUR_WORKSPACE_NAME > + New item > Graph model`nName: FabricIQCustomerRiskDemo`nGet data > OneLake catalog > FabricIQ > Add`nSelect the four gold tables > Load`nAdd the mapped nodes and edges; preserve existing items."; Notes = (Get-GuideSection $markdown '## 3. Create the Graph Model') },
        @{ Title = 'Save, Load, and Validate'; Text = "Select Save in the Model ribbon.`nWait for Data load completed before querying.`nRecord the last completed load or refresh time.`nCheck unique node keys and matching edge endpoints.`nSource updates need refresh; schema changes reload data."; Notes = (Get-GuideSection $markdown '## 6. Save and Load the Graph') + "`n" + (Get-GuideSection $markdown '## 2. Check the Source Data') },
        @{ Title = 'Trace One Known Transaction'; Text = "Modes > Query > Query builder > Code editor`nUse transaction TX-00044001 as a wiring check.`nSource preview: customer CUST-001159`nSource preview: merchant MER-0013 | USD 94.25`nReconcile these values after the graph loads."; Notes = (Get-GuideQuestion $questions 1) },
        @{ Title = 'Rank Activity at Flagged Merchants'; Text = "Filter Merchant.riskFlag = true.`nCount distinct transaction IDs and customer keys.`nSort transaction count descending; keep the top five.`nSelect a merchant from the actual result.`nFlagged activity is a review lead, not proof of fraud."; Notes = (Get-GuideQuestion $questions 2) },
        @{ Title = 'Follow a Recorded Fraud Alert'; Text = "Use alert AL-0000093 in the prepared query.`nSource preview: High severity | Open status`nSource preview: transaction TX-00047093`nSource preview: customer CUST-002026`nDiscover the merchant during rehearsal; do not assume it."; Notes = (Get-GuideQuestion $questions 3) },
        @{ Title = 'Explore the Evidence Visually'; Text = "Query builder > Add a node > Transaction`nComponents: atMerchant, hasAlert, makesTransaction`nFilter FraudAlert.alertId = AL-0000093 > Apply`nRun query; show Diagram and Table views.`nThe result shows records, not just entity types."; Notes = (Get-GuideSection $markdown '## 8. Show the Same Story Visually') },
        @{ Title = 'Save the Investigation'; Text = "Query mode > Create queryset`nName: FabricIQCustomerRiskQueries`nLocation: YOUR_WORKSPACE_NAME`nRename the query to TraceFraudAlert.`nReopen and rerun using an authorized workspace identity."; Notes = (Get-GuideSection $markdown '## 9. Save the Investigation') },
        @{ Title = 'Optional: Connect the Lending Domain'; Diagram = 'Lending'; Notes = (Get-GuideSection $markdown '## 10. Optional: Extend the Demo Into Lending') },
        @{ Title = 'Ready for the Customer Session'; Text = "Inspect one node and one edge mapping.`nTrace the transaction; explore the recorded alert.`nShow merchant ranking and the saved queryset.`nRehearse counts, access permissions, and refresh timing.`nKeep a clearly labeled screenshot or recording fallback."; Notes = (Get-GuideSection $markdown '## 11. Customer Presentation Sequence') + "`n" + (Get-GuideSection $markdown '## 12. Final Rehearsal Checklist') }
    )
}
$slideMatches = [regex]::Matches($markdown, '(?ms)^### Slide (\d{2}): ([^\r\n]+)\r?\n(.*?)(?=^### Slide |^## Part B:|^## Presenter Reference:|\z)')
$expectedSlides = $(if ($isIntroduction) { 10 } else { 16 })
if (-not $isBuildGuide -and $slideMatches.Count -ne $expectedSlides) { throw "Expected $expectedSlides slides or the FabricIQ build guide." }
$sourceUrls = @{}
foreach ($sourceMatch in [regex]::Matches($markdown, '\| \[(S\d+)\] \| \[([^\]]+)\]\((https://[^)]+)\)')) {
    $sourceUrls[$sourceMatch.Groups[1].Value] = "$($sourceMatch.Groups[2].Value): $($sourceMatch.Groups[3].Value)"
}
$runbook = ($markdown -split '## Part B: Presenter-Only Demo Runbook', 2)[1]
$runbook = ($runbook -split '## Part D:', 2)[0]
$previewDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('FabricGraphDeck-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $previewDirectory
$application = $null
$presentation = $null

try {
    $application = New-Object -ComObject PowerPoint.Application
    $presentation = $application.Presentations.Add(0)
    $presentation.PageSetup.SlideWidth = 960
    $presentation.PageSetup.SlideHeight = 540
    if ($isBuildGuide) {
        $number = 0
        $documentation = Get-GuideSection $markdown '## Official Documentation'
        foreach ($definition in $guideSlides) {
            $number++
            $slide = $presentation.Slides.Add($number, 12)
            $slide.FollowMasterBackground = 0
            $slide.Background.Fill.ForeColor.RGB = $script:Colors.White
            $bar = $slide.Shapes.AddShape(1, 0, 0, 960, 8)
            $bar.Fill.ForeColor.RGB = $script:Colors.Teal
            $bar.Line.Visible = 0
            $null = Add-Text $slide 'MICROSOFT FABRIC  /  FABRICIQ DEMO BUILD GUIDE' 48 30 850 20 11 $script:Colors.Teal $true
            $null = Add-Text $slide $definition.Title 48 65 864 58 30 $script:Colors.Ink $true
            if ($definition.Table) {
                $widths = $(if ($number -eq 4) { @(145, 235, 145, 339) } else { @(190, 230, 210, 234) })
                Add-Table $slide $definition.Table 16 320 $widths
            } elseif ($definition.Diagram) {
                Add-GuideDiagram $slide ($definition.Diagram -eq 'Lending')
            } else {
                $null = Add-Text $slide $definition.Text 48 150 864 320 23
                $slide.Shapes.Item($slide.Shapes.Count).TextFrame.TextRange.ParagraphFormat.SpaceAfter = 20
            }
            $null = Add-Text $slide 'Source: FabricIQ Graph Demo Build Guide | Metadata inspected; graph demo requires rehearsal' 48 507 800 17 9 $script:Colors.Muted
            $null = Add-Text $slide ('{0:00} / {1:00}' -f $number, $guideSlides.Count) 855 505 75 20 10 $script:Colors.Teal $true
            $notes = "SOURCE GUIDE DETAILS`r`n$($definition.Notes)`r`n`r`nOFFICIAL DOCUMENTATION`r`n$documentation`r`n`r`nIllustrations are editable schematics, not product screenshots. Source-preview checkpoints are not verified graph results."
            if ($number -eq 1) { $notes += "`r`n`r`nCOMPLETE PRESENTER BUILD GUIDE`r`n$markdown" }
            $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = $notes
        }
    }
    foreach ($slideMatch in $slideMatches) {
        $number = [int]$slideMatch.Groups[1].Value
        $title = $slideMatch.Groups[2].Value.Trim()
        $body = $slideMatch.Groups[3].Value
        $content = [regex]::Match($body, '(?s)\*\*On-slide\*\*\s*(.*?)(?=\*\*(?:Speaker notes|Suggested visual|Visual|Sources):)').Groups[1].Value.Trim()
        $slide = $presentation.Slides.Add($number, 12)
        $slide.FollowMasterBackground = 0
        $slide.Background.Fill.ForeColor.RGB = $script:Colors.White
        $bar = $slide.Shapes.AddShape(1, 0, 0, 960, 8)
        $bar.Fill.ForeColor.RGB = $script:Colors.Teal
        $bar.Line.Visible = 0
        $null = Add-Text $slide 'MICROSOFT FABRIC  /  CONNECTED INSIGHTS' 48 30 700 20 11 $script:Colors.Teal $true
        $null = Add-Text $slide $title 48 65 864 58 30 $script:Colors.Ink $true
        if ($content -match '(?m)^\|') {
            if ($isIntroduction) {
                $widths = $(if ($number -eq 3) { @(140, 340, 384) } else { @(270, 594) })
                Add-Table $slide $content 17 340 $widths
            } else {
                Add-Table $slide $content
            }
        } else {
            $hasVisual = $(if ($isIntroduction) { $number -in @(1, 2, 4, 5, 6, 8, 9, 10) } else { $number -in @(1, 2, 4, 5, 6, 7, 9, 10, 11, 12, 15, 16) })
            $bodyWidth = $(if ($isIntroduction) { 530 } elseif ($number -eq 7) { 310 } elseif ($hasVisual) { 530 } else { 864 })
            $bodySize = $(if ($isIntroduction -and $number -eq 9) { 19 } elseif ($isIntroduction) { 20 } elseif ($number -eq 7) { 20 } elseif ($hasVisual) { 21 } else { 23 })
            $bodyTop = 148
            foreach ($paragraph in ($content -split '\r?\n\s*\r?\n')) {
                if (-not $paragraph.Trim()) { continue }
                $isHeading = $paragraph.Trim().StartsWith('**')
                $plain = Convert-PlainText $paragraph
                $plain = $plain -replace '(?m)^\*', ''
                $paragraphHeight = $(if ($isHeading) { 88 } else { 250 })
                $textShape = Add-Text $slide $plain 48 $bodyTop $bodyWidth $paragraphHeight $bodySize $script:Colors.Ink $isHeading
                if (-not $isHeading) {
                    $textShape.TextFrame.TextRange.ParagraphFormat.SpaceAfter = $(if ($isIntroduction) { 12 } else { 17 })
                }
                if ($textShape.TextFrame2.TextRange.BoundHeight -gt $paragraphHeight) {
                    $textShape.TextFrame.TextRange.Font.Size = 19
                }
                $bodyTop += [math]::Max(40, $textShape.TextFrame2.TextRange.BoundHeight + 18)
            }
            if ($hasVisual) {
                if ($isIntroduction) { Add-IntroIllustration $slide $number } else { Add-Illustration $slide $number }
            }
        }
        $footer = $(if ($isIntroduction) { 'Fabric Graph | Introductory overview | Documentation reviewed 08 Oct 2026' } else { 'Northwind Financial | Synthetic-data scenario | Documentation reviewed 08 Oct 2026' })
        $null = Add-Text $slide $footer 48 507 800 17 9 $script:Colors.Muted
        $null = Add-Text $slide ('{0:00} / {1:00}' -f $number, $expectedSlides) 860 505 65 20 10 $script:Colors.Teal $true
        $notes = [System.Collections.Generic.List[string]]::new()
        $notes.Add("SLIDE $number - $title")
        foreach ($noteMatch in [regex]::Matches($body, '(?s)\*\*(Speaker notes|Suggested visual|Visual|Sources):\*\*\s*(.*?)(?=\*\*(?:Speaker notes|Suggested visual|Visual|Sources):\*\*|\z)')) {
            $notes.Add("$($noteMatch.Groups[1].Value): $($noteMatch.Groups[2].Value.Trim())")
        }
        foreach ($sourceId in @([regex]::Matches($body, '\[(S\d+)\]') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)) {
            if ($sourceUrls.ContainsKey($sourceId)) { $notes.Add($sourceUrls[$sourceId]) }
        }
        if ($isIntroduction) {
            $notes.Add('Diagrams are editable conceptual illustrations, not product screenshots or live query results. This is an introduction, not a deployment or demonstration runbook.')
        } else {
            $notes.Add('Diagrams are editable illustrations, not screenshots or verified live results. Rehearse the remote Fabric demo before presenting.')
            if ($number -eq 7) { $notes.Add('The diagram uses shortened readable edge captions; exact relationship labels are in the Markdown mapping and the Mermaid source above.') }
            if ($number -eq 11) { $notes.Add("PRESENTER-ONLY DEMO RUNBOOK AND Q&A`r`n$runbook") }
        }
        $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = $notes -join "`r`n`r`n"
    }

    $overflow = [System.Collections.Generic.List[string]]::new()
    foreach ($slide in $presentation.Slides) {
        foreach ($shape in $slide.Shapes) {
            if ($shape.HasTextFrame -eq -1 -and $shape.TextFrame.HasText -eq -1) {
                if ($shape.TextFrame2.TextRange.BoundHeight -gt ($shape.Height + 2)) { $overflow.Add("Slide $($slide.SlideIndex): text exceeds shape height") }
                if ($shape.Top -ge 145 -and $shape.Top -lt 500 -and ($shape.Top + $shape.TextFrame2.TextRange.BoundHeight) -gt 496) { $overflow.Add("Slide $($slide.SlideIndex): body reaches footer") }
            }
            if ($shape.HasTable -eq -1) {
                for ($rowIndex = 1; $rowIndex -le $shape.Table.Rows.Count; $rowIndex++) {
                    for ($columnIndex = 1; $columnIndex -le $shape.Table.Columns.Count; $columnIndex++) {
                        $cell = $shape.Table.Cell($rowIndex, $columnIndex).Shape
                        if ($cell.TextFrame2.TextRange.BoundHeight -gt ($cell.Height - 6)) { $overflow.Add("Slide $($slide.SlideIndex): table cell overflows") }
                    }
                }
            }
        }
    }
    if ($overflow.Count) { throw ($overflow -join "`n") }
    $presentation.SaveAs([System.IO.Path]::GetFullPath($OutputPath), 24)
    foreach ($slide in $presentation.Slides) {
        $slide.Export((Join-Path $previewDirectory ('slide-{0:00}.png' -f $slide.SlideIndex)), 'PNG', 1600, 900)
    }
    Write-Output "Created: $OutputPath"
    Write-Output "Slides: $($presentation.Slides.Count); editable diagrams; speaker notes and sources included."
    Write-Output "PowerPoint text bounds: PASS. Rendered slide previews: $previewDirectory"
} finally {
    if ($null -ne $presentation) {
        try { $presentation.Close() } catch { Write-Warning "PowerPoint presentation cleanup: $($_.Exception.Message)" }
    }
    if ($null -ne $application) {
        try { $application.Quit() } catch { Write-Warning "PowerPoint application cleanup: $($_.Exception.Message)" }
    }
    if ($null -ne $presentation) { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($presentation) }
    if ($null -ne $application) { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($application) }
}