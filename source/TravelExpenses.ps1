Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Common.ps1')

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$dataPath = Join-Path $PSScriptRoot 'travel-data.json'
$reportScript = Join-Path $PSScriptRoot 'Generate-Report.ps1'
$reportPath = Join-Path $PSScriptRoot '旅行花费汇总.html'
$iconPath = Join-Path $PSScriptRoot '旅行花费计算器.ico'
$script:selectedExpenseId = $null
$script:refreshingGrid = $false
$script:refreshingCategoryBox = $false
$script:lastCategoryId = ''
$script:appIcon = $null
if (Test-Path -LiteralPath $iconPath) {
    try { $script:appIcon = New-Object System.Drawing.Icon($iconPath) } catch {}
}

function Initialize-AppWindow {
    param(
        [Parameter(Mandatory)]
        [System.Windows.Forms.Form]$Window
    )

    $Window.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $Window.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    if ($null -ne $script:appIcon) {
        $Window.Icon = $script:appIcon
    }
}

function Show-Error {
    param([string]$Message, [System.Windows.Forms.IWin32Window]$Owner = $form)
    [System.Windows.Forms.MessageBox]::Show(
        $Owner,
        $Message,
        '旅行花费计算器',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info {
    param([string]$Message, [System.Windows.Forms.IWin32Window]$Owner = $form)
    [System.Windows.Forms.MessageBox]::Show(
        $Owner,
        $Message,
        '旅行花费计算器',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Parse-PositiveDecimal {
    param([string]$Text, [string]$FieldName)
    [decimal]$value = 0
    $styles = [Globalization.NumberStyles]::Number
    if (-not [decimal]::TryParse($Text.Trim(), $styles, [Globalization.CultureInfo]::CurrentCulture, [ref]$value)) {
        if (-not [decimal]::TryParse($Text.Trim(), $styles, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
            throw "$FieldName 不是有效数字。"
        }
    }
    if ($value -le 0) { throw "$FieldName 必须大于 0。" }
    $value
}

function Save-And-RefreshReport {
    param([Parameter(Mandatory)]$Data)
    Write-TravelData -Data $Data -Path $dataPath
    & $reportScript -DataPath $dataPath -OutputPath $reportPath -NoOpen | Out-Null
}

if (-not (Test-Path -LiteralPath $dataPath)) {
    $initialData = New-TravelData
    Save-And-RefreshReport -Data $initialData
}
elseif (-not (Test-Path -LiteralPath $reportPath)) {
    & $reportScript -DataPath $dataPath -OutputPath $reportPath -NoOpen | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = '旅行花费计算器'
$form.StartPosition = 'CenterScreen'
Initialize-AppWindow -Window $form
$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$layoutMetrics = Get-TravelLayoutMetrics -WorkingWidth $workingArea.Width -WorkingHeight $workingArea.Height
$form.Size = New-Object System.Drawing.Size($layoutMetrics.DefaultWidth, $layoutMetrics.DefaultHeight)
$form.MinimumSize = New-Object System.Drawing.Size($layoutMetrics.MinimumWidth, $layoutMetrics.MinimumHeight)
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = 'Fill'
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 4
$mainLayout.Padding = New-Object System.Windows.Forms.Padding(10)
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 64))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 235))) | Out-Null
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 42))) | Out-Null
$form.Controls.Add($mainLayout)

$topPanel = New-Object System.Windows.Forms.TableLayoutPanel
$topPanel.Dock = 'Fill'
$topPanel.ColumnCount = 4
$topPanel.RowCount = 1
$topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) | Out-Null
$topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))) | Out-Null
$topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) | Out-Null
$topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('AutoSize'))) | Out-Null
$mainLayout.Controls.Add($topPanel, 0, 0)

$tripLabel = New-Object System.Windows.Forms.Label
$tripLabel.AutoSize = $true
$tripLabel.Anchor = 'Left'
$tripLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 14, [System.Drawing.FontStyle]::Bold)
$tripLabel.ForeColor = [System.Drawing.Color]::FromArgb(15, 118, 110)
$topPanel.Controls.Add($tripLabel, 0, 0)

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Dock = 'Fill'
$searchBox.Margin = New-Object System.Windows.Forms.Padding(24, 9, 12, 7)
$topPanel.Controls.Add($searchBox, 1, 0)

function New-ActionButton {
    param([string]$Text, [int]$Width = 90)
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.AutoSize = $true
    $button.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $button.MinimumSize = New-Object System.Drawing.Size($Width, 36)
    $button.Padding = New-Object System.Windows.Forms.Padding(10, 2, 10, 2)
    $button.Margin = New-Object System.Windows.Forms.Padding(4, 8, 0, 6)
    $button
}

