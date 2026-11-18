# Taptico App Store previews + Reels/Shorts/TikTok promo.
# App Store: 15–30s, H.264 High@L4.0, 30 fps, AAC stereo.
#   iPhone 6.5"/6.9"  = 886 x 1920
#   iPad 13"          = 1200 x 1600
# Social: full-bleed 1080 x 1920 ads + official App Store badge end card.
#   Safe zones: captions below ~180px, CTA above the bottom ~22%.
param([switch]$SkipAppStore)

Add-Type -AssemblyName System.Drawing

$Root = "C:\Users\Ultima\Desktop\Taptico\store"
$OutDir = Join-Path $Root "previews"
$Build = Join-Path $Root "_video-build"
$IconPath = "C:\Users\Ultima\Desktop\Taptico\assets\icons\icon_1024.png"
$BadgePath = Join-Path $Root "assets\app-store-badge-white.png"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path $Build | Out-Null

$V1 = Join-Path $Root "ScreenRecording_08-22-2026 18-45-47_1.mp4"
$V2 = Join-Path $Root "ScreenRecording_08-22-2026 18-46-20_1.mp4"
$V3 = Join-Path $Root "ScreenRecording_08-22-2026 18-46-53_1.mp4"
$V4 = Join-Path $Root "ScreenRecording_08-22-2026 18-47-22_1.mp4"
$V5 = Join-Path $Root "ScreenRecording_08-22-2026 18-47-43_1.mp4"

# Trimmed beats. Total after 0.35s xfades ≈ 25.6s (App Store). Social adds ~4s end card.
$XFade = 0.35
$EndDur = 4.00
$clips = @(
    @{ src = $V1; ss = 0.20; dur = 6.20; title = "REAL HAPTIC`nFIDGETS";      sub = "Metal toys. Real Taptic Engine clicks." }
    @{ src = $V2; ss = 0.15; dur = 4.90; title = "THAT CLICK`nIS REAL.";      sub = "A heavy clicker pen. On your iPhone." }
    @{ src = $V3; ss = 0.12; dur = 6.00; title = "SPIN. CLICK.`nFEEL.";       sub = "Quiet desk fidgets. No ads." }
    @{ src = $V4; ss = 0.25; dur = 5.10; title = "ASMR CLICKS`n& POPS";       sub = "Pop a row. Reset. Do it again." }
    @{ src = $V5; ss = 0.55; dur = 5.00; title = "THREE FREE.`nONE BUY.";     sub = "Get Taptico on the App Store." }
)

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

    $wells = @(
        @{ x = -120; y = 80; s = [int]($W * 0.55) },
        @{ x = [int]($W * 0.55); y = [int]($H * 0.62); s = [int]($W * 0.62) }
    )
    foreach ($well in $wells) {
        $br = New-Object System.Drawing.SolidBrush (New-Color 28 201 162 72)
        $g.FillEllipse($br, $well.x, $well.y, $well.s, $well.s)
        $br.Dispose()
    }

    $penR = New-Object System.Drawing.Pen (New-Color 48 212 170 78), 5
    $g.DrawEllipse($penR, [int]($W * -0.12), [int]($H * 0.18), [int]($W * 0.55), [int]($W * 0.55))
    $g.DrawEllipse($penR, [int]($W * 0.62), [int]($H * 0.58), [int]($W * 0.50), [int]($W * 0.50))
    $penR.Dispose()
}

function Draw-GlowText($g, [string]$text, $font, $rect, $fill, [int]$glowA) {
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Near
    $glow = New-Object System.Drawing.SolidBrush (New-Color $glowA 212 170 78)
    foreach ($ox in @(-2, 2, 0)) {
        foreach ($oy in @(-2, 2, 0)) {
            if ($ox -eq 0 -and $oy -eq 0) { continue }
            $r = New-Object System.Drawing.RectangleF ($rect.X + $ox), ($rect.Y + $oy), $rect.Width, $rect.Height
            $g.DrawString($text, $font, $glow, $r, $sf)
        }
    }
    $glow.Dispose()
    $g.DrawString($text, $font, $fill, $rect, $sf)
    $sf.Dispose()
}

