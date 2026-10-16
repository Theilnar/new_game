Add-Type -AssemblyName System.Drawing

$outPath = Join-Path $PSScriptRoot 'Sprites\other\parallax_layers\00_sky_gradient.png'
$w = 1680
$h = 944
$skyEnd = 390
$bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

function Mix($a, $b, [double]$t) {
    return [int][Math]::Round($a + (($b - $a) * $t))
}

# Dark green-gray night sky, brighter near the horizon.
$top = @(50, 66, 51)
$bottom = @(86, 103, 81)
for ($y = 0; $y -lt $h; $y++) {
    if ($y -lt $skyEnd) {
        $t = $y / [double]($skyEnd - 1)
        $cTop = $top
        $cBottom = $bottom
    } else {
        # Continue into a dark green atmospheric base so the canvas is fully covered.
        $t = ($y - $skyEnd) / [double]($h - $skyEnd - 1)
        $cTop = $bottom
        $cBottom = @(27, 38, 30)
    }
    # Keep the gradient stepped enough to remain compatible with pixel art.
    $t = [Math]::Floor($t * 32) / 32
    $c = [System.Drawing.Color]::FromArgb(255, (Mix $cTop[0] $cBottom[0] $t), (Mix $cTop[1] $cBottom[1] $t), (Mix $cTop[2] $cBottom[2] $t))
    for ($x = 0; $x -lt $w; $x++) { $bmp.SetPixel($x, $y, $c) }
}

$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

# Broad blocky cloud bands, kept soft and low-contrast.
$cloud1 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150, 90, 108, 87))
$cloud2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(125, 102, 119, 96))
$cloud3 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(100, 68, 86, 69))

$g.FillPolygon($cloud1, @([Drawing.Point]::new(0,92),[Drawing.Point]::new(105,92),[Drawing.Point]::new(105,77),[Drawing.Point]::new(230,77),[Drawing.Point]::new(230,99),[Drawing.Point]::new(390,99),[Drawing.Point]::new(390,118),[Drawing.Point]::new(0,118)))
$g.FillPolygon($cloud2, @([Drawing.Point]::new(505,126),[Drawing.Point]::new(600,126),[Drawing.Point]::new(600,108),[Drawing.Point]::new(735,108),[Drawing.Point]::new(735,91),[Drawing.Point]::new(820,91),[Drawing.Point]::new(820,113),[Drawing.Point]::new(952,113),[Drawing.Point]::new(952,139),[Drawing.Point]::new(505,139)))
$g.FillPolygon($cloud1, @([Drawing.Point]::new(980,88),[Drawing.Point]::new(1090,88),[Drawing.Point]::new(1090,68),[Drawing.Point]::new(1230,68),[Drawing.Point]::new(1230,89),[Drawing.Point]::new(1370,89),[Drawing.Point]::new(1370,111),[Drawing.Point]::new(980,111)))
$g.FillPolygon($cloud2, @([Drawing.Point]::new(1360,142),[Drawing.Point]::new(1455,142),[Drawing.Point]::new(1455,122),[Drawing.Point]::new(1590,122),[Drawing.Point]::new(1590,140),[Drawing.Point]::new(1680,140),[Drawing.Point]::new(1680,166),[Drawing.Point]::new(1360,166)))
$g.FillPolygon($cloud3, @([Drawing.Point]::new(0,206),[Drawing.Point]::new(180,206),[Drawing.Point]::new(180,190),[Drawing.Point]::new(335,190),[Drawing.Point]::new(335,210),[Drawing.Point]::new(485,210),[Drawing.Point]::new(485,231),[Drawing.Point]::new(0,231)))
$g.FillPolygon($cloud3, @([Drawing.Point]::new(770,220),[Drawing.Point]::new(930,220),[Drawing.Point]::new(930,201),[Drawing.Point]::new(1085,201),[Drawing.Point]::new(1085,224),[Drawing.Point]::new(1250,224),[Drawing.Point]::new(1250,245),[Drawing.Point]::new(770,245)))

$cloud1.Dispose(); $cloud2.Dispose(); $cloud3.Dispose(); $g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "Created $outPath"