$reportButton = New-ActionButton '打开互动汇总' 115
$resetButton = New-ActionButton '新建/重置旅行' 125
$topPanel.Controls.Add($reportButton, 2, 0)
$topPanel.Controls.Add($resetButton, 3, 0)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToOrderColumns = $true
$grid.MultiSelect = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.AutoSizeColumnsMode = 'Fill'
$grid.RowHeadersVisible = $false
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.BorderStyle = 'Fixed3D'
$grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
$grid.RowTemplate.Height = 28

function Add-GridColumn {
    param(
        [string]$Name,
        [string]$Header,
        [int]$Weight,
        [Type]$ValueType = [string],
        [string]$Alignment = 'MiddleLeft'
    )
    $column = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $column.Name = $Name
    $column.HeaderText = $Header
    $column.FillWeight = $Weight
    $column.ValueType = $ValueType
    $column.SortMode = 'Automatic'
    $column.DefaultCellStyle.Alignment = $Alignment
    $grid.Columns.Add($column) | Out-Null
}

Add-GridColumn 'Date' '日期' 75
Add-GridColumn 'Item' '项目' 115
Add-GridColumn 'Category' '类别' 85
Add-GridColumn 'Merchant' '商家/地点' 105
Add-GridColumn 'OriginalAmount' '原币金额' 76 ([decimal]) 'MiddleRight'
Add-GridColumn 'Currency' '币种' 52
Add-GridColumn 'ExchangeRate' '汇率' 65 ([decimal]) 'MiddleRight'
Add-GridColumn 'ConvertedAmount' '换算金额' 80 ([decimal]) 'MiddleRight'
Add-GridColumn 'Notes' '备注' 145
Add-GridColumn 'Id' 'Id' 10
$grid.Columns['Id'].Visible = $false
$grid.Columns['OriginalAmount'].DefaultCellStyle.Format = 'N2'
$grid.Columns['ExchangeRate'].DefaultCellStyle.Format = '0.######'
$grid.Columns['ConvertedAmount'].DefaultCellStyle.Format = 'N2'
$mainLayout.Controls.Add($grid, 0, 1)

$editor = New-Object System.Windows.Forms.TableLayoutPanel
$editor.Dock = 'Fill'
$editor.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$editor.ColumnCount = 12
$editor.RowCount = 3
foreach ($width in @(10, 8.5, 8.5, 8, 8, 8, 8, 8.5, 8.5, 7.5, 7.5, 9)) {
    $editor.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', $width))) | Out-Null
}
$editor.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 38))) | Out-Null
$editor.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 52))) | Out-Null
$editor.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) | Out-Null
$mainLayout.Controls.Add($editor, 0, 2)

function Add-EditorLabel {
    param([string]$Text, [int]$Column, [int]$Span)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $true
    $label.Anchor = 'Left'
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 5, 4, 2)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
    $editor.Controls.Add($label, $Column, 0)
    $editor.SetColumnSpan($label, $Span)
}

function New-EditorTextBox {
    $box = New-Object System.Windows.Forms.TextBox
    $box.Dock = 'Fill'
    $box.Margin = New-Object System.Windows.Forms.Padding(0, 5, 8, 7)
    $box
}

Add-EditorLabel '日期' 0 1
Add-EditorLabel '项目' 1 2
Add-EditorLabel '类别' 3 2
Add-EditorLabel '原币金额' 5 1
Add-EditorLabel '币种' 6 1
Add-EditorLabel '汇率（1 原币 = ? 基准币）' 7 2
Add-EditorLabel '商家/地点' 9 2
Add-EditorLabel '备注' 11 1

$datePicker = New-Object System.Windows.Forms.DateTimePicker
$datePicker.Format = 'Custom'
$datePicker.CustomFormat = 'yyyy-MM-dd'
$datePicker.Dock = 'Fill'
$datePicker.Margin = New-Object System.Windows.Forms.Padding(0, 5, 8, 7)
$editor.Controls.Add($datePicker, 0, 1)

$itemBox = New-EditorTextBox
$editor.Controls.Add($itemBox, 1, 1)
$editor.SetColumnSpan($itemBox, 2)

$categoryBox = New-Object System.Windows.Forms.ComboBox
$categoryBox.DropDownStyle = 'DropDownList'
$categoryBox.Dock = 'Fill'
$categoryBox.Margin = New-Object System.Windows.Forms.Padding(0, 5, 8, 7)
$editor.Controls.Add($categoryBox, 3, 1)
$editor.SetColumnSpan($categoryBox, 2)

$amountBox = New-EditorTextBox
$editor.Controls.Add($amountBox, 5, 1)

