Set-StrictMode -Version Latest

function Get-ObjectProperty {
    param(
        $Object,
        [Parameter(Mandatory)]
        [string]$Name,
        $Default = $null
    )

    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    $Default
}

function Get-DefaultTripName {
    param(
        [string]$CalculatorRoot = $PSScriptRoot
    )

    $parent = Split-Path -Parent $CalculatorRoot
    $name = Split-Path -Leaf $parent
    if ([string]::IsNullOrWhiteSpace($name)) {
        return '我的旅行'
    }
    $name
}

function Get-TravelLayoutMetrics {
    param(
        [Parameter(Mandatory)] [int]$WorkingWidth,
        [Parameter(Mandatory)] [int]$WorkingHeight,
        [ValidateSet(96, 144, 192)] [int]$Dpi = 96
    )

    if ($WorkingWidth -le 0 -or $WorkingHeight -le 0) {
        throw '屏幕工作区尺寸必须大于 0。'
    }

    [decimal]$scale = [decimal]$Dpi / 96
    $defaultWidth = [Math]::Min($WorkingWidth, [Math]::Max(1320, [int][Math]::Round($WorkingWidth * 0.70)))
    $defaultHeight = [Math]::Min($WorkingHeight, [Math]::Max(820, [int][Math]::Round($WorkingHeight * 0.70)))
    $fixedLogicalHeight = 64 + 235 + 42 + 20
    $editorRequiredLogicalHeight = 38 + 52 + 60
    $estimatedGridHeight = $defaultHeight - [int][Math]::Ceiling($fixedLogicalHeight * $scale)
    $estimatedEditorHeight = [int][Math]::Ceiling(235 * $scale)
    $estimatedEditorRequiredHeight = [int][Math]::Ceiling($editorRequiredLogicalHeight * $scale)

    [pscustomobject]@{
        Dpi = $Dpi
        Scale = $scale
        DefaultWidth = $defaultWidth
        DefaultHeight = $defaultHeight
        MinimumWidth = 1180
        MinimumHeight = 760
        EstimatedGridHeight = $estimatedGridHeight
        EstimatedEditorHeight = $estimatedEditorHeight
        EstimatedEditorRequiredHeight = $estimatedEditorRequiredHeight
        Fits = ($estimatedGridHeight -ge [int][Math]::Ceiling(220 * $scale)) -and
            ($estimatedEditorHeight -ge $estimatedEditorRequiredHeight)
    }
}

function Get-DefaultCategories {
    @(
        [pscustomobject]@{ Id = 'transport'; Name = '交通'; Color = '#2563eb'; IsDefault = $true }
        [pscustomobject]@{ Id = 'lodging'; Name = '住宿'; Color = '#7c3aed'; IsDefault = $true }
        [pscustomobject]@{ Id = 'food'; Name = '餐饮'; Color = '#ea580c'; IsDefault = $true }
        [pscustomobject]@{ Id = 'activities'; Name = '景点/活动'; Color = '#16a34a'; IsDefault = $true }
        [pscustomobject]@{ Id = 'shopping'; Name = '购物'; Color = '#db2777'; IsDefault = $true }
        [pscustomobject]@{ Id = 'visa-insurance'; Name = '签证/保险'; Color = '#0891b2'; IsDefault = $true }
        [pscustomobject]@{ Id = 'communication'; Name = '通讯/网络'; Color = '#4f46e5'; IsDefault = $true }
        [pscustomobject]@{ Id = 'fees-exchange'; Name = '手续费/换汇'; Color = '#ca8a04'; IsDefault = $true }
        [pscustomobject]@{ Id = 'medical'; Name = '医疗'; Color = '#dc2626'; IsDefault = $true }
        [pscustomobject]@{ Id = 'other'; Name = '其他'; Color = '#64748b'; IsDefault = $true }
    )
}

function New-TravelData {
    param(
        [string]$TripName = (Get-DefaultTripName),
        [string]$BaseCurrency = 'CNY'
    )

    if ([string]::IsNullOrWhiteSpace($TripName)) {
        $TripName = '我的旅行'
    }
    $BaseCurrency = $BaseCurrency.Trim().ToUpperInvariant()
    if ($BaseCurrency -notmatch '^[A-Z]{3}$') {
        throw '基准币种必须是 3 位英文字母，例如 CNY、USD、EUR。'
    }

    $now = (Get-Date).ToString('o')
    [pscustomobject]@{
        SchemaVersion = 1
        Settings = [pscustomobject]@{
            TripName = $TripName.Trim()
            BaseCurrency = $BaseCurrency
            CreatedAt = $now
            UpdatedAt = $now
        }
        Categories = @(Get-DefaultCategories)
        ExchangeRates = @(
            [pscustomobject]@{
                Currency = $BaseCurrency
                Rate = [decimal]1
                UpdatedAt = $now
            }
        )
        Expenses = @()
    }
}

