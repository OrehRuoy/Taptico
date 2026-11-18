# Taptico App Store screenshots — iPad 13" (2064 x 2752).
# Same set / copy / panoramic gold language as iPhone 6.5", extra width filled
# with lock-dial hardware so neighbors still join.

Add-Type -AssemblyName System.Drawing

$Root = "C:\Users\Ultima\Desktop\Taptico\store"
$OutDir = Join-Path $Root "ipad-13"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$CanvasW = 2064
$CanvasH = 2752

$slides = @(
    @{
        src = "IMG_0027.png"
        file = "01-haptic-fidgets.png"
        title = "REAL HAPTIC`nFIDGETS"
        sub = "Metal toys. Real clicks from the Taptic Engine."
        pills = @("Haptics", "Quiet", "Desk toys")
        badge = "FREE TOY"
    }
    @{
        src = "IMG_0028.png"
        file = "02-asmr-pops.png"
        title = "ASMR CLICKS`n& POPS"
        sub = "Pop a row of dimples. Reset and do it again."
        pills = @("Dimples", "Pops", "ASMR")
        badge = $null
    }
    @{
        src = "IMG_0029.png"
        file = "03-desk-focus.png"
        title = "QUIET DESK`nFOCUS"
        sub = "Stick, gear, stone, and clicker faces on one cube."
        pills = @("Desk cube", "Stick", "Clicker")
        badge = $null
    }
    @{
        src = "IMG_0030.png"
        file = "04-spin-feel.png"
        title = "SPIN. CLICK.`nFEEL."
        sub = "A heavy metal spinner with tilt weight."
        pills = @("Spinner", "Tilt", "Metal")
        badge = $null
    }
    @{
        src = "IMG_0031.png"
        file = "05-zip-fold.png"
        title = "ZIP. FOLD.`nFIDGET."
        sub = "Zipper, infinity cube, and more in one set."
        pills = @("Zipper", "Infinity", "Catalog")
        badge = $null
    }
    @{
        src = "IMG_0035.png"
        file = "06-three-free.png"
        title = "THREE TOYS`nFREE"
        sub = "Lock, switches, and slider. No account."
        pills = @("Lock", "Switches", "Slider")
        badge = "FREE"
    }
    @{
        src = "IMG_0036.png"
        file = "07-lifetime.png"
        title = "NO ADS.`nONE BUY."
        sub = "Lifetime unlock. Restore is always there."
        pills = @("No ads", "Lifetime", "Restore")
        badge = "ONCE"
    }
)

$N = $slides.Count
$TotalW = $CanvasW * $N

