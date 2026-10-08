Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot "assets\images\logo.png"
$resBase = Join-Path $PSScriptRoot "android\app\src\main\res"

if (-not (Test-Path $sourcePath)) {
    Write-Error "Source logo not found at $sourcePath"
    exit 1
}

$srcImg = [System.Drawing.Image]::FromFile($sourcePath)

$mipmapSizes = [ordered]@{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
}

$adaptiveSizes = [ordered]@{
    'mipmap-mdpi' = 108
    'mipmap-hdpi' = 162
    'mipmap-xhdpi' = 216
    'mipmap-xxhdpi' = 324
    'mipmap-xxxhdpi' = 432
}

# 1. Generate standard legacy ic_launcher.png (with dark navy background + rounded corners)
foreach ($folder in $mipmapSizes.Keys) {
    $size = $mipmapSizes[$folder]
    $targetDir = Join-Path $resBase $folder
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
    $targetPath = Join-Path $targetDir "ic_launcher.png"

    $destBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # Draw dark navy rounded rect
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#0F172A'))
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $radius = [int]($size * 0.22)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
    $path.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
    $path.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)

    # Draw logo scaled inside
    $padding = [int]($size * 0.08)
    $drawSize = $size - (2 * $padding)
    $g.DrawImage($srcImg, $padding, $padding, $drawSize, $drawSize)

    $g.Dispose()
    $destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated legacy icon: $targetPath ($size px)"
}

# 2. Generate adaptive foreground ic_launcher_foreground.png
foreach ($folder in $adaptiveSizes.Keys) {
    $size = $adaptiveSizes[$folder]
    $targetDir = Join-Path $resBase $folder
    $targetPath = Join-Path $targetDir "ic_launcher_foreground.png"

    $destBmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($destBmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # Adaptive icons safe zone is inner 70%
    $logoSize = [int]($size * 0.72)
    $offset = [int](($size - $logoSize) / 2)
    $g.DrawImage($srcImg, $offset, $offset, $logoSize, $logoSize)

    $g.Dispose()
    $destBmp.Save($targetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $destBmp.Dispose()
    Write-Host "Generated adaptive foreground: $targetPath ($size px)"
}

# 3. Create mipmap-anydpi-v26/ic_launcher.xml for Android 8.0+ adaptive icons
$anyDpiDir = Join-Path $resBase "mipmap-anydpi-v26"
if (-not (Test-Path $anyDpiDir)) { New-Item -ItemType Directory -Path $anyDpiDir | Out-Null }
$anyDpiPath = Join-Path $anyDpiDir "ic_launcher.xml"
$xmlContent = '<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>'
[System.IO.File]::WriteAllText($anyDpiPath, $xmlContent)
Write-Host "Generated adaptive icon config: $anyDpiPath"

# 4. Create values/colors.xml for ic_launcher_background
$valuesDir = Join-Path $resBase "values"
$colorsXmlPath = Join-Path $valuesDir "colors.xml"
$colorsContent = '<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#0F172A</color>
</resources>'
[System.IO.File]::WriteAllText($colorsXmlPath, $colorsContent)
Write-Host "Generated launcher background color: $colorsXmlPath"

$srcImg.Dispose()
Write-Host "All launcher icons generated successfully!"