function Get-PhoneLayout([int]$W, [int]$H) {
    $titleH = if ($H -gt 1800) { 390 } else { 300 }
    $bottom = if ($H -gt 1800) { 56 } else { 40 }
    $availH = $H - $titleH - $bottom
    $aspect = 1334.0 / 750.0
    $maxW = $W - 48
    $phoneH = $availH
    $phoneW = [int]($phoneH / $aspect)
    if ($phoneW -gt $maxW) {
        $phoneW = $maxW
        $phoneH = [int]($phoneW * $aspect)
    }
    $phoneX = [int](($W - $phoneW) / 2)
    $phoneY = $titleH
    $bezel = [Math]::Max(10, [int]($phoneW * 0.028))
    $radius = [Math]::Max(28, [int]($phoneW * 0.07))
    return @{
        titleH = $titleH
        phoneX = $phoneX; phoneY = $phoneY; phoneW = $phoneW; phoneH = $phoneH
        bezel = $bezel; radius = $radius
        screenX = $phoneX + $bezel
        screenY = $phoneY + $bezel
        screenW = $phoneW - 2 * $bezel
        screenH = $phoneH - 2 * $bezel
        innerR = [Math]::Max(18, $radius - 12)
    }
}

function Save-ChromePng([string]$path, [int]$W, [int]$H, [string]$title, [string]$sub, [int]$seed, $icon) {
    $lay = Get-PhoneLayout $W $H
    $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    Draw-WorldBackdrop $g $W $H $seed

    $brandFont = New-PxFont "Cinzel Black" ([Math]::Max(22, $W / 28.0)) ([System.Drawing.FontStyle]::Regular)
    $titleFont = New-PxFont "Cinzel Black" ([Math]::Max(44, $W / 16.0)) ([System.Drawing.FontStyle]::Regular)
    $subFont = New-PxFont "Segoe UI" ([Math]::Max(18, $W / 42.0)) ([System.Drawing.FontStyle]::Regular)
    $gold = New-Object System.Drawing.SolidBrush (New-Color 255 232 204 128)
    $white = New-Object System.Drawing.SolidBrush (New-Color 255 248 244 232)
    $mute = New-Object System.Drawing.SolidBrush (New-Color 255 186 168 128)

    if ($icon) { $g.DrawImage($icon, 36, 28, 52, 52) }
    $g.DrawString("TAPTICO", $brandFont, $gold, 98, 36)

    $titleRect = New-Object System.Drawing.RectangleF 24, 92, ($W - 48), 200
    Draw-GlowText $g $title $titleFont $titleRect $white 70
    $subRect = New-Object System.Drawing.RectangleF 40, ($lay.titleH - 78), ($W - 80), 70
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($sub, $subFont, $mute, $subRect, $sf)
    $sf.Dispose()

    $shadow = New-Object System.Drawing.SolidBrush (New-Color 140 0 0 0)
    $sp = New-RoundPath ($lay.phoneX + 14) ($lay.phoneY + 22) $lay.phoneW $lay.phoneH ($lay.radius + 4)
    $g.FillPath($shadow, $sp)
    $shadow.Dispose(); $sp.Dispose()

    $goldPath = New-RoundPath ($lay.phoneX - 3) ($lay.phoneY - 3) ($lay.phoneW + 6) ($lay.phoneH + 6) ($lay.radius + 4)
    $goldBr = New-Object System.Drawing.SolidBrush (New-Color 255 186 148 64)
    $g.FillPath($goldBr, $goldPath)
    $goldBr.Dispose(); $goldPath.Dispose()

    $body = New-RoundPath $lay.phoneX $lay.phoneY $lay.phoneW $lay.phoneH $lay.radius
    $bodyBr = New-Object System.Drawing.SolidBrush (New-Color 255 16 14 13)
    $g.FillPath($bodyBr, $body)
    $bodyBr.Dispose()

    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $hole = New-RoundPath $lay.screenX $lay.screenY $lay.screenW $lay.screenH $lay.innerR
    $clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
    $g.FillPath($clear, $hole)
    $clear.Dispose(); $hole.Dispose()
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $body.Dispose()

    $islandW = [int]($lay.phoneW * 0.17)
    $islandH = [int]($lay.phoneW * 0.038)
    $ix0 = $lay.phoneX + [int](($lay.phoneW - $islandW) / 2)
    $island = New-RoundPath $ix0 ($lay.phoneY + 12) $islandW $islandH ([int]($islandH / 2))
    $ibl = New-Object System.Drawing.SolidBrush (New-Color 255 6 6 6)
    $g.FillPath($ibl, $island)
    $ibl.Dispose(); $island.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    $brandFont.Dispose(); $titleFont.Dispose(); $subFont.Dispose()
    $gold.Dispose(); $white.Dispose(); $mute.Dispose()
    return $lay
}

