param(
  [string]$SourceDocx = "C:\Users\van\Downloads\Bao_cao_JWT_an_toan_da_sua.docx",
  [string]$OutputDocx = (Join-Path $PSScriptRoot "..\docs\Bao_cao_JWT_an_toan_hoan_chinh.docx"),
  [string]$DiagramPng = (Join-Path $PSScriptRoot "..\docs\token-storage-model.png")
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Convert-Utf8Literal([string]$Text) {
  return [System.Text.Encoding]::UTF8.GetString([System.Text.Encoding]::GetEncoding(1252).GetBytes($Text))
}

function New-RoundedRectanglePath {
  param([float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $diameter = $Radius * 2
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
  $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function Draw-Box {
  param(
    [System.Drawing.Graphics]$Graphics,
    [float]$X, [float]$Y, [float]$Width, [float]$Height,
    [string]$Text,
    [System.Drawing.Color]$Fill,
    [System.Drawing.Color]$Stroke,
    [System.Drawing.Font]$Font
  )
  $path = New-RoundedRectanglePath $X $Y $Width $Height 22
  $brush = [System.Drawing.SolidBrush]::new($Fill)
  $pen = [System.Drawing.Pen]::new($Stroke, 4)
  $Graphics.FillPath($brush, $path)
  $Graphics.DrawPath($pen, $path)
  $format = [System.Drawing.StringFormat]::new()
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = [System.Drawing.RectangleF]::new($X + 12, $Y + 8, $Width - 24, $Height - 16)
  $Graphics.DrawString($Text, $Font, [System.Drawing.Brushes]::Black, $rect, $format)
  $format.Dispose()
  $pen.Dispose()
  $brush.Dispose()
  $path.Dispose()
}

function Draw-Arrow {
  param(
    [System.Drawing.Graphics]$Graphics,
    [float]$X1, [float]$Y1, [float]$X2, [float]$Y2,
    [string]$Label = "",
    [float]$LabelX = 0, [float]$LabelY = 0,
    [bool]$Dashed = $false
  )
  $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(68, 75, 86), 4)
  if ($Dashed) { $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash }
  $cap = [System.Drawing.Drawing2D.AdjustableArrowCap]::new(7, 8, $true)
  $pen.CustomEndCap = $cap
  $Graphics.DrawLine($pen, $X1, $Y1, $X2, $Y2)
  if ($Label) {
    $labelFont = [System.Drawing.Font]::new("Segoe UI", 18, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $Graphics.DrawString($Label, $labelFont, [System.Drawing.Brushes]::Black, $LabelX, $LabelY)
    $labelFont.Dispose()
  }
  $cap.Dispose()
  $pen.Dispose()
}

$width = 1710
$height = 895
$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.Color]::White)

$titleFont = [System.Drawing.Font]::new("Segoe UI", 38, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$boxFont = [System.Drawing.Font]::new("Segoe UI", 25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$smallFont = [System.Drawing.Font]::new("Segoe UI", 20, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$noteFont = [System.Drawing.Font]::new("Segoe UI", 19, [System.Drawing.FontStyle]::Italic, [System.Drawing.GraphicsUnit]::Pixel)

$titleFormat = [System.Drawing.StringFormat]::new()
$titleFormat.Alignment = [System.Drawing.StringAlignment]::Center
$graphics.DrawString(
  (Convert-Utf8Literal "Mô hình lưu và sử dụng token an toàn cho ứng dụng web"),
  $titleFont,
  [System.Drawing.Brushes]::Black,
  [System.Drawing.RectangleF]::new(80, 34, 1550, 60),
  $titleFormat
)

$blueFill = [System.Drawing.Color]::FromArgb(237, 244, 252)
$blueStroke = [System.Drawing.Color]::FromArgb(54, 97, 151)
$greenFill = [System.Drawing.Color]::FromArgb(237, 248, 239)
$greenStroke = [System.Drawing.Color]::FromArgb(61, 124, 75)
$orangeFill = [System.Drawing.Color]::FromArgb(255, 246, 232)
$orangeStroke = [System.Drawing.Color]::FromArgb(166, 104, 32)
$grayFill = [System.Drawing.Color]::FromArgb(246, 247, 249)
$grayStroke = [System.Drawing.Color]::FromArgb(96, 104, 116)

Draw-Box $graphics 80 145 260 115 (Convert-Utf8Literal "Client / trình duyệt") $grayFill $grayStroke $boxFont
Draw-Box $graphics 520 130 330 125 (Convert-Utf8Literal "Keycloak`nXác thực và cấp token") $blueFill $blueStroke $boxFont
Draw-Box $graphics 600 340 300 110 (Convert-Utf8Literal "Access token`nlưu trong RAM") $greenFill $greenStroke $boxFont
Draw-Box $graphics 1080 340 330 110 "Refresh token`nHttpOnly Cookie" $orangeFill $orangeStroke $boxFont
Draw-Box $graphics 285 600 310 110 (Convert-Utf8Literal "API Gateway`nkiểm tra JWT") $blueFill $blueStroke $boxFont
Draw-Box $graphics 720 600 310 110 (Convert-Utf8Literal "Finance API`nkiểm tra role") $blueFill $blueStroke $boxFont
Draw-Box $graphics 1175 600 280 110 (Convert-Utf8Literal "PostgreSQL`nnội bộ") $grayFill $grayStroke $boxFont

Draw-Arrow $graphics 340 190 520 190 (Convert-Utf8Literal "Đăng nhập") 374 150
Draw-Arrow $graphics 650 255 730 340 (Convert-Utf8Literal "Cấp access token") 480 275
Draw-Arrow $graphics 775 255 1190 340 (Convert-Utf8Literal "Cấp refresh token") 900 275
Draw-Arrow $graphics 600 430 475 600 "Authorization: Bearer" 285 490
Draw-Arrow $graphics 595 655 720 655 "Proxy + Bearer JWT" 570 615
Draw-Arrow $graphics 1030 655 1175 655 "SQL" 1080 615
Draw-Arrow $graphics 1245 340 835 255 (Convert-Utf8Literal "Khi access token hết hạn:`nrefresh để nhận bộ token mới") 1010 185 $true

$graphics.DrawString(
  (Convert-Utf8Literal "Demo CLI hiện giữ cả hai token tạm thời trong RAM; HttpOnly + Secure + SameSite là mô hình khuyến nghị khi triển khai client web."),
  $noteFont,
  [System.Drawing.Brushes]::DimGray,
  [System.Drawing.RectangleF]::new(170, 785, 1370, 60),
  $titleFormat
)

$diagramDirectory = Split-Path -Parent $DiagramPng
if (-not (Test-Path $diagramDirectory)) { New-Item -ItemType Directory -Path $diagramDirectory | Out-Null }
$bitmap.Save($DiagramPng, [System.Drawing.Imaging.ImageFormat]::Png)

$titleFormat.Dispose()
$noteFont.Dispose()
$smallFont.Dispose()
$boxFont.Dispose()
$titleFont.Dispose()
$graphics.Dispose()
$bitmap.Dispose()

if (-not (Test-Path -LiteralPath $SourceDocx)) {
  throw "Source DOCX not found: $SourceDocx"
}

$outputDirectory = Split-Path -Parent $OutputDocx
if (-not (Test-Path $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory | Out-Null }
Copy-Item -LiteralPath $SourceDocx -Destination $OutputDocx -Force

$archive = [System.IO.Compression.ZipFile]::Open($OutputDocx, [System.IO.Compression.ZipArchiveMode]::Update)
try {
  $oldImage = $archive.GetEntry("word/media/image2.png")
  if (-not $oldImage) { throw "word/media/image2.png not found in report" }
  $oldImage.Delete()
  $newImage = $archive.CreateEntry("word/media/image2.png", [System.IO.Compression.CompressionLevel]::Optimal)
  $imageInput = [System.IO.File]::OpenRead($DiagramPng)
  $imageOutput = $newImage.Open()
  try { $imageInput.CopyTo($imageOutput) } finally { $imageOutput.Dispose(); $imageInput.Dispose() }

  $documentEntry = $archive.GetEntry("word/document.xml")
  $reader = [System.IO.StreamReader]::new($documentEntry.Open())
  try { $documentXml = $reader.ReadToEnd() } finally { $reader.Dispose() }
  $documentXml = $documentXml.Replace(
    (Convert-Utf8Literal "Hình 5.1. Mô hình khuyến nghị khi triển khai web: access token trong RAM và refresh token bằng HttpOnly Cookie"),
    (Convert-Utf8Literal "Hình 5.1. Mô hình lưu và sử dụng token an toàn khuyến nghị khi triển khai ứng dụng web")
  )
  $documentEntry.Delete()
  $newDocumentEntry = $archive.CreateEntry("word/document.xml", [System.IO.Compression.CompressionLevel]::Optimal)
  $writer = [System.IO.StreamWriter]::new($newDocumentEntry.Open(), [System.Text.UTF8Encoding]::new($false))
  try { $writer.Write($documentXml) } finally { $writer.Dispose() }
} finally {
  $archive.Dispose()
}

Write-Host "Created diagram: $DiagramPng"
Write-Host "Created report:  $OutputDocx"