function New-Color([int]$a, [int]$r, [int]$g, [int]$b) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-RoundPath([int]$x, [int]$y, [int]$w, [int]$h, [int]$radius) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [Math]::Max(2, $radius * 2)
    if ($d -gt $w) { $d = $w }
    if ($d -gt $h) { $d = $h }
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Draw-LockDial($g, [int]$cx, [int]$cy, [int]$radius, [int]$alpha) {
    if ($cx + $radius -lt -40 -or $cx - $radius -gt $script:CanvasW + 40) { return }
    $outer = New-Object System.Drawing.SolidBrush (New-Color ([Math]::Min(255, $alpha + 20)) 28 22 16)
    $g.FillEllipse($outer, $cx - $radius, $cy - $radius, $radius * 2, $radius * 2)
    $outer.Dispose()

    $ringW = [Math]::Max(4, [int]($radius * 0.045))
    $ringCol = New-Color $alpha 201 162 72
    $goldPen = New-Object System.Drawing.Pen $ringCol, $ringW
    $g.DrawEllipse($goldPen, $cx - $radius, $cy - $radius, $radius * 2, $radius * 2)
    $goldPen.Dispose()

    $mid = [int]($radius * 0.78)
    $midPen = New-Object System.Drawing.Pen (New-Color ([int]($alpha * 0.7)) 212 174 84), 3
    $g.DrawEllipse($midPen, $cx - $mid, $cy - $mid, $mid * 2, $mid * 2)
    $midPen.Dispose()

    $tickPen = New-Object System.Drawing.Pen (New-Color ([int]($alpha * 0.85)) 232 204 128), 2.2
    $tickPenLong = New-Object System.Drawing.Pen (New-Color $alpha 232 204 128), 3.0
    for ($t = 0; $t -lt 36; $t++) {
        $ang = $t * 10 * [Math]::PI / 180.0
        $inner = if ($t % 9 -eq 0) { $radius * 0.62 } else { $radius * 0.70 }
        $x0 = [int]($cx + [Math]::Cos($ang) * $inner)
        $y0 = [int]($cy + [Math]::Sin($ang) * $inner)
        $x1 = [int]($cx + [Math]::Cos($ang) * ($radius * 0.92))
        $y1 = [int]($cy + [Math]::Sin($ang) * ($radius * 0.92))
        if ($t % 9 -eq 0) { $g.DrawLine($tickPenLong, $x0, $y0, $x1, $y1) }
        else { $g.DrawLine($tickPen, $x0, $y0, $x1, $y1) }
    }
    $tickPen.Dispose()
    $tickPenLong.Dispose()

    $knobR = [int]($radius * 0.28)
    $knob = New-Object System.Drawing.SolidBrush (New-Color ([Math]::Min(255, $alpha + 40)) 16 14 13)
    $g.FillEllipse($knob, $cx - $knobR, $cy - $knobR, $knobR * 2, $knobR * 2)
    $knob.Dispose()
    $knobPen = New-Object System.Drawing.Pen (New-Color $alpha 186 148 64), 3
    $g.DrawEllipse($knobPen, $cx - $knobR, $cy - $knobR, $knobR * 2, $knobR * 2)
    $knobPen.Dispose()

    $ptr = New-Object System.Drawing.SolidBrush (New-Color $alpha 201 162 72)
    $pts = @(
        [System.Drawing.Point]::new($cx, $cy - $radius + 8),
        [System.Drawing.Point]::new($cx - 10, $cy - $radius + 32),
        [System.Drawing.Point]::new($cx + 10, $cy - $radius + 32)
    )
    $g.FillPolygon($ptr, $pts)
    $ptr.Dispose()
}

function Draw-Screw($g, [int]$cx, [int]$cy, [int]$r) {
    $br = New-Object System.Drawing.SolidBrush (New-Color 200 186 148 64)
    $g.FillEllipse($br, $cx - $r, $cy - $r, $r * 2, $r * 2)
    $br.Dispose()
    $inner = New-Object System.Drawing.SolidBrush (New-Color 220 42 36 28)
    $ir = [int]($r * 0.62)
    $g.FillEllipse($inner, $cx - $ir, $cy - $ir, $ir * 2, $ir * 2)
    $inner.Dispose()
    $pen = New-Object System.Drawing.Pen (New-Color 230 232 204 128), 2.4
    $g.DrawLine($pen, $cx - $ir + 2, $cy, $cx + $ir - 2, $cy)
    $pen.Dispose()
}