function ConvertTo-NormalizedTravelData {
    param(
        [Parameter(Mandatory)]
        $Data,
        [string]$FallbackTripName = (Get-DefaultTripName)
    )

    $settings = Get-ObjectProperty $Data 'Settings'
    $tripName = [string](Get-ObjectProperty $settings 'TripName' $FallbackTripName)
    $baseCurrency = ([string](Get-ObjectProperty $settings 'BaseCurrency' 'CNY')).Trim().ToUpperInvariant()
    $createdAt = [string](Get-ObjectProperty $settings 'CreatedAt' (Get-Date).ToString('o'))
    $updatedAt = [string](Get-ObjectProperty $settings 'UpdatedAt' $createdAt)

    $categories = @()
    foreach ($category in @(Get-ObjectProperty $Data 'Categories' @())) {
        if ($null -eq $category) { continue }
        $id = [string](Get-ObjectProperty $category 'Id' '')
        $name = [string](Get-ObjectProperty $category 'Name' '')
        if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($name)) { continue }
        $categories += [pscustomobject]@{
            Id = $id
            Name = $name
            Color = [string](Get-ObjectProperty $category 'Color' '#64748b')
            IsDefault = [bool](Get-ObjectProperty $category 'IsDefault' $false)
        }
    }
    if ($categories.Count -eq 0) {
        $categories = @(Get-DefaultCategories)
    }

    $ratesByCurrency = @{}
    foreach ($rateItem in @(Get-ObjectProperty $Data 'ExchangeRates' @())) {
        if ($null -eq $rateItem) { continue }
        $currency = ([string](Get-ObjectProperty $rateItem 'Currency' '')).Trim().ToUpperInvariant()
        if ($currency -notmatch '^[A-Z]{3}$') { continue }
        $rate = [decimal](Get-ObjectProperty $rateItem 'Rate' 0)
        if ($rate -le 0) { continue }
        $ratesByCurrency[$currency] = [pscustomobject]@{
            Currency = $currency
            Rate = if ($currency -eq $baseCurrency) { [decimal]1 } else { $rate }
            UpdatedAt = [string](Get-ObjectProperty $rateItem 'UpdatedAt' $updatedAt)
        }
    }
    $ratesByCurrency[$baseCurrency] = [pscustomobject]@{
        Currency = $baseCurrency
        Rate = [decimal]1
        UpdatedAt = $updatedAt
    }

    $knownCategoryIds = @{}
    foreach ($category in $categories) {
        $knownCategoryIds[$category.Id] = $true
    }
    $fallbackCategoryId = if ($knownCategoryIds.ContainsKey('other')) { 'other' } else { $categories[0].Id }

    $expenses = @()
    foreach ($expense in @(Get-ObjectProperty $Data 'Expenses' @())) {
        if ($null -eq $expense) { continue }
        $categoryId = [string](Get-ObjectProperty $expense 'CategoryId' $fallbackCategoryId)
        if (-not $knownCategoryIds.ContainsKey($categoryId)) {
            $categoryId = $fallbackCategoryId
        }
        $amount = [decimal](Get-ObjectProperty $expense 'OriginalAmount' 0)
        $currency = ([string](Get-ObjectProperty $expense 'Currency' $baseCurrency)).Trim().ToUpperInvariant()
        $rate = [decimal](Get-ObjectProperty $expense 'ExchangeRate' 1)
        if ($currency -eq $baseCurrency) { $rate = [decimal]1 }
        $converted = Get-ObjectProperty $expense 'ConvertedAmount'
        if ($null -eq $converted) {
            $converted = [decimal]::Round($amount * $rate, 2, [MidpointRounding]::AwayFromZero)
        }
        $expenses += [pscustomobject]@{
            Id = [string](Get-ObjectProperty $expense 'Id' ([guid]::NewGuid().ToString()))
            Date = [string](Get-ObjectProperty $expense 'Date' (Get-Date -Format 'yyyy-MM-dd'))
            Item = [string](Get-ObjectProperty $expense 'Item' '')
            CategoryId = $categoryId
            OriginalAmount = $amount
            Currency = $currency
            ExchangeRate = $rate
            ConvertedAmount = [decimal]$converted
            Merchant = [string](Get-ObjectProperty $expense 'Merchant' '')
            Notes = [string](Get-ObjectProperty $expense 'Notes' '')
            CreatedAt = [string](Get-ObjectProperty $expense 'CreatedAt' $createdAt)
            UpdatedAt = [string](Get-ObjectProperty $expense 'UpdatedAt' $updatedAt)
        }
    }

    [pscustomobject]@{
        SchemaVersion = 1
        Settings = [pscustomobject]@{
            TripName = $tripName
            BaseCurrency = $baseCurrency
            CreatedAt = $createdAt
            UpdatedAt = $updatedAt
        }
        Categories = @($categories)
        ExchangeRates = @($ratesByCurrency.Values | Sort-Object Currency)
        Expenses = @($expenses)
    }
}