function Save-SocialCaption([string]$path, [int]$W, [int]$H, [string]$title, [string]$sub, $icon) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)

    # Stay below Shorts/TikTok/Reels top chrome (~180px) and keep the right 96px clear.
    $fade = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
        [System.Drawing.Rectangle]::new(0, 0, $W, 560),
        (New-Color 200 8 7 6),
        (New-Color 0 8 7 6),
        90
    )
    $g.FillRectangle($fade, 0, 0, $W, 560)
    $fade.Dispose()

    $brandFont = New-PxFont "Cinzel Black" 28 ([System.Drawing.FontStyle]::Regular)
    $titleFont = New-PxFont "Cinzel Black" 70 ([System.Drawing.FontStyle]::Regular)
    $subFont = New-PxFont "Segoe UI Semibold" 32 ([System.Drawing.FontStyle]::Regular)
    $gold = New-Object System.Drawing.SolidBrush (New-Color 255 232 204 128)
    $white = New-Object System.Drawing.SolidBrush (New-Color 255 248 244 232)
    $mute = New-Object System.Drawing.SolidBrush (New-Color 255 220 196 140)

    if ($icon) { $g.DrawImage($icon, 40, 188, 44, 44) }
    $g.DrawString("TAPTICO", $brandFont, $gold, 94, 196)

    $titleRect = New-Object System.Drawing.RectangleF 36, 250, ($W - 132), 210
    Draw-GlowText $g $title $titleFont $titleRect $white 80
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($sub, $subFont, $mute, (New-Object System.Drawing.RectangleF 48, 470, ($W - 144), 72), $sf)
    $sf.Dispose()

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    $brandFont.Dispose(); $titleFont.Dispose(); $subFont.Dispose()
    $gold.Dispose(); $white.Dispose(); $mute.Dispose()
}