function Draw-WorldBackdrop($g, [int]$ox, [int]$localW, [int]$localH, [int]$worldW) {
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        [System.Drawing.Rectangle]::new(-40, 0, $localW + 80, $localH),
        (New-Color 255 10 9 8),
        (New-Color 255 28 22 16),
        95
    )
    $g.FillRectangle($bg, 0, 0, $localW, $localH)
    $bg.Dispose()

    $rng = New-Object System.Random 42
    for ($y = 0; $y -lt $localH; $y += 3) {
        $a = 6 + ($rng.Next(0, 14))
        $goldish = $rng.Next(0, 3) -eq 0
        $col = if ($goldish) { New-Color $a 196 158 86 } else { New-Color $a 90 84 76 }
        $pen = New-Object System.Drawing.Pen $col, 1.0
        $g.DrawLine($pen, 0, $y, $localW, $y)
        $pen.Dispose()
    }

    $wells = @(
        @{ x = 1450; y = 180; s = 920 },
        @{ x = 3380; y = 1580; s = 1100 },
        @{ x = 5780; y = 40; s = 820 },
        @{ x = 8360; y = 1880; s = 980 },
        @{ x = 10920; y = 360; s = 1080 },
        @{ x = 13180; y = 1360; s = 880 }
    )
    foreach ($well in $wells) {
        $wx = $well.x - $ox
        $wy = $well.y
        if ($wx + $well.s -lt -80 -or $wx -gt $localW + 80) { continue }
        $br = New-Object System.Drawing.SolidBrush (New-Color 28 201 162 72)
        $g.FillEllipse($br, $wx, $wy, $well.s, $well.s)
        $br.Dispose()
    }

    $ribbons = @(
        @{ y0 = -200; y1 = $localH + 200; thick = 32; a = 55 },
        @{ y0 = 380; y1 = $localH + 680; thick = 16; a = 40 },
        @{ y0 = -520; y1 = $localH - 80; thick = 48; a = 22 }
    )
    foreach ($rib in $ribbons) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $x0 = 0 - $ox
        $x1 = [int]($worldW * 0.33) - $ox
        $x2 = [int]($worldW * 0.66) - $ox
        $x3 = $worldW - $ox
        $path.AddBezier($x0, $rib.y0, $x1, $rib.y0 + 380, $x2, $rib.y1 - 520, $x3, $rib.y1)
        $pen = New-Object System.Drawing.Pen (New-Color $rib.a 212 170 78), $rib.thick
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    }

    $rings = @(
        @{ x = 1900; y = 640; r = 260 },
        @{ x = 4020; y = 2080; r = 210 },
        @{ x = 6270; y = 500; r = 300 },
        @{ x = 10280; y = 1980; r = 230 },
        @{ x = 12540; y = 680; r = 280 }
    )
    foreach ($rg in $rings) {
        $cx = $rg.x - $ox
        if ($cx + $rg.r -lt -20 -or $cx - $rg.r -gt $localW + 20) { continue }
        $pen = New-Object System.Drawing.Pen (New-Color 50 212 174 84), 7
        $g.DrawEllipse($pen, $cx - $rg.r, $rg.y - $rg.r, $rg.r * 2, $rg.r * 2)
        $pen.Dispose()
        $pen2 = New-Object System.Drawing.Pen (New-Color 28 212 174 84), 3.5
        $g.DrawEllipse($pen2, $cx - [int]($rg.r * 0.62), $rg.y - [int]($rg.r * 0.62), [int]($rg.r * 1.24), [int]($rg.r * 1.24))
        $pen2.Dispose()
    }

    # Gutter lock dials — sit in the extra iPad side space and straddle neighbors.
    $dials = @(
        @{ x = 170; y = 1680; r = 210; a = 70 },
        @{ x = 2064; y = 980; r = 240; a = 58 },
        @{ x = 4128; y = 1880; r = 200; a = 64 },
        @{ x = 6192; y = 720; r = 230; a = 52 },
        @{ x = 8256; y = 1760; r = 250; a = 60 },
        @{ x = 10320; y = 860; r = 215; a = 56 },
        @{ x = 12384; y = 1620; r = 235; a = 62 },
        @{ x = 14300; y = 1100; r = 200; a = 50 }
    )
    foreach ($dial in $dials) {
        Draw-LockDial $g ($dial.x - $ox) $dial.y $dial.r $dial.a
    }

    $screws = @(
        @{ x = 90; y = 420 }, @{ x = 1974; y = 420 },
        @{ x = 2154; y = 2380 }, @{ x = 4038; y = 240 },
        @{ x = 6282; y = 2480 }, @{ x = 8166; y = 300 },
        @{ x = 10410; y = 2420 }, @{ x = 12294; y = 260 },
        @{ x = 14448; y = 420 }
    )
    foreach ($sc in $screws) {
        $sx = $sc.x - $ox
        if ($sx -lt -20 -or $sx -gt $localW + 20) { continue }
        Draw-Screw $g $sx $sc.y 18
    }

    # Lock-tick ruler along the panorama so the side gutters feel mechanical.
    $tickPen = New-Object System.Drawing.Pen (New-Color 36 201 162 72), 2.0
    $tickPenMajor = New-Object System.Drawing.Pen (New-Color 70 232 204 128), 2.6
    for ($wx = 0; $wx -lt $worldW; $wx += 28) {
        $lx = $wx - $ox
        if ($lx -lt -4 -or $lx -gt $localW + 4) { continue }
        $major = ($wx % 140 -eq 0)
        $len = if ($major) { 28 } else { 14 }
        $penUse = if ($major) { $tickPenMajor } else { $tickPen }
        $g.DrawLine($penUse, $lx, $localH - 18, $lx, $localH - 18 - $len)
        $g.DrawLine($penUse, $lx, 18, $lx, 18 + $len)
    }
    $tickPen.Dispose()
    $tickPenMajor.Dispose()
}