function Read-TravelData {
    param(
        [string]$Path = (Join-Path $PSScriptRoot 'travel-data.json')
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return New-TravelData
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return New-TravelData
    }
    ConvertTo-NormalizedTravelData -Data ($raw | ConvertFrom-Json)
}

function Test-TravelData {
    param(
        [Parameter(Mandatory)]
        $Data
    )

    if ([string]::IsNullOrWhiteSpace([string]$Data.Settings.TripName)) {
        throw '旅行名称不能为空。'
    }
    $baseCurrency = ([string]$Data.Settings.BaseCurrency).ToUpperInvariant()
    if ($baseCurrency -notmatch '^[A-Z]{3}$') {
        throw '基准币种必须是 3 位英文字母。'
    }

    $categoryIds = @{}
    $categoryNames = @{}
    foreach ($category in @($Data.Categories)) {
        if ([string]::IsNullOrWhiteSpace([string]$category.Id)) { throw '类别 ID 不能为空。' }
        if ([string]::IsNullOrWhiteSpace([string]$category.Name)) { throw '类别名称不能为空。' }
        if ($categoryIds.ContainsKey([string]$category.Id)) { throw "类别 ID 重复：$($category.Id)" }
        $nameKey = ([string]$category.Name).Trim().ToLowerInvariant()
        if ($categoryNames.ContainsKey($nameKey)) { throw "类别名称重复：$($category.Name)" }
        if ([string]$category.Color -notmatch '^#[0-9a-fA-F]{6}$') { throw "类别颜色无效：$($category.Name)" }
        $categoryIds[[string]$category.Id] = $true
        $categoryNames[$nameKey] = $true
    }
    if ($categoryIds.Count -eq 0) { throw '至少需要一个花费类别。' }

    $rateCurrencies = @{}
    $hasBaseRate = $false
    foreach ($rateItem in @($Data.ExchangeRates)) {
        $currency = ([string]$rateItem.Currency).ToUpperInvariant()
        if ($currency -notmatch '^[A-Z]{3}$') { throw "币种代码无效：$currency" }
        if ([decimal]$rateItem.Rate -le 0) { throw "$currency 的汇率必须大于 0。" }
        if ($rateCurrencies.ContainsKey($currency)) { throw "币种汇率重复：$currency" }
        if ($currency -eq $baseCurrency) {
            $hasBaseRate = $true
            if ([decimal]$rateItem.Rate -ne 1) { throw '基准币种汇率必须固定为 1。' }
        }
        $rateCurrencies[$currency] = $true
    }
    if (-not $hasBaseRate) { throw '缺少基准币种汇率。' }

    $expenseIds = @{}
    foreach ($expense in @($Data.Expenses)) {
        if ([string]::IsNullOrWhiteSpace([string]$expense.Id)) { throw '花费记录缺少 ID。' }
        if ($expenseIds.ContainsKey([string]$expense.Id)) { throw "花费记录 ID 重复：$($expense.Id)" }
        $expenseIds[[string]$expense.Id] = $true
        if ([string]::IsNullOrWhiteSpace([string]$expense.Item)) { throw '花费项目不能为空。' }
        if (-not $categoryIds.ContainsKey([string]$expense.CategoryId)) { throw "花费项目【$($expense.Item)】引用了不存在的类别。" }
        $parsedDate = [datetime]::MinValue
        if (-not [datetime]::TryParseExact([string]$expense.Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
            throw "花费项目【$($expense.Item)】的日期必须是 YYYY-MM-DD。"
        }
        if ([decimal]$expense.OriginalAmount -le 0) { throw "花费项目【$($expense.Item)】的金额必须大于 0。" }
        $currency = ([string]$expense.Currency).ToUpperInvariant()
        if ($currency -notmatch '^[A-Z]{3}$') { throw "花费项目【$($expense.Item)】的币种无效。" }
        if ([decimal]$expense.ExchangeRate -le 0) { throw "花费项目【$($expense.Item)】的汇率必须大于 0。" }
        if ($currency -eq $baseCurrency -and [decimal]$expense.ExchangeRate -ne 1) {
            throw "花费项目【$($expense.Item)】使用基准币种时汇率必须为 1。"
        }
        $expected = [decimal]::Round(
            [decimal]$expense.OriginalAmount * [decimal]$expense.ExchangeRate,
            2,
            [MidpointRounding]::AwayFromZero
        )
        if ([decimal]$expense.ConvertedAmount -ne $expected) {
            throw "花费项目【$($expense.Item)】的换算金额不一致。"
        }
    }
}

function Write-TravelData {
    param(
        [Parameter(Mandatory)]
        $Data,
        [string]$Path = (Join-Path $PSScriptRoot 'travel-data.json')
    )

    $Data.Settings.UpdatedAt = (Get-Date).ToString('o')
    Test-TravelData -Data $Data
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $json = $Data | ConvertTo-Json -Depth 8
    $tempPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $backupPath = "$Path.bak"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    try {
        [System.IO.File]::WriteAllText($tempPath, $json, $utf8NoBom)
        if (Test-Path -LiteralPath $Path) {
            try {
                [System.IO.File]::Replace($tempPath, $Path, $backupPath, $true)
                Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                Move-Item -LiteralPath $tempPath -Destination $Path -Force
            }
        }
        else {
            Move-Item -LiteralPath $tempPath -Destination $Path
        }
    }
    finally {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-DefaultExchangeRate {
    param(
        [Parameter(Mandatory)]
        $Data,
        [Parameter(Mandatory)]
        [string]$Currency
    )

    $currencyCode = $Currency.Trim().ToUpperInvariant()
    if ($currencyCode -eq [string]$Data.Settings.BaseCurrency) {
        return [decimal]1
    }
    $match = @($Data.ExchangeRates | Where-Object { $_.Currency -eq $currencyCode })
    if ($match.Count -eq 0) { return $null }
    [decimal]$match[0].Rate
}

function Set-DefaultExchangeRate {
    param(
        [Parameter(Mandatory)]
        $Data,
        [Parameter(Mandatory)]
        [string]$Currency,
        [Parameter(Mandatory)]
        [decimal]$Rate
    )

    $currencyCode = $Currency.Trim().ToUpperInvariant()
    if ($currencyCode -notmatch '^[A-Z]{3}$') { throw '币种必须是 3 位英文字母。' }
    if ($Rate -le 0) { throw '汇率必须大于 0。' }
    if ($currencyCode -eq [string]$Data.Settings.BaseCurrency) { $Rate = [decimal]1 }

    $existing = @($Data.ExchangeRates | Where-Object { $_.Currency -eq $currencyCode })
    if ($existing.Count -gt 0) {
        $existing[0].Rate = $Rate
        $existing[0].UpdatedAt = (Get-Date).ToString('o')
    }
    else {
        $Data.ExchangeRates = @($Data.ExchangeRates) + [pscustomobject]@{
            Currency = $currencyCode
            Rate = $Rate
            UpdatedAt = (Get-Date).ToString('o')
        }
    }
    $Data.ExchangeRates = @($Data.ExchangeRates | Sort-Object Currency)
}

function New-ExpenseRecord {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [string]$Date,
        [Parameter(Mandatory)] [string]$Item,
        [Parameter(Mandatory)] [string]$CategoryId,
        [Parameter(Mandatory)] [decimal]$OriginalAmount,
        [Parameter(Mandatory)] [string]$Currency,
        [Parameter(Mandatory)] [decimal]$ExchangeRate,
        [string]$Merchant = '',
        [string]$Notes = ''
    )

    if ([string]::IsNullOrWhiteSpace($Item)) { throw '花费项目不能为空。' }
    if ($OriginalAmount -le 0) { throw '金额必须大于 0。' }
    if (@($Data.Categories | Where-Object { $_.Id -eq $CategoryId }).Count -eq 0) { throw '请选择有效类别。' }

    $currencyCode = $Currency.Trim().ToUpperInvariant()
    if ($currencyCode -notmatch '^[A-Z]{3}$') { throw '币种必须是 3 位英文字母。' }
    if ($currencyCode -eq [string]$Data.Settings.BaseCurrency) {
        $ExchangeRate = [decimal]1
    }
    if ($ExchangeRate -le 0) { throw '汇率必须大于 0。' }

    $parsedDate = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedDate)) {
        throw '日期必须是有效日期。'
    }

    $now = (Get-Date).ToString('o')
    [pscustomobject]@{
        Id = [guid]::NewGuid().ToString()
        Date = $Date
        Item = $Item.Trim()
        CategoryId = $CategoryId
        OriginalAmount = $OriginalAmount
        Currency = $currencyCode
        ExchangeRate = $ExchangeRate
        ConvertedAmount = [decimal]::Round($OriginalAmount * $ExchangeRate, 2, [MidpointRounding]::AwayFromZero)
        Merchant = $Merchant.Trim()
        Notes = $Notes.Trim()
        CreatedAt = $now
        UpdatedAt = $now
    }
}