function Save-EndCard([string]$path, [int]$W, [int]$H, $icon, [string]$badgeFile) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    Draw-WorldBackdrop $g $W $H 11

    $titleFont = New-PxFont "Cinzel Black" 88 ([System.Drawing.FontStyle]::Regular)
    $ctaFont = New-PxFont "Cinzel Black" 46 ([System.Drawing.FontStyle]::Regular)
    $subFont = New-PxFont "Segoe UI Semibold" 34 ([System.Drawing.FontStyle]::Regular)
    $white = New-Object System.Drawing.SolidBrush (New-Color 255 248 244 232)
    $gold = New-Object System.Drawing.SolidBrush (New-Color 255 232 204 128)
    $mute = New-Object System.Drawing.SolidBrush (New-Color 255 186 168 128)

    $iw = 260
    $ix = [int](($W - $iw) / 2)
    $iy = 280
    if ($icon) {
        $rr = New-RoundPath $ix $iy $iw $iw 58
        $g.SetClip($rr)
        $g.DrawImage($icon, $ix, $iy, $iw, $iw)
        $g.ResetClip()
        $pen = New-Object System.Drawing.Pen (New-Color 255 201 162 72), 4
        $g.DrawPath($pen, $rr)
        $pen.Dispose(); $rr.Dispose()
    }

    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    Draw-GlowText $g "TAPTICO" $titleFont (New-Object System.Drawing.RectangleF 40, 570, ($W - 80), 110) $white 80
    $g.DrawString("Metal fidgets. Real haptics.", $subFont, $mute, (New-Object System.Drawing.RectangleF 40, 690, ($W - 80), 50), $sf)
    $g.DrawString("No ads. Three free. One purchase.", $subFont, $mute, (New-Object System.Drawing.RectangleF 40, 744, ($W - 80), 50), $sf)
    Draw-GlowText $g "GET IT ON`nTHE APP STORE" $ctaFont (New-Object System.Drawing.RectangleF 36, 830, ($W - 72), 130) $gold 70
    $sf.Dispose()

    if ($badgeFile -and (Test-Path $badgeFile)) {
        $badge = [System.Drawing.Image]::FromFile($badgeFile)
        $bw = 560
        $bh = [int]([double]$badge.Height * $bw / $badge.Width)
        $bx = [int](($W - $bw) / 2)
        $by = 990
        $g.DrawImage($badge, $bx, $by, $bw, $bh)
        $badge.Dispose()
    }

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    $titleFont.Dispose(); $ctaFont.Dispose(); $subFont.Dispose()
    $white.Dispose(); $gold.Dispose(); $mute.Dispose()
}

function Invoke-FF {
    param([Parameter(Mandatory)][string[]]$FFArgs)
    & ffmpeg -y -hide_banner -loglevel error @FFArgs
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: $($FFArgs -join ' ')" }
}

function FmtN([double]$n) {
    return $n.ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
}

$icon = $null
if (Test-Path $IconPath) { $icon = [System.Drawing.Image]::FromFile($IconPath) }

$iphoneW = 886; $iphoneH = 1920
$ipadW = 1200; $ipadH = 1600
$socW = 1080; $socH = 1920

Write-Host "Drawing overlays..."
$iPhoneLays = New-Object System.Collections.Generic.List[object]
$iPadLays = New-Object System.Collections.Generic.List[object]
for ($i = 0; $i -lt $clips.Count; $i++) {
    $c = $clips[$i]
    if (-not $SkipAppStore) {
        $p1 = Join-Path $Build ("chrome-iphone-{0:d2}.png" -f ($i + 1))
        $p2 = Join-Path $Build ("chrome-ipad-{0:d2}.png" -f ($i + 1))
        [void]$iPhoneLays.Add((Save-ChromePng $p1 $iphoneW $iphoneH $c.title $c.sub (40 + $i) $icon))
        [void]$iPadLays.Add((Save-ChromePng $p2 $ipadW $ipadH $c.title $c.sub (40 + $i) $icon))
    }
    $cap = Join-Path $Build ("caption-social-{0:d2}.png" -f ($i + 1))
    Save-SocialCaption $cap $socW $socH $c.title $c.sub $icon
}
$endPath = Join-Path $Build "endcard-social.png"
Save-EndCard $endPath $socW $socH $icon $BadgePath
if ($icon) { $icon.Dispose() }

function Render-FramedSeg([string]$src, [double]$ss, [double]$dur, [string]$chrome, $lay, [int]$W, [int]$H, [string]$out) {
    $sx = $lay.screenX; $sy = $lay.screenY; $sw = $lay.screenW; $sh = $lay.screenH
    $vf = "fps=30,scale=${sw}:${sh}:flags=lanczos,setsar=1,format=yuv420p,tpad=stop_mode=clone:stop_duration=0.08"
    Invoke-FF @(
        "-ss", (FmtN $ss), "-t", (FmtN $dur), "-i", $src,
        "-loop", "1", "-i", $chrome,
        "-filter_complex", "[0:v]$vf[v];color=c=0x0A0908:s=${W}x${H}:r=30,format=yuv420p[bg];[bg][v]overlay=${sx}:${sy}:shortest=1[base];[1:v]format=rgba[ch];[base][ch]overlay=0:0:shortest=1,format=yuv420p,setsar=1[vout];[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[aout]",
        "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-r", "30", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2",
        "-t", (FmtN $dur),
        $out
    )
}