function Draw-GlowText($g, [string]$text, $font, $rect, $fill, [int]$glowA) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Near
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoClip
    $glow = New-Object System.Drawing.SolidBrush (New-Color $glowA 212 170 78)
    foreach ($offX in @(-3, 3, 0)) {
        foreach ($offY in @(-3, 3, 0)) {
            if ($offX -eq 0 -and $offY -eq 0) { continue }
            $r = New-Object System.Drawing.RectangleF ($rect.X + $offX), ($rect.Y + $offY), $rect.Width, $rect.Height
            $g.DrawString($text, $font, $glow, $r, $sf)
        }
    }
    $glow.Dispose()
    $g.DrawString($text, $font, $fill, $rect, $sf)
    $sf.Dispose()
}

function Draw-Pill($g, [string]$label, $font, [int]$x, [int]$y, [bool]$filled) {
    $size = $g.MeasureString($label, $font)
    $pw = [int]($size.Width + 42)
    $ph = 58
    $path = New-RoundPath $x $y $pw $ph 29
    if ($filled) {
        $br = New-Object System.Drawing.SolidBrush (New-Color 255 201 162 72)
        $g.FillPath($br, $path)
        $br.Dispose()
        $tb = New-Object System.Drawing.SolidBrush (New-Color 255 18 14 12)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString($label, $font, $tb, (New-Object System.Drawing.RectangleF $x, $y, $pw, $ph), $sf)
        $sf.Dispose()
        $tb.Dispose()
    } else {
        $pen = New-Object System.Drawing.Pen (New-Color 220 201 162 72), 2.5
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $tb = New-Object System.Drawing.SolidBrush (New-Color 255 232 208 140)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString($label, $font, $tb, (New-Object System.Drawing.RectangleF $x, $y, $pw, $ph), $sf)
        $sf.Dispose()
        $tb.Dispose()
    }
    $path.Dispose()
    return $pw
}

function Draw-Badge($g, [string]$label, $font, [int]$cx, [int]$cy) {
    $r = 108
    $br = New-Object System.Drawing.SolidBrush (New-Color 235 28 22 16)
    $g.FillEllipse($br, $cx - $r, $cy - $r, $r * 2, $r * 2)
    $br.Dispose()
    $pen = New-Object System.Drawing.Pen (New-Color 255 201 162 72), 4
    $pen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $g.DrawEllipse($pen, $cx - $r, $cy - $r, $r * 2, $r * 2)
    $pen.Dispose()
    $tb = New-Object System.Drawing.SolidBrush (New-Color 255 232 208 140)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($label, $font, $tb, (New-Object System.Drawing.RectangleF ($cx - $r + 8), ($cy - 32), ($r * 2 - 16), 64), $sf)
    $sf.Dispose()
    $tb.Dispose()
}

