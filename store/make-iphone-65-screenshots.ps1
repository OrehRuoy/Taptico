# Taptico App Store screenshots — iPhone 6.5" (1284 x 2778).
# Phone-in-frame + shared panoramic gold/metal background, StimPad / Spectrum layout.

Add-Type -AssemblyName System.Drawing

$Root = "C:\Users\Ultima\Desktop\Taptico\store"
$OutDir = Join-Path $Root "iphone-6.5"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$W = 1284
$H = 2778

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
$TotalW = $W * $N

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

function Draw-WorldBackdrop($g, [int]$ox, [int]$W, [int]$H, [int]$totalW) {
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        [System.Drawing.Rectangle]::new(-40, 0, $W + 80, $H),
        (New-Color 255 10 9 8),
        (New-Color 255 28 22 16),
        95
    )
    $g.FillRectangle($bg, 0, 0, $W, $H)
    $bg.Dispose()

    # Brushed metal grain — horizontal lines spanning the whole set.
    $rng = New-Object System.Random 42
    for ($y = 0; $y -lt $H; $y += 3) {
        $a = 6 + ($rng.Next(0, 14))
        $goldish = $rng.Next(0, 3) -eq 0
        $col = if ($goldish) { New-Color $a 196 158 86 } else { New-Color $a 90 84 76 }
        $pen = New-Object System.Drawing.Pen $col, 1.0
        $g.DrawLine($pen, 0, $y, $W, $y)
        $pen.Dispose()
    }

    # Soft gold wells that sit on slide seams so neighbors match.
    $wells = @(
        @{ x = 900; y = 220; s = 720 },
        @{ x = 2100; y = 1600; s = 900 },
        @{ x = 3600; y = 80; s = 640 },
        @{ x = 5200; y = 1900; s = 780 },
        @{ x = 6800; y = 400; s = 860 },
        @{ x = 8200; y = 1400; s = 700 }
    )
    foreach ($well in $wells) {
        $wx = $well.x - $ox
        $wy = $well.y
        if ($wx + $well.s -lt -80 -or $wx -gt $W + 80) { continue }
        $br = New-Object System.Drawing.SolidBrush (New-Color 28 201 162 72)
        $g.FillEllipse($br, $wx, $wy, $well.s, $well.s)
        $br.Dispose()
    }

    # Continuous diagonal gold ribbons.
    $ribbons = @(
        @{ y0 = -200; y1 = $H + 200; thick = 26; a = 55 },
        @{ y0 = 400; y1 = $H + 700; thick = 14; a = 40 },
        @{ y0 = -500; y1 = $H - 100; thick = 40; a = 22 }
    )
    foreach ($rib in $ribbons) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $x0 = 0 - $ox
        $x1 = [int]($totalW * 0.33) - $ox
        $x2 = [int]($totalW * 0.66) - $ox
        $x3 = $totalW - $ox
        $path.AddBezier($x0, $rib.y0, $x1, $rib.y0 + 380, $x2, $rib.y1 - 520, $x3, $rib.y1)
        $pen = New-Object System.Drawing.Pen (New-Color $rib.a 212 170 78), $rib.thick
        $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    }

    # Faint hardware rings (lock / spinner language) that straddle frames.
    $rings = @(
        @{ x = 1180; y = 640; r = 220 },
        @{ x = 2500; y = 2100; r = 180 },
        @{ x = 3900; y = 520; r = 260 },
        @{ x = 6400; y = 2000; r = 200 },
        @{ x = 7800; y = 700; r = 240 }
    )
    foreach ($rg in $rings) {
        $cx = $rg.x - $ox
        if ($cx + $rg.r -lt -20 -or $cx - $rg.r -gt $W + 20) { continue }
        $pen = New-Object System.Drawing.Pen (New-Color 50 212 174 84), 6
        $g.DrawEllipse($pen, $cx - $rg.r, $rg.y - $rg.r, $rg.r * 2, $rg.r * 2)
        $pen.Dispose()
        $pen2 = New-Object System.Drawing.Pen (New-Color 28 212 174 84), 3
        $g.DrawEllipse($pen2, $cx - [int]($rg.r * 0.62), $rg.y - [int]($rg.r * 0.62), [int]($rg.r * 1.24), [int]($rg.r * 1.24))
        $pen2.Dispose()
    }
}

function Draw-GlowText($g, [string]$text, $font, $rect, $fill, [int]$glowA) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Near
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoClip
    $glow = New-Object System.Drawing.SolidBrush (New-Color $glowA 212 170 78)
    foreach ($ox in @(-3, 3, 0)) {
        foreach ($oy in @(-3, 3, 0)) {
            if ($ox -eq 0 -and $oy -eq 0) { continue }
            $r = New-Object System.Drawing.RectangleF ($rect.X + $ox), ($rect.Y + $oy), $rect.Width, $rect.Height
            $g.DrawString($text, $font, $glow, $r, $sf)
        }
    }
    $glow.Dispose()
    $g.DrawString($text, $font, $fill, $rect, $sf)
    $sf.Dispose()
}