function Render-SocialSeg([string]$src, [double]$ss, [double]$dur, [string]$cap, [string]$out) {
    $vf = "fps=30,scale=${socW}:${socH}:force_original_aspect_ratio=increase:flags=lanczos,crop=${socW}:${socH},setsar=1,format=yuv420p,tpad=stop_mode=clone:stop_duration=0.08"
    Invoke-FF @(
        "-ss", (FmtN $ss), "-t", (FmtN $dur), "-i", $src,
        "-loop", "1", "-i", $cap,
        "-filter_complex", "[0:v]$vf[v];[1:v]format=rgba[c];[v][c]overlay=0:0:shortest=1,format=yuv420p,setsar=1[vout];[0:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[aout]",
        "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-r", "30", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2",
        "-t", (FmtN $dur),
        $out
    )
}

function Render-EndCardSeg([string]$png, [double]$dur, [string]$out) {
    Invoke-FF @(
        "-loop", "1", "-i", $png, "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo",
        "-filter_complex", "[0:v]fps=30,format=yuv420p,setsar=1[vout]",
        "-map", "[vout]", "-map", "1:a",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "16", "-r", "30", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "192k", "-ar", "44100", "-ac", "2",
        "-t", (FmtN $dur), "-shortest",
        $out
    )
}

function Join-Xfade([string[]]$segs, [double[]]$durs, [double]$fade, [string]$out, [switch]$FadeIO) {
    $ffIn = @()
    foreach ($s in $segs) { $ffIn += "-i"; $ffIn += $s }
    $vchain = "[0:v]"
    $achain = "[0:a]"
    $acc = $durs[0]
    $lastV = "0:v"
    $lastA = "0:a"
    $fc = New-Object System.Collections.Generic.List[string]
    for ($i = 1; $i -lt $segs.Count; $i++) {
        $off = $acc - $fade
        $vn = "v$i"; $an = "a$i"
        $fc.Add("[$lastV][$i`:v]xfade=transition=fade:duration=$(FmtN $fade):offset=$(FmtN $off)[$vn]")
        $fc.Add("[$lastA][$i`:a]acrossfade=d=$(FmtN $fade)[$an]")
        $lastV = $vn; $lastA = $an
        $acc = $acc + $durs[$i] - $fade
    }
    $total = $acc
    $vout = $lastV
    $aout = $lastA
    if ($FadeIO) {
        $st = [Math]::Max(0, $total - 0.55)
        $fc.Add("[${vout}]fade=t=in:d=0.35,fade=t=out:st=${st}:d=0.5,format=yuv420p[vfinal]")
        $fc.Add("[${aout}]afade=t=in:d=0.25,afade=t=out:st=${st}:d=0.5[afinal]")
        $vout = "vfinal"; $aout = "afinal"
    } else {
        $fc.Add("[${vout}]format=yuv420p[vfinal]")
        $fc.Add("[${aout}]anull[afinal]")
        $vout = "vfinal"; $aout = "afinal"
    }
    $filter = ($fc -join ";")
    $ffIn += @(
        "-filter_complex", $filter,
        "-map", "[$vout]", "-map", "[$aout]",
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.0",
        "-pix_fmt", "yuv420p", "-r", "30",
        "-b:v", "11M", "-maxrate", "12M", "-bufsize", "22M",
        "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-ac", "2",
        "-movflags", "+faststart",
        "-t", (FmtN $total),
        $out
    )
    Invoke-FF $ffIn
    return $total
}

