# 1024x1024 Lifetime IAP promo image + 1080x1920 Shorts/Reels thumbnail.
Add-Type -AssemblyName System.Drawing

$Root = "C:\Users\Ultima\Desktop\Taptico\store"
$IconPath = "C:\Users\Ultima\Desktop\Taptico\assets\icons\icon_1024.png"
$ShotPath = Join-Path $Root "IMG_0027.png"
$IapDir = Join-Path $Root "iap"
$PrevDir = Join-Path $Root "previews"
New-Item -ItemType Directory -Force -Path $IapDir | Out-Null
New-Item -ItemType Directory -Force -Path $PrevDir | Out-Null

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

function New-PxFont([string]$name, [float]$px, [System.Drawing.FontStyle]$style) {
    try {
        return New-Object System.Drawing.Font $name, $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    } catch {
        return New-Object System.Drawing.Font "Georgia", $px, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    }
}

function Draw-WorldBackdrop($g, [int]$W, [int]$H, [int]$seed) {
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        [System.Drawing.Rectangle]::new(-40, 0, $W + 80, $H),
        (New-Color 255 10 9 8),
        (New-Color 255 28 22 16),
        95
    )
    $g.FillRectangle($bg, 0, 0, $W, $H)
    $bg.Dispose()
    $rng = New-Object System.Random $seed
    for ($y = 0; $y -lt $H; $y += 3) {
        $a = 6 + $rng.Next(0, 14)
        $col = if ($rng.Next(0, 3) -eq 0) { New-Color $a 196 158 86 } else { New-Color $a 90 84 76 }
        $pen = New-Object System.Drawing.Pen $col, 1.0
        $g.DrawLine($pen, 0, $y, $W, $y)
        $pen.Dispose()
    }
    $br = New-Object System.Drawing.SolidBrush (New-Color 32 201 162 72)
    $g.FillEllipse($br, [int]($W * -0.18), [int]($H * 0.08), [int]($W * 0.72), [int]($W * 0.72))
    $g.FillEllipse($br, [int]($W * 0.48), [int]($H * 0.55), [int]($W * 0.62), [int]($W * 0.62))
    $br.Dispose()
    $penR = New-Object System.Drawing.Pen (New-Color 55 212 170 78), 6
    $g.DrawEllipse($penR, [int]($W * 0.08), [int]($H * 0.10), [int]($W * 0.84), [int]($W * 0.84))
    $g.DrawEllipse($penR, [int]($W * 0.18), [int]($H * 0.20), [int]($W * 0.64), [int]($W * 0.64))
    $penR.Dispose()
}

function Draw-GlowText($g, [string]$text, $font, $rect, $fill, [int]$glowA) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Near
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

function Draw-Pill($g, [string]$label, $font, [int]$x, [int]$y, [int]$h) {
    $sz = $g.MeasureString($label, $font)
    $pw = [int]($sz.Width + 36)
    $path = New-RoundPath $x $y $pw $h ([int]($h / 2))
    $pen = New-Object System.Drawing.Pen (New-Color 220 201 162 72), 2.4
    $g.DrawPath($pen, $path)
    $pen.Dispose()
    $br = New-Object System.Drawing.SolidBrush (New-Color 255 232 208 140)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($label, $font, $br, (New-Object System.Drawing.RectangleF $x, $y, $pw, $h), $sf)
    $sf.Dispose(); $br.Dispose(); $path.Dispose()
    return $pw
}

# ---- IAP 1024x1024 (opaque PNG, no rounded canvas — Apple rounds it) ----
$W = 1024; $H = 1024
$bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
Draw-WorldBackdrop $g $W $H 7

$icon = [System.Drawing.Image]::FromFile($IconPath)
$iw = 560
$ix = [int](($W - $iw) / 2)
$iy = 168
$rr = New-RoundPath $ix $iy $iw $iw 124
$shadow = New-Object System.Drawing.SolidBrush (New-Color 160 0 0 0)
$g.FillPath($shadow, (New-RoundPath ($ix + 10) ($iy + 18) $iw $iw 124))
$shadow.Dispose()
$goldRing = New-RoundPath ($ix - 8) ($iy - 8) ($iw + 16) ($iw + 16) 132
$goldBr = New-Object System.Drawing.SolidBrush (New-Color 255 186 148 64)
$g.FillPath($goldBr, $goldRing)
$goldBr.Dispose(); $goldRing.Dispose()
$g.SetClip($rr)
$g.DrawImage($icon, $ix, $iy, $iw, $iw)
$g.ResetClip()
$ringPen = New-Object System.Drawing.Pen (New-Color 255 201 162 72), 5
$g.DrawPath($ringPen, $rr)
$ringPen.Dispose(); $rr.Dispose()

$brandFont = New-PxFont "Cinzel Black" 36 ([System.Drawing.FontStyle]::Regular)
$titleFont = New-PxFont "Cinzel Black" 78 ([System.Drawing.FontStyle]::Regular)
$subFont = New-PxFont "Segoe UI" 28 ([System.Drawing.FontStyle]::Regular)
$pillFont = New-PxFont "Segoe UI" 22 ([System.Drawing.FontStyle]::Bold)
$gold = New-Object System.Drawing.SolidBrush (New-Color 255 232 204 128)
$cream = New-Object System.Drawing.SolidBrush (New-Color 255 248 244 232)
$mute = New-Object System.Drawing.SolidBrush (New-Color 255 186 168 128)