function Draw-Pill($g, [string]$label, $font, [int]$x, [int]$y, [bool]$filled) {
    $size = $g.MeasureString($label, $font)
    $pw = [int]($size.Width + 36)
    $ph = 52
    $path = New-RoundPath $x $y $pw $ph 26
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
    $r = 92
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
    $g.DrawString($label, $font, $tb, (New-Object System.Drawing.RectangleF ($cx - $r + 8), ($cy - 28), ($r * 2 - 16), 56), $sf)
    $sf.Dispose()
    $tb.Dispose()
}

function Draw-Phone($g, $shot, [int]$x, [int]$y, [int]$w, [int]$h) {
    $bezel = 22
    $radius = 58
    $shadow = New-Object System.Drawing.SolidBrush (New-Color 140 0 0 0)
    $sp = New-RoundPath ($x + 18) ($y + 28) $w $h ($radius + 4)
    $g.FillPath($shadow, $sp)
    $shadow.Dispose()
    $sp.Dispose()

    $goldPath = New-RoundPath ($x - 3) ($y - 3) ($w + 6) ($h + 6) ($radius + 4)
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
    $innerR = [Math]::Max(28, $radius - 16)
    $clip = New-RoundPath $ix $iy $iw $ih $innerR
    $state = $g.Save()
    $g.SetClip($clip)
    $g.DrawImage($shot, $ix, $iy, $iw, $ih)
    $g.Restore($state)
    $clip.Dispose()
    $body.Dispose()

    $islandW = 168
    $islandH = 38
    $ix0 = $x + [int](($w - $islandW) / 2)
    $iy0 = $y + 18
    $island = New-RoundPath $ix0 $iy0 $islandW $islandH 19
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

$brandFont = New-PxFont "Cinzel Black" 36 ([System.Drawing.FontStyle]::Regular)
$titleFont = New-PxFont "Cinzel Black" 72 ([System.Drawing.FontStyle]::Regular)
$subFont = New-PxFont "Segoe UI" 28 ([System.Drawing.FontStyle]::Regular)
$pillFont = New-PxFont "Segoe UI" 24 ([System.Drawing.FontStyle]::Bold)
$badgeFont = New-PxFont "Segoe UI" 22 ([System.Drawing.FontStyle]::Bold)

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
    $ox = $i * $W
    $canvas = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($canvas)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.PageUnit = [System.Drawing.GraphicsUnit]::Pixel

    Draw-WorldBackdrop $g $ox $W $H $TotalW

    if ($icon) {
        $g.DrawImage($icon, 56, 54, 72, 72)
    }
    $g.DrawString("TAPTICO", $brandFont, $goldFill, 144, 68)

    $titleRect = New-Object System.Drawing.RectangleF 48, 148, ($W - 96), 200
    Draw-GlowText $g $slide.title $titleFont $titleRect $whiteFill 70

    $subRect = New-Object System.Drawing.RectangleF 70, 360, ($W - 140), 80
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($slide.sub, $subFont, $muteFill, $subRect, $sf)
    $sf.Dispose()

    $pillX = 0
    $pillWidths = @()
    foreach ($p in $slide.pills) {
        $pillWidths += [int]($g.MeasureString($p, $pillFont).Width + 36)
    }
    $gap = 14
    $rowW = ($pillWidths | Measure-Object -Sum).Sum + $gap * ($pillWidths.Count - 1)
    $pillX = [int](($W - $rowW) / 2)
    $pi = 0
    foreach ($p in $slide.pills) {
        $used = Draw-Pill $g $p $pillFont $pillX 452 ($pi -eq 0)
        $pillX += $used + $gap
        $pi++
    }

    $shot = [System.Drawing.Image]::FromFile((Join-Path $Root $slide.src))
    $phoneW = 980
    $aspect = $shot.Height / [double]$shot.Width
    $phoneH = [int]($phoneW * $aspect)
    $phoneX = [int](($W - $phoneW) / 2)
    $phoneY = 545
    if ($phoneY + $phoneH -gt $H - 48) {
        $phoneH = $H - 48 - $phoneY
        $phoneW = [int]($phoneH / $aspect)
        $phoneX = [int](($W - $phoneW) / 2)
    }
    Draw-Phone $g $shot $phoneX $phoneY $phoneW $phoneH
    $shot.Dispose()

    if ($slide.badge) {
        Draw-Badge $g $slide.badge $badgeFont ($W - 150) 210
    }

    $out = Join-Path $OutDir $slide.file
    $canvas.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("Saved {0} ({1}x{2})" -f $slide.file, $canvas.Width, $canvas.Height)

    $g.Dispose()
    $canvas.Dispose()
    $i++
}

# Contact strip so the panoramic join is obvious.
$thumbW = 240
$thumbH = [int]($thumbW * $H / $W)
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