if (-not $SkipAppStore) {
    Write-Host "Rendering iPhone segments..."
    $iphoneSegs = @(); $iphoneDurs = @()
    for ($i = 0; $i -lt $clips.Count; $i++) {
        $c = $clips[$i]
        $out = Join-Path $Build ("seg-iphone-{0:d2}.mp4" -f ($i + 1))
        Write-Host "  iPhone $($i+1)"
        Render-FramedSeg $c.src $c.ss $c.dur (Join-Path $Build ("chrome-iphone-{0:d2}.png" -f ($i + 1))) $iPhoneLays[$i] $iphoneW $iphoneH $out
        $iphoneSegs += $out
        $iphoneDurs += $c.dur
    }

    Write-Host "Rendering iPad segments..."
    $ipadSegs = @(); $ipadDurs = @()
    for ($i = 0; $i -lt $clips.Count; $i++) {
        $c = $clips[$i]
        $out = Join-Path $Build ("seg-ipad-{0:d2}.mp4" -f ($i + 1))
        Write-Host "  iPad $($i+1)"
        Render-FramedSeg $c.src $c.ss $c.dur (Join-Path $Build ("chrome-ipad-{0:d2}.png" -f ($i + 1))) $iPadLays[$i] $ipadW $ipadH $out
        $ipadSegs += $out
        $ipadDurs += $c.dur
    }
}

Write-Host "Rendering social segments..."
$socSegs = @(); $socDurs = @()
for ($i = 0; $i -lt $clips.Count; $i++) {
    $c = $clips[$i]
    $out = Join-Path $Build ("seg-social-{0:d2}.mp4" -f ($i + 1))
    Write-Host "  social $($i+1)"
    Render-SocialSeg $c.src $c.ss $c.dur (Join-Path $Build ("caption-social-{0:d2}.png" -f ($i + 1))) $out
    $socSegs += $out
    $socDurs += $c.dur
}
$endSeg = Join-Path $Build "seg-social-end.mp4"
Render-EndCardSeg $endPath $EndDur $endSeg
$socSegs += $endSeg
$socDurs += $EndDur

$tIphone = 0; $tIpad = 0
if (-not $SkipAppStore) {
    Write-Host "Joining iPhone preview..."
    $iphoneOut = Join-Path $OutDir "Taptico-app-preview-iphone-65.mp4"
    $tIphone = Join-Xfade $iphoneSegs $iphoneDurs $XFade $iphoneOut -FadeIO

    Write-Host "Joining iPad preview..."
    $ipadOut = Join-Path $OutDir "Taptico-app-preview-ipad-13.mp4"
    $tIpad = Join-Xfade $ipadSegs $ipadDurs $XFade $ipadOut -FadeIO

    Invoke-FF @("-ss", "5.0", "-i", $iphoneOut, "-frames:v", "1", (Join-Path $OutDir "_poster-iphone.jpg"))
    Invoke-FF @("-ss", "5.0", "-i", $ipadOut, "-frames:v", "1", (Join-Path $OutDir "_poster-ipad.jpg"))
}

Write-Host "Joining social promo..."
$socOut = Join-Path $OutDir "Taptico-promo-reels-shorts-tiktok.mp4"
$tSoc = Join-Xfade $socSegs $socDurs $XFade $socOut -FadeIO

Invoke-FF @("-ss", "1.4", "-i", $socOut, "-frames:v", "1", "-q:v", "3", (Join-Path $OutDir "_poster-social.jpg"))
Invoke-FF @("-ss", (FmtN ([Math]::Max(1, $tSoc - 1.6))), "-i", $socOut, "-frames:v", "1", "-q:v", "3", (Join-Path $OutDir "_poster-social-end.jpg"))
Copy-Item (Join-Path $OutDir "_poster-social.jpg") (Join-Path $OutDir "Taptico-promo-thumbnail.jpg") -Force

Write-Host ""
Write-Host "Done."
Get-ChildItem $OutDir -File | ForEach-Object {
    $p = ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate -show_entries format=duration,size -of default=noprint_wrappers=1 $_.FullName 2>$null
    Write-Host ("{0}`n{1}" -f $_.Name, ($p -join " / "))
}
Write-Host ("iPhone duration {0:n2}s  iPad {1:n2}s  social {2:n2}s" -f $tIphone, $tIpad, $tSoc)