$currencyBox = New-Object System.Windows.Forms.ComboBox
$currencyBox.DropDownStyle = 'DropDown'
$currencyBox.MaxLength = 3
$currencyBox.Dock = 'Fill'
$currencyBox.Margin = New-Object System.Windows.Forms.Padding(0, 5, 8, 7)
$editor.Controls.Add($currencyBox, 6, 1)

$rateBox = New-EditorTextBox
$editor.Controls.Add($rateBox, 7, 1)
$editor.SetColumnSpan($rateBox, 2)

$merchantBox = New-EditorTextBox
$editor.Controls.Add($merchantBox, 9, 1)
$editor.SetColumnSpan($merchantBox, 2)

$notesBox = New-EditorTextBox
$notesBox.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 7)
$editor.Controls.Add($notesBox, 11, 1)

$buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$buttonPanel.Dock = 'Fill'
$buttonPanel.FlowDirection = 'LeftToRight'
$buttonPanel.WrapContents = $false
$buttonPanel.AutoScroll = $true
$editor.Controls.Add($buttonPanel, 0, 2)
$editor.SetColumnSpan($buttonPanel, 12)

$addButton = New-ActionButton '新增' 70
$saveButton = New-ActionButton '保存修改' 85
$deleteButton = New-ActionButton '彻底删除' 85
$clearButton = New-ActionButton '清空输入' 80
$categoriesButton = New-ActionButton '管理类别' 85
$ratesButton = New-ActionButton '管理汇率' 85
$refreshButton = New-ActionButton '刷新' 70
$convertedLabel = New-Object System.Windows.Forms.Label
$convertedLabel.AutoSize = $true
$convertedLabel.TextAlign = 'MiddleLeft'
$convertedLabel.Margin = New-Object System.Windows.Forms.Padding(18, 13, 0, 0)
$convertedLabel.ForeColor = [System.Drawing.Color]::FromArgb(15, 118, 110)
$convertedLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
@($addButton, $saveButton, $deleteButton, $clearButton, $categoriesButton, $ratesButton, $refreshButton, $convertedLabel) |
    ForEach-Object { $buttonPanel.Controls.Add($_) }

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Dock = 'Fill'
$statusLabel.TextAlign = 'MiddleRight'
$statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$mainLayout.Controls.Add($statusLabel, 0, 3)

function Get-CategoryByName {
    param($Data, [string]$Name)
    @($Data.Categories | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
}

function Refresh-CategoryBox {
    param([string]$SelectId = '')
    $data = Read-TravelData -Path $dataPath
    $script:refreshingCategoryBox = $true
    try {
        $categoryBox.Items.Clear()
        foreach ($name in @(Get-CategoryChoiceNames -Data $data -IncludeAddOption)) {
            $categoryBox.Items.Add($name) | Out-Null
        }

        $selectedIndex = Get-CategoryChoiceIndexById -Data $data -Id $SelectId
        if ($selectedIndex -lt 0 -and @($data.Categories).Count -gt 0) {
            $selectedIndex = 0
        }
        $categoryBox.SelectedIndex = $selectedIndex
        $script:lastCategoryId = Get-CategoryIdByChoiceIndex -Data $data -Index $selectedIndex
    }
    finally {
        $script:refreshingCategoryBox = $false
    }
}

function Get-SelectedCategoryId {
    $data = Read-TravelData -Path $dataPath
    Get-CategoryIdByChoiceIndex -Data $data -Index $categoryBox.SelectedIndex
}

function Show-NewCategoryNameDialog {
$dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = '新增类别'
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    Initialize-AppWindow -Window $dialog
    $dialog.ClientSize = New-Object System.Drawing.Size(440, 185)
    $dialog.MinimumSize = New-Object System.Drawing.Size(440, 185)
    $dialog.Font = $form.Font

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(16)
    $layout.ColumnCount = 1
    $layout.RowCount = 3
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 36))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 52))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) | Out-Null
    $dialog.Controls.Add($layout)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = '类别名称'
    $label.Dock = 'Fill'
    $label.TextAlign = 'BottomLeft'
    $layout.Controls.Add($label, 0, 0)

    $nameInput = New-Object System.Windows.Forms.TextBox
    $nameInput.Dock = 'Fill'
    $layout.Controls.Add($nameInput, 0, 1)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Fill'
    $buttons.FlowDirection = 'RightToLeft'
    $layout.Controls.Add($buttons, 0, 2)
    $confirm = New-ActionButton '新增' 80
    $confirm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = New-ActionButton '取消' 80
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttons.Controls.Add($confirm)
    $buttons.Controls.Add($cancel)
    $dialog.AcceptButton = $confirm
    $dialog.CancelButton = $cancel
    $dialog.Add_Shown({ $nameInput.Focus() })

    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }
    $nameInput.Text.Trim()
}