$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$g.DrawString("TAPTICO", $brandFont, $gold, (New-Object System.Drawing.RectangleF 40, 48, 944, 50), $sf)
Draw-GlowText $g "LIFETIME" $titleFont (New-Object System.Drawing.RectangleF 40, 748, 944, 90) $cream 90
$g.DrawString("Unlock every fidget. Forever.", $subFont, $mute, (New-Object System.Drawing.RectangleF 40, 838, 944, 40), $sf)

$pills = @("No ads", "One buy", "All toys")
$gap = 14
$widths = @()
foreach ($p in $pills) { $widths += [int]($g.MeasureString($p, $pillFont).Width + 36) }
$row = ($widths | Measure-Object -Sum).Sum + $gap * 2
$px = [int](($W - $row) / 2)
$pi = 0
foreach ($p in $pills) {
    $used = Draw-Pill $g $p $pillFont $px 892 48
    $px += $used + $gap
    $pi++
}

$iapPath = Join-Path $IapDir "lifetime-unlock-1024.png"
$bmp.Save($iapPath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Saved $iapPath"
$g.Dispose(); $bmp.Dispose()

# ---- Thumbnail 1080x1920 ----
$TW = 1080; $TH = 1920
$tb = New-Object System.Drawing.Bitmap $TW, $TH, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$tg = [System.Drawing.Graphics]::FromImage($tb)
$tg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$tg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
Draw-WorldBackdrop $tg $TW $TH 9

$tg.DrawImage($icon, 48, 44, 72, 72)
$tg.DrawString("TAPTICO", (New-PxFont "Cinzel Black" 42 ([System.Drawing.FontStyle]::Regular)), $gold, 136, 58)
Draw-GlowText $tg "REAL HAPTIC`nFIDGETS" (New-PxFont "Cinzel Black" 92 ([System.Drawing.FontStyle]::Regular)) (New-Object System.Drawing.RectangleF 40, 140, 1000, 240) $cream 85
$tg.DrawString("Metal toys. Real iPhone clicks.", (New-PxFont "Segoe UI" 32 ([System.Drawing.FontStyle]::Regular)), $mute, (New-Object System.Drawing.RectangleF 50, 390, 980, 50), $sf)

$shot = [System.Drawing.Image]::FromFile($ShotPath)
$phoneW = 860
$aspect = $shot.Height / [double]$shot.Width
$phoneH = [int]($phoneW * $aspect)
$phoneX = [int](($TW - $phoneW) / 2)
$phoneY = 470
if ($phoneY + $phoneH -gt $TH - 70) {
    $phoneH = $TH - 70 - $phoneY
    $phoneW = [int]($phoneH / $aspect)
    $phoneX = [int](($TW - $phoneW) / 2)
}
$bezel = 22; $radius = 58
$shBr = New-Object System.Drawing.SolidBrush (New-Color 150 0 0 0)
$tg.FillPath($shBr, (New-RoundPath ($phoneX + 16) ($phoneY + 26) $phoneW $phoneH ($radius + 4)))
$shBr.Dispose()
$tg.FillPath((New-Object System.Drawing.SolidBrush (New-Color 255 186 148 64)), (New-RoundPath ($phoneX - 3) ($phoneY - 3) ($phoneW + 6) ($phoneH + 6) ($radius + 4)))
$body = New-RoundPath $phoneX $phoneY $phoneW $phoneH $radius
$tg.FillPath((New-Object System.Drawing.SolidBrush (New-Color 255 16 14 13)), $body)
$sx = $phoneX + $bezel; $sy = $phoneY + $bezel
$sw = $phoneW - 2 * $bezel; $sh = $phoneH - 2 * $bezel
$clip = New-RoundPath $sx $sy $sw $sh ($radius - 16)
$st = $tg.Save()
$tg.SetClip($clip)
$tg.DrawImage($shot, $sx, $sy, $sw, $sh)
$tg.Restore($st)
$island = New-RoundPath ($phoneX + [int](($phoneW - 168) / 2)) ($phoneY + 16) 168 38 19
$tg.FillPath((New-Object System.Drawing.SolidBrush (New-Color 255 6 6 6)), $island)

$thumbPath = Join-Path $PrevDir "Taptico-promo-thumbnail.jpg"
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$enc = New-Object System.Drawing.Imaging.EncoderParameters 1
$enc.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]92)
$tb.Save($thumbPath, $jpegCodec, $enc)
Write-Host "Saved $thumbPath"

$icon.Dispose(); $shot.Dispose()
$tg.Dispose(); $tb.Dispose()
$brandFont.Dispose(); $titleFont.Dispose(); $subFont.Dispose(); $pillFont.Dispose()
$gold.Dispose(); $cream.Dispose(); $mute.Dispose(); $sf.Dispose()