function Find-Expense {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [string]$Id
    )
    $matches = @($Data.Expenses | Where-Object { $_.Id -eq $Id })
    if ($matches.Count -eq 0) { throw '没有找到所选花费记录。' }
    if ($matches.Count -gt 1) { throw '花费记录 ID 重复。' }
    $matches[0]
}

function Add-TravelCategory {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [string]$Name,
        [string]$Color = '#0f766e'
    )
    $cleanName = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($cleanName)) { throw '类别名称不能为空。' }
    if (@($Data.Categories | Where-Object { $_.Name -eq $cleanName }).Count -gt 0) { throw '类别名称已经存在。' }
    if ($Color -notmatch '^#[0-9a-fA-F]{6}$') { throw '类别颜色必须是 #RRGGBB 格式。' }
    $category = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString()
        Name = $cleanName
        Color = $Color.ToLowerInvariant()
        IsDefault = $false
    }
    $Data.Categories = @($Data.Categories) + $category
    $category
}

function Rename-TravelCategory {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [string]$Id,
        [Parameter(Mandatory)] [string]$Name
    )
    $cleanName = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($cleanName)) { throw '类别名称不能为空。' }
    if (@($Data.Categories | Where-Object { $_.Id -ne $Id -and $_.Name -eq $cleanName }).Count -gt 0) {
        throw '类别名称已经存在。'
    }
    $matches = @($Data.Categories | Where-Object { $_.Id -eq $Id })
    if ($matches.Count -eq 0) { throw '没有找到该类别。' }
    $matches[0].Name = $cleanName
}