function Refresh-CurrencyBox {
    param([string]$SelectCurrency = '')
    $data = Read-TravelData -Path $dataPath
    $currencies = @($data.ExchangeRates | ForEach-Object { $_.Currency } | Sort-Object -Unique)
    $currencyBox.Items.Clear()
    foreach ($currency in $currencies) { $currencyBox.Items.Add($currency) | Out-Null }
    if ([string]::IsNullOrWhiteSpace($SelectCurrency)) {
        $SelectCurrency = [string]$data.Settings.BaseCurrency
    }
    $currencyBox.Text = $SelectCurrency
}

function Update-ConvertedPreview {
    try {
        $amount = Parse-PositiveDecimal -Text $amountBox.Text -FieldName '金额'
        $rate = Parse-PositiveDecimal -Text $rateBox.Text -FieldName '汇率'
        $data = Read-TravelData -Path $dataPath
        if ($currencyBox.Text.Trim().ToUpperInvariant() -eq [string]$data.Settings.BaseCurrency) {
            $rate = [decimal]1
        }
        $converted = [decimal]::Round($amount * $rate, 2, [MidpointRounding]::AwayFromZero)
        $convertedLabel.Text = '换算：{0} {1:N2}' -f $data.Settings.BaseCurrency, $converted
    }
    catch {
        $convertedLabel.Text = ''
    }
}

function Clear-Editor {
    $script:selectedExpenseId = $null
    $datePicker.Value = Get-Date
    $itemBox.Clear()
    $amountBox.Clear()
    $merchantBox.Clear()
    $notesBox.Clear()
    Refresh-CategoryBox
    Refresh-CurrencyBox
    $data = Read-TravelData -Path $dataPath
    $rateBox.Text = '1'
    $grid.ClearSelection()
    Update-ConvertedPreview
    $itemBox.Focus()
}

function Refresh-Grid {
    $data = Read-TravelData -Path $dataPath
    $query = $searchBox.Text.Trim().ToLowerInvariant()
    $categoryNames = @{}
    foreach ($category in @($data.Categories)) { $categoryNames[$category.Id] = $category.Name }

    $script:refreshingGrid = $true
    try {
        $grid.Rows.Clear()
        foreach ($expense in @($data.Expenses | Sort-Object Date, CreatedAt -Descending)) {
            $categoryName = [string]$categoryNames[$expense.CategoryId]
            $haystack = ('{0} {1} {2} {3} {4}' -f $expense.Item, $categoryName, $expense.Merchant, $expense.Notes, $expense.Currency).ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($query) -and -not $haystack.Contains($query)) { continue }
            $grid.Rows.Add(
                $expense.Date,
                $expense.Item,
                $categoryName,
                $expense.Merchant,
                [decimal]$expense.OriginalAmount,
                $expense.Currency,
                [decimal]$expense.ExchangeRate,
                [decimal]$expense.ConvertedAmount,
                $expense.Notes,
                $expense.Id
            ) | Out-Null
        }
        $grid.ClearSelection()
    }
    finally {
        $script:refreshingGrid = $false
    }

    $tripLabel.Text = '基准币种 {0}' -f $data.Settings.BaseCurrency
    $currencyTotals = Get-OriginalCurrencyTotals -Data $data
    $originalSummary = @($currencyTotals.Keys | Sort-Object | ForEach-Object {
        '{0} {1:N2}' -f $_, ([decimal]$currencyTotals[$_])
    }) -join '，'
    if ([string]::IsNullOrWhiteSpace($originalSummary)) { $originalSummary = '暂无记录' }
    $statusLabel.Text = '共 {0} 笔｜原币：{1}｜折合 {2} {3:N2}' -f @($data.Expenses).Count, $originalSummary, $data.Settings.BaseCurrency, (Get-ConvertedTotal -Data $data)
}

