Add-Type -AssemblyName System.Drawing

$srcPath = Join-Path $PSScriptRoot 'Sprites\other\exec-16a23d77-e0f7-4aba-be9b-981acbbe9280.png'
$outDir = Join-Path $PSScriptRoot 'Sprites\other\parallax_layers'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$src = [System.Drawing.Bitmap]::new($srcPath)
$w = $src.Width
$h = $src.Height

function New-Mask {
    $m = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($m)
    $g.Clear([System.Drawing.Color]::Black)
    return @{ Bitmap = $m; Graphics = $g }
}

function Add-Poly($g, [int[]]$coords) {
    $pts = New-Object System.Drawing.Point[] ($coords.Count / 2)
    for ($i = 0; $i -lt $coords.Count; $i += 2) {
        $pts[$i / 2] = [System.Drawing.Point]::new($coords[$i], $coords[$i + 1])
    }
    $g.FillPolygon([System.Drawing.Brushes]::White, $pts)
}

function Add-Rect($g, $x, $y, $ww, $hh) {
    $g.FillRectangle([System.Drawing.Brushes]::White, $x, $y, $ww, $hh)
}

function Add-Ellipse($g, $x, $y, $ww, $hh) {
    $g.FillEllipse([System.Drawing.Brushes]::White, $x, $y, $ww, $hh)
}

function Export-Layer($name, $maskObj) {
    $mask = $maskObj.Bitmap
    $out = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $a = $mask.GetPixel($x, $y).R
            if ($a -gt 0) {
                $p = $src.GetPixel($x, $y)
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $p.R, $p.G, $p.B))
            } else {
                $out.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }
        }
    }
    $out.Save((Join-Path $outDir $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $out.Dispose()
    $mask.Dispose()
}

# 01: sky and clouds only. Dark tree silhouettes are filtered out by brightness.
$sky = New-Mask
$sg = $sky.Graphics
Add-Rect $sg 0 0 $w 380
for ($y = 0; $y -lt 380; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $p = $src.GetPixel($x, $y)
        $lum = (0.299 * $p.R) + (0.587 * $p.G) + (0.114 * $p.B)
        if ($lum -lt 58 -or $p.G -lt ($p.R + 5)) {
            $sky.Bitmap.SetPixel($x, $y, [System.Drawing.Color]::Black)
        }
    }
}
$sg.Dispose()
Export-Layer '01_sky.png' $sky

# 02: distant tree line behind the scene.
$forest = New-Mask
$fg = $forest.Graphics
Add-Poly $fg @(0,110, 1680,90, 1680,430, 0,430)
for ($y = 90; $y -lt 430; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $p = $src.GetPixel($x, $y)
        $lum = (0.299 * $p.R) + (0.587 * $p.G) + (0.114 * $p.B)
        $isDarkGreen = ($p.G -ge $p.R - 2) -and ($p.G -ge $p.B - 2) -and ($lum -lt 78)
        if (-not $isDarkGreen) { $forest.Bitmap.SetPixel($x, $y, [System.Drawing.Color]::Black) }
    }
}
# remove the building roof/facade region from the tree layer
Add-Poly $fg @(548,270, 1680,292, 1680,430, 580,430)
$fg.Dispose()
Export-Layer '02_distant_forest.png' $forest

# 03: left industrial structure, railings, stairs, fence, lamp and gate.
$mid = New-Mask
$mg = $mid.Graphics
Add-Poly $mg @(0,405, 224,411, 332,460, 360,610, 580,610, 580,700, 0,700)
Add-Rect $mg 330 120 50 530
Add-Poly $mg @(0,480, 295,480, 360,560, 360,680, 0,680)
Add-Rect $mg 398 438 164 210
Add-Rect $mg 430 425 126 220
Add-Rect $mg 570 590 62 130
$mg.Dispose()
Export-Layer '03_left_industrial.png' $mid

# 04: main building only, including roof, facade, windows and foundation.
$building = New-Mask
$bg = $building.Graphics
Add-Poly $bg @(548,276, 585,270, 1680,300, 1680,720, 579,720, 579,318)
$bg.Dispose()
Export-Layer '04_building.png' $building

# 05: foreground vegetation, barrels, ground and road. Transparent everywhere else.
$front = New-Mask
$pg = $front.Graphics
Add-Poly $pg @(0,635, 180,640, 350,650, 520,665, 700,686, 950,694, 1200,690, 1450,687, 1680,680, 1680,944, 0,944)
Add-Poly $pg @(0,605, 80,620, 180,630, 0,670)
Add-Poly $pg @(250,610, 360,625, 420,660, 300,680)
Add-Poly $pg @(545,610, 650,625, 740,675, 560,700)
Add-Poly $pg @(1000,600, 1120,610, 1260,685, 980,700)
Add-Poly $pg @(1340,600, 1510,615, 1680,650, 1680,705, 1400,700)
Add-Rect $pg 400 590 58 100
Add-Rect $pg 486 590 58 100
Add-Rect $pg 575 610 64 110
Add-Ellipse $pg 615 700 105 42
# Remove bright/yellow facade pixels from the foreground mask while retaining dark weeds.
for ($y = 580; $y -lt 710; $y++) {
    for ($x = 580; $x -lt $w; $x++) {
        $p = $src.GetPixel($x, $y)
        $lum = (0.299 * $p.R) + (0.587 * $p.G) + (0.114 * $p.B)
        $facadeLike = ($lum -gt 72) -or (($p.R -gt $p.G + 7) -and ($p.R -gt $p.B + 12))
        if ($facadeLike) { $front.Bitmap.SetPixel($x, $y, [System.Drawing.Color]::Black) }
    }
}
# Keep the main building completely out of the foreground; its weeds are retained in the building layer.
for ($y = 0; $y -lt 680; $y++) {
    for ($x = 580; $x -lt $w; $x++) {
        $front.Bitmap.SetPixel($x, $y, [System.Drawing.Color]::Black)
    }
}
$pg.Dispose()
Export-Layer '05_foreground.png' $front

$src.Dispose()
Write-Output "Created parallax layers in $outDir"
