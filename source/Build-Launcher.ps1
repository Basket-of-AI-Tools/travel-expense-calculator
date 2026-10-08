Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
$iconPath = Join-Path $root '旅行花费计算器.ico'
$sourcePath = Join-Path $root 'Launcher.cs'
$outputPath = Join-Path $root '旅行花费计算器.exe'

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw '缺少 Launcher.cs。'
}

$bitmap = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$background = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(15, 118, 110))
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$softWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 255, 255, 255))
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$radius = 48
$path.AddArc(16, 16, $radius, $radius, 180, 90)
$path.AddArc(192, 16, $radius, $radius, 270, 90)
$path.AddArc(192, 192, $radius, $radius, 0, 90)
$path.AddArc(16, 192, $radius, $radius, 90, 90)
$path.CloseFigure()
$graphics.FillPath($background, $path)

# Suitcase body and handle.
$graphics.FillRectangle($white, 48, 86, 160, 112)
$graphics.FillRectangle($background, 66, 108, 10, 68)
$graphics.FillRectangle($background, 180, 108, 10, 68)
$graphics.FillRectangle($white, 92, 58, 72, 20)
$graphics.FillRectangle($background, 108, 58, 40, 10)

# Three spending/statistics bars.
$graphics.FillRectangle($background, 92, 145, 16, 31)
$graphics.FillRectangle($background, 120, 126, 16, 50)
$graphics.FillRectangle($background, 148, 106, 16, 70)
$graphics.FillEllipse($softWhite, 40, 190, 28, 28)
$graphics.FillEllipse($softWhite, 188, 190, 28, 28)

$graphics.Dispose()
$background.Dispose()
$white.Dispose()
$softWhite.Dispose()
$path.Dispose()

$iconHandle = $bitmap.GetHicon()
try {
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    $stream = [System.IO.File]::Open($iconPath, [System.IO.FileMode]::Create)
    try { $icon.Save($stream) } finally { $stream.Dispose() }
}
finally {
    $bitmap.Dispose()
}

$compiler = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($compiler)) {
    throw '没有找到 .NET Framework C# 编译器。'
}

$arguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    "/win32icon:$iconPath",
    '/reference:System.dll',
    '/reference:System.Windows.Forms.dll',
    "/out:$outputPath",
    $sourcePath
)

& $compiler $arguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
    throw '便携启动器编译失败。'
}

Write-Output $outputPath