function Draw-Phone($g, $shot, [int]$x, [int]$y, [int]$w, [int]$h) {
    $bezel = 26
    $radius = 68
    $shadow = New-Object System.Drawing.SolidBrush (New-Color 150 0 0 0)
    $sp = New-RoundPath ($x + 22) ($y + 34) $w $h ($radius + 4)
    $g.FillPath($shadow, $sp)
    $shadow.Dispose()
    $sp.Dispose()

    $halo = New-Object System.Drawing.SolidBrush (New-Color 36 201 162 72)
    $g.FillEllipse($halo, $x - 80, $y + [int]($h * 0.12), ($w + 160), [int]($h * 0.78))
    $halo.Dispose()

    $desk = New-Object System.Drawing.SolidBrush (New-Color 40 18 16 14)
    $g.FillEllipse($desk, $x - 70, $y + $h - 90, $w + 140, 160)
    $desk.Dispose()
    $deskPen = New-Object System.Drawing.Pen (New-Color 50 201 162 72), 2
    $g.DrawEllipse($deskPen, $x - 70, $y + $h - 90, $w + 140, 160)
    $deskPen.Dispose()

    $goldPath = New-RoundPath ($x - 4) ($y - 4) ($w + 8) ($h + 8) ($radius + 5)
    $goldBr = New-Object System.Drawing.SolidBrush (New-Color 255 186 148 64)
    $g.FillPath($goldBr, $goldPath)
    $goldBr.Dispose()
    $goldPath.Dispose()

    $body = New-RoundPath $x $y $w $h $radius
    $bodyBr = New-Object System.Drawing.SolidBrush (New-Color 255 16 14 13)
    $g.FillPath($bodyBr, $body)
    $bodyBr.Dispose()

    $ix = $x + $bezel
    $iy = $y + $bezel
    $iw = $w - $bezel * 2
    $ih = $h - $bezel * 2
    $innerR = [Math]::Max(32, $radius - 18)
    $clip = New-RoundPath $ix $iy $iw $ih $innerR
    $state = $g.Save()
    $g.SetClip($clip)
    $g.DrawImage($shot, $ix, $iy, $iw, $ih)
    $g.Restore($state)
    $clip.Dispose()
    $body.Dispose()

    $islandW = 186
    $islandH = 42
    $ix0 = $x + [int](($w - $islandW) / 2)
    $iy0 = $y + 20
    $island = New-RoundPath $ix0 $iy0 $islandW $islandH 21
    $ibl = New-Object System.Drawing.SolidBrush (New-Color 255 6 6 6)
    $g.FillPath($ibl, $island)
    $ibl.Dispose()
    $island.Dispose()
}

function New-PxFont([string]$name, [float]$px, [System.Drawing.FontStyle]$style) {
    try {
        return New-Object System.Drawing.Font $name, $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    } catch {
        return New-Object System.Drawing.Font "Georgia", $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    }
}

$brandFont = New-PxFont "Cinzel Black" 42 ([System.Drawing.FontStyle]::Regular)
$titleFont = New-PxFont "Cinzel Black" 84 ([System.Drawing.FontStyle]::Regular)
$subFont = New-PxFont "Segoe UI" 32 ([System.Drawing.FontStyle]::Regular)
$pillFont = New-PxFont "Segoe UI" 26 ([System.Drawing.FontStyle]::Bold)
$badgeFont = New-PxFont "Segoe UI" 24 ([System.Drawing.FontStyle]::Bold)

$goldFill = New-Object System.Drawing.SolidBrush (New-Color 255 232 204 128)
$whiteFill = New-Object System.Drawing.SolidBrush (New-Color 255 248 244 232)
$muteFill = New-Object System.Drawing.SolidBrush (New-Color 255 186 168 128)

