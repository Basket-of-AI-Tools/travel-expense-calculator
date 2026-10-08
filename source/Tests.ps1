Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$testRoot = Join-Path $env:TEMP "TravelExpenseCalculator-Test-$([guid]::NewGuid().ToString('N'))"
$dataPath = Join-Path $testRoot 'travel-data.json'
$reportPath = Join-Path $testRoot '旅行花费汇总.html'
$script:passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "断言失败：$Message" }
    $script:passed++
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "断言失败：$Message。实际值【$Actual】，期望值【$Expected】"
    }
    $script:passed++
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    $threw = $false
    try { & $Action } catch { $threw = $true }
    Assert-True $threw $Message
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    $data = New-TravelData -TripName '俄罗斯测试旅行' -BaseCurrency 'CNY'
    Assert-Equal @($data.Categories).Count 10 '应预置 10 个类别'
    Assert-Equal (Get-DefaultExchangeRate -Data $data -Currency 'CNY') ([decimal]1) '基准币种汇率应为 1'
    Assert-Throws { New-TravelData -TripName '错误币种' -BaseCurrency 'CN' } '应拒绝非三位币种'

    foreach ($scenario in @(
        @{ Dpi = 96; Width = 1920; Height = 1080 },
        @{ Dpi = 144; Width = 2560; Height = 1440 },
        @{ Dpi = 192; Width = 2880; Height = 1920 }
    )) {
        $metrics = Get-TravelLayoutMetrics `
            -WorkingWidth $scenario.Width `
            -WorkingHeight $scenario.Height `
            -Dpi $scenario.Dpi
        Assert-True $metrics.Fits "$($scenario.Dpi) DPI 下编辑区和表格区应有足够空间"
        Assert-True ($metrics.DefaultWidth -le $scenario.Width) "$($scenario.Dpi) DPI 下窗口宽度不得超出工作区"
        Assert-True ($metrics.DefaultHeight -le $scenario.Height) "$($scenario.Dpi) DPI 下窗口高度不得超出工作区"
    }

    $choiceNames = @(Get-CategoryChoiceNames -Data $data -IncludeAddOption)
    Assert-Equal $choiceNames[0] '交通' '类别选项应只显示名称'
    Assert-Equal $choiceNames[-1] '＋ 新增类别…' '类别选项末尾应提供新增入口'
    Assert-Equal (Get-CategoryIdByChoiceIndex -Data $data -Index 0) 'transport' '交通选项应映射到稳定 ID'
    Assert-Equal (Get-CategoryChoiceIndexById -Data $data -Id 'transport') 0 '交通 ID 应映射回正确选项'
    Assert-True ($null -eq (Get-CategoryIdByChoiceIndex -Data $data -Index (@($data.Categories).Count))) '新增类别入口不应被当作有效类别'

    Add-Type -AssemblyName System.Windows.Forms
    $testCombo = New-Object System.Windows.Forms.ComboBox
    $testCombo.DropDownStyle = 'DropDownList'
    foreach ($choiceName in $choiceNames) { $testCombo.Items.Add($choiceName) | Out-Null }
    $testCombo.SelectedIndex = 0
    Assert-Equal $testCombo.Text '交通' 'WinForms 类别下拉框应只显示交通名称'
    Assert-Equal (Get-CategoryIdByChoiceIndex -Data $data -Index $testCombo.SelectedIndex) 'transport' 'WinForms 选中交通后应取得有效类别 ID'

    Set-DefaultExchangeRate -Data $data -Currency 'RUB' -Rate ([decimal]0.08)
    $rubRate = Get-DefaultExchangeRate -Data $data -Currency 'rub'
    Assert-Equal $rubRate ([decimal]0.08) '币种代码应归一化并读回默认汇率'

    $custom = Add-TravelCategory -Data $data -Name '纪念品 & 礼物' -Color '#123abc'
    Assert-True (-not [string]::IsNullOrWhiteSpace($custom.Id)) '自定义类别应有稳定 ID'
    Assert-Throws { Add-TravelCategory -Data $data -Name '纪念品 & 礼物' } '应拒绝重复类别名称'
    Rename-TravelCategory -Data $data -Id $custom.Id -Name '纪念品/礼物'
    Assert-Equal @($data.Categories | Where-Object { $_.Id -eq $custom.Id })[0].Name '纪念品/礼物' '类别应可重命名'

    $expense = New-ExpenseRecord `
        -Data $data `
        -Date '2026-08-10' `
        -Item '<script>红场门票 & 测试' `
        -CategoryId 'activities' `
        -OriginalAmount ([decimal]123.45) `
        -Currency 'RUB' `
        -ExchangeRate $rubRate `
        -Merchant '克里姆林宫' `
        -Notes '中文备注'
    Assert-Equal $expense.ConvertedAmount ([decimal]9.88) '换算金额应按 AwayFromZero 保留两位'
    $data.Expenses = @($expense)
    Write-TravelData -Data $data -Path $dataPath

    $loaded = Read-TravelData -Path $dataPath
    Assert-Equal @($loaded.Expenses).Count 1 '花费记录应能写入并读回'
    Assert-Equal $loaded.Expenses[0].Item '<script>红场门票 & 测试' '中文和特殊字符应完整保存'
    Assert-Equal (Get-ConvertedTotal -Data $loaded) ([decimal]9.88) '总额应正确'
    Assert-Equal (Get-OriginalCurrencyTotals -Data $loaded)['RUB'] ([decimal]123.45) '应按原币汇总'

    Set-DefaultExchangeRate -Data $loaded -Currency 'RUB' -Rate ([decimal]0.09)
    Assert-Equal $loaded.Expenses[0].ExchangeRate ([decimal]0.08) '修改默认汇率不应追溯历史记录'
    Assert-Equal $loaded.Expenses[0].ConvertedAmount ([decimal]9.88) '修改默认汇率不应改变历史换算金额'

    Assert-Throws { Remove-TravelCategory -Data $loaded -Id 'activities' } '已有记录使用的类别不能删除'
    $unused = Add-TravelCategory -Data $loaded -Name '临时类别'
    Remove-TravelCategory -Data $loaded -Id $unused.Id
    Assert-Equal @($loaded.Categories | Where-Object { $_.Id -eq $unused.Id }).Count 0 '未使用类别应可删除'

    $bad = ConvertTo-NormalizedTravelData -Data $loaded
    $bad.Expenses[0].ConvertedAmount = [decimal]1
    Assert-Throws { Test-TravelData -Data $bad } '应拒绝不一致的换算金额'

    Write-TravelData -Data $loaded -Path $dataPath
    $generated = & (Join-Path $PSScriptRoot 'Generate-Report.ps1') -DataPath $dataPath -OutputPath $reportPath -NoOpen
    Assert-True (Test-Path -LiteralPath $generated) '应生成 HTML 汇总'
    $html = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
    Assert-True ($html.Contains('const DATA =')) 'HTML 应内嵌数据'
    Assert-True ($html.Contains('renderBarChart')) 'HTML 应包含互动柱状图逻辑'
    Assert-True ($html.Contains('renderPieChart')) 'HTML 应包含互动扇形图逻辑'
    Assert-True ($html.Contains('categoryFilter')) 'HTML 应包含类别筛选'
    Assert-True ($html.Contains('currencyFilter')) 'HTML 应包含币种筛选'
    Assert-True ($html.Contains('\u003cscript\u003e红场门票 \u0026 测试')) 'HTML 内嵌 JSON 应转义标签和连接符'
    Assert-True (-not $html.Contains('<script>红场门票 & 测试')) '用户文本不得形成可执行 HTML'

    $loaded.Expenses = @()
    Write-TravelData -Data $loaded -Path $dataPath
    & (Join-Path $PSScriptRoot 'Generate-Report.ps1') -DataPath $dataPath -OutputPath $reportPath -NoOpen | Out-Null
    $emptyHtml = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
    Assert-True ($emptyHtml.Contains('"expenses":[]')) '空数据应正常生成汇总'

    $copyAParent = Join-Path $testRoot 'A'
    $copyBParent = Join-Path $testRoot 'B'
    New-Item -ItemType Directory -Path $copyAParent, $copyBParent -Force | Out-Null
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $copyAParent '旅行花费计算器') -Recurse
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $copyBParent '旅行花费计算器') -Recurse
    $copyAData = Join-Path $copyAParent '旅行花费计算器\travel-data.json'
    $copyBData = Join-Path $copyBParent '旅行花费计算器\travel-data.json'
    $a = New-TravelData -TripName '旅行 A'
    $b = New-TravelData -TripName '旅行 B'
    $a.Expenses = @(
        New-ExpenseRecord -Data $a -Date '2026-01-01' -Item 'A 的交通' -CategoryId 'transport' -OriginalAmount 10 -Currency CNY -ExchangeRate 1
    )
    Write-TravelData -Data $a -Path $copyAData
    Write-TravelData -Data $b -Path $copyBData
    Assert-Equal @((Read-TravelData -Path $copyAData).Expenses).Count 1 '副本 A 应保留自己的记录'
    Assert-Equal @((Read-TravelData -Path $copyBData).Expenses).Count 0 '副本 B 不应受到副本 A 影响'
    Write-TravelData -Data (New-TravelData -TripName '重置后的 A') -Path $copyAData
    Assert-Equal (Read-TravelData -Path $copyAData).Settings.TripName '重置后的 A' '副本 A 应能独立重置'
    Assert-Equal (Read-TravelData -Path $copyBData).Settings.TripName '旅行 B' '重置副本 A 不应影响副本 B'

    $parseErrors = @()
    foreach ($scriptPath in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath.FullName, [ref]$tokens, [ref]$errors)
        $parseErrors += @($errors)
    }
    Assert-Equal $parseErrors.Count 0 '所有 PowerShell 脚本应通过当前运行时语法检查'

    Write-Host "测试通过：$script:passed 项断言。运行时：$($PSVersionTable.PSVersion)"
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
