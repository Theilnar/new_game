Add-Type -AssemblyName System.Drawing

$basePath = 'C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_continuation.png'
$trainPath = 'C:\Users\Admin\Documents\box_push\train_station_parallax_midground.png'
$outPath = 'C:\Users\Admin\Documents\box_push\train_station_near_lit_layer_carriage.png'

$base = [System.Drawing.Bitmap]::FromFile($basePath)
$train = [System.Drawing.Bitmap]::FromFile($trainPath)
$g = [System.Drawing.Graphics]::FromImage($base)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

# Extract a clean passenger-car section from the finished station train.
$crop = New-Object System.Drawing.Rectangle(180, 415, 420, 105)
$car = $train.Clone($crop, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$scaled = New-Object System.Drawing.Bitmap(920, 230, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cg = [System.Drawing.Graphics]::FromImage($scaled)
$cg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$cg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$cg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$cg.DrawImage($car, 0, 0, 920, 230)
$cg.Dispose()

# Place the matched carriage above the same rails/platform continuation.
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 5, 13, 28))), 540, 304, 920, 26)
$g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 28, 53, 80), 4)), 540, 304, 920, 26)
$g.DrawImage($scaled, 540, 330, 920, 230)

$base.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $scaled.Dispose(); $car.Dispose(); $train.Dispose(); $base.Dispose()
