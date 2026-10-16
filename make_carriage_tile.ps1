Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Drawing2D

$src = 'C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_continuation.png'
$dst = 'C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_carriage.png'
$bmp = [System.Drawing.Bitmap]::FromFile($src)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor

function Brush($color) { New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($color[0],$color[1],$color[2],$color[3])) }
function Pen($color, $width) { New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($color[0],$color[1],$color[2],$color[3]), $width) }

$body = Brush @(255,8,18,38); $inner = Brush @(255,15,31,57); $dark = Brush @(255,5,13,28)
$outline = Pen @(255,2,7,20) 10; $edge = Pen @(255,28,53,80) 4; $seam = Pen @(255,7,17,34) 5
$g.FillRectangle($body, 410,325,1240,190); $g.DrawRectangle($outline, 410,325,1240,190)
$g.FillRectangle($inner, 420,340,1220,165); $g.DrawRectangle($edge, 420,340,1220,165)
$g.FillRectangle($dark, 420,475,1220,30); $g.FillRectangle((Brush @(255,30,54,76)), 420,337,1220,11)

for($x=470; $x -lt 1540; $x += 175) {
    $frame = Brush @(255,40,44,56); $warm = Brush @(230,196,151,73); $glow = Brush @(210,196,151,73)
    $g.FillRectangle($frame,$x,365,112,60); $g.DrawRectangle((Pen @(255,3,10,25) 5),$x,365,112,60)
    $g.FillRectangle($warm,$x+10,374,92,42); $g.FillRectangle($glow,$x+18,382,76,28)
    $g.DrawLine((Pen @(255,47,43,43) 4),$x+56,374,$x+56,416)
}

$g.FillRectangle((Brush @(255,10,23,44)),1310,351,140,154); $g.DrawRectangle((Pen @(255,38,61,83) 5),1310,351,140,154)
$g.FillRectangle((Brush @(255,111,87,51)),1330,368,100,69); $g.DrawRectangle((Pen @(255,3,10,24) 4),1330,368,100,69)
$g.FillRectangle((Brush @(220,178,135,67)),1341,378,78,50); $g.DrawLine((Pen @(255,46,44,44) 3),1380,368,1380,437)
foreach($x in @(700,1000,1570)) { $g.DrawLine($seam,$x,348,$x,505) }

$g.FillRectangle((Brush @(255,3,8,18)),500,505,1050,43); $g.DrawRectangle((Pen @(255,20,31,46) 4),500,505,1050,43)
foreach($x in @(600,910,1230,1500)) {
    $g.FillEllipse((Brush @(255,3,7,15)),$x-35,515,70,70); $g.DrawEllipse((Pen @(255,35,50,63) 7),$x-35,515,70,70)
    $g.FillRectangle((Brush @(220,94,78,48)),$x-8,535,16,30)
}
$g.FillRectangle((Brush @(255,5,10,20)),350,505,70,30); $g.FillRectangle((Brush @(255,5,10,20)),1640,505,80,30)
$g.FillRectangle((Brush @(255,132,22,26)),424,455,15,20); $g.FillRectangle((Brush @(255,132,22,26)),1620,455,15,20)

$bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