function Get-EditorExpense {
    param($Data)
    $categoryId = Get-SelectedCategoryId
    if ([string]::IsNullOrWhiteSpace($categoryId)) { throw '请选择有效类别。' }
    $currency = $currencyBox.Text.Trim().ToUpperInvariant()
    $rate = Parse-PositiveDecimal -Text $rateBox.Text -FieldName '汇率'
    New-ExpenseRecord `
        -Data $Data `
        -Date $datePicker.Value.ToString('yyyy-MM-dd') `
        -Item $itemBox.Text `
        -CategoryId $categoryId `
        -OriginalAmount (Parse-PositiveDecimal -Text $amountBox.Text -FieldName '金额') `
        -Currency $currency `
        -ExchangeRate $rate `
        -Merchant $merchantBox.Text `
        -Notes $notesBox.Text
}

function Show-CategoryManager {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = '管理花费类别'
    $dialog.StartPosition = 'CenterParent'
    Initialize-AppWindow -Window $dialog
    $dialog.Size = New-Object System.Drawing.Size(720, 560)
    $dialog.MinimumSize = New-Object System.Drawing.Size(620, 500)
    $dialog.Font = $form.Font

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    $layout.ColumnCount = 2
    $layout.RowCount = 4
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 45))) | Out-Null
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 55))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 32))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 48))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 44))) | Out-Null
    $dialog.Controls.Add($layout)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = 'Fill'
    $layout.Controls.Add($list, 0, 0)
    $layout.SetRowSpan($list, 3)
    $categoryListIds = New-Object System.Collections.ArrayList

    $help = New-Object System.Windows.Forms.Label
    $help.Text = '选择类别后可重命名或改颜色。已有记录使用的类别不能删除。'
    $help.Dock = 'Fill'
    $help.Padding = New-Object System.Windows.Forms.Padding(10, 6, 4, 4)
    $layout.Controls.Add($help, 1, 0)

    $nameBox = New-Object System.Windows.Forms.TextBox
    $nameBox.Dock = 'Fill'
    $nameBox.Margin = New-Object System.Windows.Forms.Padding(10, 2, 0, 2)
    $layout.Controls.Add($nameBox, 1, 1)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Fill'
    $buttons.Margin = New-Object System.Windows.Forms.Padding(10, 3, 0, 0)
    $buttons.WrapContents = $false
    $layout.Controls.Add($buttons, 1, 2)
    $add = New-ActionButton '新增' 68
    $rename = New-ActionButton '保存名称' 82
    $color = New-ActionButton '选择颜色' 82
    $delete = New-ActionButton '删除' 68
    @($add, $rename, $color, $delete) | ForEach-Object { $buttons.Controls.Add($_) }

    $close = New-ActionButton '完成' 90
    $close.Anchor = 'Right'
    $layout.Controls.Add($close, 1, 3)

    function Refresh-CategoryList {
        param([string]$SelectId = '')
        $data = Read-TravelData -Path $dataPath
        $list.Items.Clear()
        $categoryListIds.Clear()
        foreach ($category in @($data.Categories)) {
            $list.Items.Add([string]$category.Name) | Out-Null
            $categoryListIds.Add([string]$category.Id) | Out-Null
        }
        if (-not [string]::IsNullOrWhiteSpace($SelectId)) {
            for ($i = 0; $i -lt $list.Items.Count; $i++) {
                if ([string]$categoryListIds[$i] -eq $SelectId) { $list.SelectedIndex = $i; break }
            }
        }
        elseif ($list.Items.Count -gt 0) {
            $list.SelectedIndex = 0
        }
    }

    function Get-ManagedCategoryId {
        if ($list.SelectedIndex -lt 0 -or $list.SelectedIndex -ge $categoryListIds.Count) {
            return $null
        }
        [string]$categoryListIds[$list.SelectedIndex]
    }

    $list.Add_SelectedIndexChanged({
        if ($list.SelectedItem -ne $null) { $nameBox.Text = [string]$list.SelectedItem }
    })
    $add.Add_Click({
        try {
            $data = Read-TravelData -Path $dataPath
            $newCategory = Add-TravelCategory -Data $data -Name $nameBox.Text
            Save-And-RefreshReport -Data $data
            Refresh-CategoryList -SelectId $newCategory.Id
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $rename.Add_Click({
        try {
            $selectedId = Get-ManagedCategoryId
            if ([string]::IsNullOrWhiteSpace($selectedId)) { throw '请先选择类别。' }
            $data = Read-TravelData -Path $dataPath
            Rename-TravelCategory -Data $data -Id $selectedId -Name $nameBox.Text
            Save-And-RefreshReport -Data $data
            Refresh-CategoryList -SelectId $selectedId
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $color.Add_Click({
        try {
            $selectedId = Get-ManagedCategoryId
            if ([string]::IsNullOrWhiteSpace($selectedId)) { throw '请先选择类别。' }
            $data = Read-TravelData -Path $dataPath
            $category = @($data.Categories | Where-Object { $_.Id -eq $selectedId })[0]
            $picker = New-Object System.Windows.Forms.ColorDialog
            $picker.FullOpen = $true
            $picker.Color = [System.Drawing.ColorTranslator]::FromHtml([string]$category.Color)
            if ($picker.ShowDialog($dialog) -ne [System.Windows.Forms.DialogResult]::OK) { return }
            $category.Color = '#{0:X2}{1:X2}{2:X2}' -f $picker.Color.R, $picker.Color.G, $picker.Color.B
            Save-And-RefreshReport -Data $data
            Refresh-CategoryList -SelectId $category.Id
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $delete.Add_Click({
        try {
            $selectedId = Get-ManagedCategoryId
            if ([string]::IsNullOrWhiteSpace($selectedId)) { throw '请先选择类别。' }
            $answer = [System.Windows.Forms.MessageBox]::Show(
                $dialog, '确定删除所选类别？', '确认删除类别',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            $data = Read-TravelData -Path $dataPath
            Remove-TravelCategory -Data $data -Id $selectedId
            Save-And-RefreshReport -Data $data
            Refresh-CategoryList
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $close.Add_Click({ $dialog.Close() })
    Refresh-CategoryList
    [void]$dialog.ShowDialog($form)
    Refresh-CategoryBox
    Refresh-Grid
}

function Show-RateManager {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = '管理默认汇率'
    $dialog.StartPosition = 'CenterParent'
    Initialize-AppWindow -Window $dialog
    $dialog.Size = New-Object System.Drawing.Size(680, 540)
    $dialog.MinimumSize = New-Object System.Drawing.Size(600, 480)
    $dialog.Font = $form.Font

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(14)
    $layout.ColumnCount = 2
    $layout.RowCount = 4
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50))) | Out-Null
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 50))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 100))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 32))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 48))) | Out-Null
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Absolute', 44))) | Out-Null
    $dialog.Controls.Add($layout)

    $list = New-Object System.Windows.Forms.ListBox
    $list.Dock = 'Fill'
    $layout.Controls.Add($list, 0, 0)
    $layout.SetRowSpan($list, 3)

    $help = New-Object System.Windows.Forms.Label
    $help.Dock = 'Fill'
    $help.Padding = New-Object System.Windows.Forms.Padding(10, 6, 0, 4)
    $layout.Controls.Add($help, 1, 0)

    $currencyInput = New-Object System.Windows.Forms.TextBox
    $currencyInput.Dock = 'Fill'
    $currencyInput.MaxLength = 3
    $currencyInput.Margin = New-Object System.Windows.Forms.Padding(10, 2, 0, 2)
    $layout.Controls.Add($currencyInput, 1, 1)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Fill'
    $buttons.Margin = New-Object System.Windows.Forms.Padding(10, 3, 0, 0)
    $layout.Controls.Add($buttons, 1, 2)
    $rateInput = New-Object System.Windows.Forms.TextBox
    $rateInput.Width = 90
    $rateInput.Margin = New-Object System.Windows.Forms.Padding(0, 8, 6, 0)
    $save = New-ActionButton '保存' 68
    $remove = New-ActionButton '删除' 68
    $buttons.Controls.Add($rateInput)
    $buttons.Controls.Add($save)
    $buttons.Controls.Add($remove)
    $close = New-ActionButton '完成' 90
    $close.Anchor = 'Right'
    $layout.Controls.Add($close, 1, 3)

    function Refresh-RateList {
        param([string]$SelectCurrency = '')
        $data = Read-TravelData -Path $dataPath
        $help.Text = "汇率含义：1 原币 = ? $($data.Settings.BaseCurrency)`r`n默认汇率只用于新记录。"
        $list.Items.Clear()
        foreach ($rate in @($data.ExchangeRates | Sort-Object Currency)) {
            $list.Items.Add([pscustomobject]@{
                Currency = $rate.Currency
                Rate = [decimal]$rate.Rate
                Display = ('{0}  →  {1}' -f $rate.Currency, ([decimal]$rate.Rate).ToString('0.######'))
            }) | Out-Null
        }
        $list.DisplayMember = 'Display'
        if (-not [string]::IsNullOrWhiteSpace($SelectCurrency)) {
            for ($i = 0; $i -lt $list.Items.Count; $i++) {
                if ($list.Items[$i].Currency -eq $SelectCurrency) { $list.SelectedIndex = $i; break }
            }
        }
        elseif ($list.Items.Count -gt 0) { $list.SelectedIndex = 0 }
    }
    $list.Add_SelectedIndexChanged({
        if ($list.SelectedItem -ne $null) {
            $currencyInput.Text = [string]$list.SelectedItem.Currency
            $rateInput.Text = ([decimal]$list.SelectedItem.Rate).ToString('0.######')
        }
    })
    $save.Add_Click({
        try {
            $data = Read-TravelData -Path $dataPath
            $currency = $currencyInput.Text.Trim().ToUpperInvariant()
            Set-DefaultExchangeRate -Data $data -Currency $currency -Rate (Parse-PositiveDecimal -Text $rateInput.Text -FieldName '汇率')
            Save-And-RefreshReport -Data $data
            Refresh-RateList -SelectCurrency $currency
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $remove.Add_Click({
        try {
            if ($list.SelectedItem -eq $null) { throw '请先选择币种。' }
            $data = Read-TravelData -Path $dataPath
            $currency = [string]$list.SelectedItem.Currency
            if ($currency -eq [string]$data.Settings.BaseCurrency) { throw '不能删除基准币种汇率。' }
            $data.ExchangeRates = @($data.ExchangeRates | Where-Object { $_.Currency -ne $currency })
            Save-And-RefreshReport -Data $data
            Refresh-RateList
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    $close.Add_Click({ $dialog.Close() })
    Refresh-RateList
    [void]$dialog.ShowDialog($form)
    Refresh-CurrencyBox
    Refresh-Grid
}

function Show-ResetDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = '新建/重置旅行'
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    Initialize-AppWindow -Window $dialog
    $dialog.ClientSize = New-Object System.Drawing.Size(560, 290)
    $dialog.MinimumSize = New-Object System.Drawing.Size(560, 290)
    $dialog.Font = $form.Font

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = 'Fill'
    $layout.Padding = New-Object System.Windows.Forms.Padding(18)
    $layout.ColumnCount = 2
    $layout.RowCount = 4
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Absolute', 95))) | Out-Null
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 100))) | Out-Null
    $dialog.Controls.Add($layout)

    $warning = New-Object System.Windows.Forms.Label
    $warning.Text = '此操作只清空当前文件夹副本，不影响其他旅行文件夹。'
    $warning.Dock = 'Fill'
    $warning.ForeColor = [System.Drawing.Color]::FromArgb(185, 28, 28)
    $layout.Controls.Add($warning, 0, 0)
    $layout.SetColumnSpan($warning, 2)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = '旅行名称'
    $nameLabel.Anchor = 'Left'
    $layout.Controls.Add($nameLabel, 0, 1)
    $nameInput = New-Object System.Windows.Forms.TextBox
    $nameInput.Dock = 'Fill'
    $nameInput.Text = Get-DefaultTripName
    $layout.Controls.Add($nameInput, 1, 1)

    $currencyLabel = New-Object System.Windows.Forms.Label
    $currencyLabel.Text = '基准币种'
    $currencyLabel.Anchor = 'Left'
    $layout.Controls.Add($currencyLabel, 0, 2)
    $baseInput = New-Object System.Windows.Forms.TextBox
    $baseInput.Dock = 'Fill'
    $baseInput.MaxLength = 3
    $baseInput.Text = 'CNY'
    $layout.Controls.Add($baseInput, 1, 2)

    $buttons = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttons.Dock = 'Fill'
    $buttons.FlowDirection = 'RightToLeft'
    $layout.Controls.Add($buttons, 0, 3)
    $layout.SetColumnSpan($buttons, 2)
    $confirm = New-ActionButton '继续' 90
    $cancel = New-ActionButton '取消' 90
    $buttons.Controls.Add($confirm)
    $buttons.Controls.Add($cancel)

    $cancel.Add_Click({ $dialog.Close() })
    $confirm.Add_Click({
        try {
            $newData = New-TravelData -TripName $nameInput.Text -BaseCurrency $baseInput.Text
            $answer = [System.Windows.Forms.MessageBox]::Show(
                $dialog,
                '最终确认：当前副本的所有花费、类别修改和汇率设置都将被清空，是否继续？',
                '确认重置当前旅行',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
            Save-And-RefreshReport -Data $newData
            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dialog.Close()
        }
        catch { Show-Error -Message $_.Exception.Message -Owner $dialog }
    })
    if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $searchBox.Clear()
        Clear-Editor
        Refresh-Grid
    }
}

$grid.Add_SelectionChanged({
    if ($script:refreshingGrid -or $grid.SelectedRows.Count -eq 0) { return }
    try {
        $id = [string]$grid.SelectedRows[0].Cells['Id'].Value
        $data = Read-TravelData -Path $dataPath
        $expense = Find-Expense -Data $data -Id $id
        $script:selectedExpenseId = $expense.Id
        $datePicker.Value = [datetime]::ParseExact($expense.Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $itemBox.Text = $expense.Item
        Refresh-CategoryBox -SelectId $expense.CategoryId
        $amountBox.Text = ([decimal]$expense.OriginalAmount).ToString('0.##')
        Refresh-CurrencyBox -SelectCurrency $expense.Currency
        $rateBox.Text = ([decimal]$expense.ExchangeRate).ToString('0.######')
        $merchantBox.Text = $expense.Merchant
        $notesBox.Text = $expense.Notes
        Update-ConvertedPreview
    }
    catch { Show-Error $_.Exception.Message }
})

$categoryBox.Add_SelectedIndexChanged({
    if ($script:refreshingCategoryBox) { return }

    $data = Read-TravelData -Path $dataPath
    $selectedId = Get-CategoryIdByChoiceIndex -Data $data -Index $categoryBox.SelectedIndex
    if (-not [string]::IsNullOrWhiteSpace($selectedId)) {
        $script:lastCategoryId = $selectedId
        return
    }

    if ($categoryBox.SelectedIndex -ne @($data.Categories).Count) {
        return
    }

    $previousId = $script:lastCategoryId
    $name = Show-NewCategoryNameDialog
    if ($null -eq $name) {
        Refresh-CategoryBox -SelectId $previousId
        return
    }

    try {
        $newCategory = Add-TravelCategory -Data $data -Name $name
        Save-And-RefreshReport -Data $data
        Refresh-CategoryBox -SelectId $newCategory.Id
        Refresh-Grid
    }
    catch {
        Show-Error $_.Exception.Message
        Refresh-CategoryBox -SelectId $previousId
    }
})

$currencyBox.Add_TextChanged({
    try {
        $data = Read-TravelData -Path $dataPath
        $currency = $currencyBox.Text.Trim().ToUpperInvariant()
        if ($currency.Length -ne 3) { Update-ConvertedPreview; return }
        $defaultRate = Get-DefaultExchangeRate -Data $data -Currency $currency
        if ($null -ne $defaultRate) {
            $rateBox.Text = ([decimal]$defaultRate).ToString('0.######')
        }
        elseif ($currency -ne [string]$data.Settings.BaseCurrency) {
            $rateBox.Clear()
        }
        Update-ConvertedPreview
    }
    catch {}
})
$amountBox.Add_TextChanged({ Update-ConvertedPreview })
$rateBox.Add_TextChanged({ Update-ConvertedPreview })
$searchBox.Add_TextChanged({ Refresh-Grid })

$addButton.Add_Click({
    try {
        $data = Read-TravelData -Path $dataPath
        $expense = Get-EditorExpense -Data $data
        $data.Expenses = @($data.Expenses) + $expense
        Save-And-RefreshReport -Data $data
        Clear-Editor
        Refresh-Grid
    }
    catch { Show-Error $_.Exception.Message }
})

$saveButton.Add_Click({
    try {
        if ([string]::IsNullOrWhiteSpace($script:selectedExpenseId)) { throw '请先选择要修改的花费记录。' }
        $data = Read-TravelData -Path $dataPath
        $existing = Find-Expense -Data $data -Id $script:selectedExpenseId
        $replacement = Get-EditorExpense -Data $data
        $existing.Date = $replacement.Date
        $existing.Item = $replacement.Item
        $existing.CategoryId = $replacement.CategoryId
        $existing.OriginalAmount = $replacement.OriginalAmount
        $existing.Currency = $replacement.Currency
        $existing.ExchangeRate = $replacement.ExchangeRate
        $existing.ConvertedAmount = $replacement.ConvertedAmount
        $existing.Merchant = $replacement.Merchant
        $existing.Notes = $replacement.Notes
        $existing.UpdatedAt = (Get-Date).ToString('o')
        Save-And-RefreshReport -Data $data
        Clear-Editor
        Refresh-Grid
    }
    catch { Show-Error $_.Exception.Message }
})

$deleteButton.Add_Click({
    try {
        if ([string]::IsNullOrWhiteSpace($script:selectedExpenseId)) { throw '请先选择要删除的花费记录。' }
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $form, '确定永久删除所选花费记录？', '确认彻底删除',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $data = Read-TravelData -Path $dataPath
        $data.Expenses = @($data.Expenses | Where-Object { $_.Id -ne $script:selectedExpenseId })
        Save-And-RefreshReport -Data $data
        Clear-Editor
        Refresh-Grid
    }
    catch { Show-Error $_.Exception.Message }
})

$clearButton.Add_Click({ Clear-Editor })
$refreshButton.Add_Click({ Clear-Editor; Refresh-Grid })
$categoriesButton.Add_Click({ Show-CategoryManager })
$ratesButton.Add_Click({ Show-RateManager })
$resetButton.Add_Click({ Show-ResetDialog })
$reportButton.Add_Click({
    try {
        & $reportScript -DataPath $dataPath -OutputPath $reportPath -NoOpen | Out-Null
        Start-Process -FilePath $reportPath
    }
    catch { Show-Error $_.Exception.Message }
})

$form.Add_Shown({
    Refresh-CategoryBox
    Refresh-CurrencyBox
    Clear-Editor
    Refresh-Grid
})

[void][System.Windows.Forms.Application]::Run($form)