function Remove-TravelCategory {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [string]$Id
    )
    if (@($Data.Expenses | Where-Object { $_.CategoryId -eq $Id }).Count -gt 0) {
        throw '该类别已有花费记录，不能删除；可以先把相关记录改到其他类别。'
    }
    if (@($Data.Categories).Count -le 1) { throw '至少需要保留一个类别。' }
    if (@($Data.Categories | Where-Object { $_.Id -eq $Id }).Count -eq 0) { throw '没有找到该类别。' }
    $Data.Categories = @($Data.Categories | Where-Object { $_.Id -ne $Id })
}

function Get-ConvertedTotal {
    param([Parameter(Mandatory)] $Data)
    [decimal]$total = 0
    foreach ($expense in @($Data.Expenses)) {
        $total += [decimal]$expense.ConvertedAmount
    }
    $total
}

function Get-CategoryChoiceNames {
    param(
        [Parameter(Mandatory)] $Data,
        [switch]$IncludeAddOption
    )

    $names = @($Data.Categories | ForEach-Object { [string]$_.Name })
    if ($IncludeAddOption) {
        $names += '＋ 新增类别…'
    }
    @($names)
}

function Get-CategoryIdByChoiceIndex {
    param(
        [Parameter(Mandatory)] $Data,
        [Parameter(Mandatory)] [int]$Index
    )

    $categories = @($Data.Categories)
    if ($Index -lt 0 -or $Index -ge $categories.Count) {
        return $null
    }
    [string]$categories[$Index].Id
}

function Get-CategoryChoiceIndexById {
    param(
        [Parameter(Mandatory)] $Data,
        [string]$Id
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        return -1
    }
    $categories = @($Data.Categories)
    for ($index = 0; $index -lt $categories.Count; $index++) {
        if ([string]$categories[$index].Id -eq $Id) {
            return $index
        }
    }
    -1
}

function Get-OriginalCurrencyTotals {
    param([Parameter(Mandatory)] $Data)
    $totals = @{}
    foreach ($expense in @($Data.Expenses)) {
        $currency = [string]$expense.Currency
        if (-not $totals.ContainsKey($currency)) { $totals[$currency] = [decimal]0 }
        $totals[$currency] = [decimal]$totals[$currency] + [decimal]$expense.OriginalAmount
    }
    $totals
}