$iconPath = "C:\Users\Ultima\Desktop\Taptico\assets\icons\icon_1024.png"
$icon = $null
if (Test-Path $iconPath) {
    $icon = [System.Drawing.Image]::FromFile($iconPath)
}

$i = 0
foreach ($slide in $slides) {
    $ox = $i * $CanvasW
    $canvas = New-Object System.Drawing.Bitmap $CanvasW, $CanvasH
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.PageUnit = [System.Drawing.GraphicsUnit]::Pixel

    Draw-WorldBackdrop $g $ox $CanvasW $CanvasH $TotalW

    if ($icon) {
        $g.DrawImage($icon, 72, 58, 84, 84)
    }
    $g.DrawString("TAPTICO", $brandFont, $goldFill, 172, 76)

    $titleRect = New-Object System.Drawing.RectangleF 80, 168, ($CanvasW - 160), 220
    Draw-GlowText $g $slide.title $titleFont $titleRect $whiteFill 70

    $subRect = New-Object System.Drawing.RectangleF 120, 400, ($CanvasW - 240), 90
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($slide.sub, $subFont, $muteFill, $subRect, $sf)
    $sf.Dispose()

    $pillWidths = @()
    foreach ($p in $slide.pills) {
        $pillWidths += [int]($g.MeasureString($p, $pillFont).Width + 42)
    }
    $gap = 16
    $rowW = ($pillWidths | Measure-Object -Sum).Sum + $gap * ($pillWidths.Count - 1)
    $pillX = [int](($CanvasW - $rowW) / 2)
    $pi = 0
    foreach ($p in $slide.pills) {
        $used = Draw-Pill $g $p $pillFont $pillX 498 ($pi -eq 0)
        $pillX += $used + $gap
        $pi++
    }

    $shot = [System.Drawing.Image]::FromFile((Join-Path $Root $slide.src))
    $phoneW = 1180
    $aspect = $shot.Height / [double]$shot.Width
    $phoneH = [int]($phoneW * $aspect)
    $phoneX = [int](($CanvasW - $phoneW) / 2)
    $phoneY = 590
    if ($phoneY + $phoneH -gt $CanvasH - 70) {
        $phoneH = $CanvasH - 70 - $phoneY
        $phoneW = [int]($phoneH / $aspect)
        $phoneX = [int](($CanvasW - $phoneW) / 2)
    }
    Draw-Phone $g $shot $phoneX $phoneY $phoneW $phoneH
    $shot.Dispose()

    if ($slide.badge) {
        Draw-Badge $g $slide.badge $badgeFont ($CanvasW - 190) 220
    }

    $out = Join-Path $OutDir $slide.file
    $canvas.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("Saved {0} ({1}x{2})" -f $slide.file, $canvas.Width, $canvas.Height)

    $g.Dispose()
    $canvas.Dispose()
    $i++
}

$thumbW = 220
$thumbH = [int]($thumbW * $CanvasH / $CanvasW)
$strip = New-Object System.Drawing.Bitmap ($thumbW * $N), $thumbH
$sg = [System.Drawing.Graphics]::FromImage($strip)
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$j = 0
foreach ($slide in $slides) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $OutDir $slide.file))
    $sg.DrawImage($img, $j * $thumbW, 0, $thumbW, $thumbH)
    $img.Dispose()
    $j++
}
$stripPath = Join-Path $OutDir "_preview-row.png"
$strip.Save($stripPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sg.Dispose()
$strip.Dispose()
Write-Host "Saved _preview-row.png"

if ($icon) { $icon.Dispose() }
$brandFont.Dispose()
$titleFont.Dispose()
$subFont.Dispose()
$pillFont.Dispose()
$badgeFont.Dispose()
$goldFill.Dispose()
$whiteFill.Dispose()
$muteFill.Dispose()
