# 硅基生命族 · 概念艺术 v2（程序化晶脉流动）— 与 RACE_SILICON.md 规格同源
# 使用：powershell.exe -NoProfile -ExecutionPolicy Bypass -File 本文件
Add-Type -AssemblyName System.Drawing

$W = 1600; $H = 1120
$out = Join-Path (Split-Path $PSScriptRoot) 'docs\silicon_concept_v2.png'
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

function Hex([string]$h) { [System.Drawing.ColorTranslator]::FromHtml($h) }
function Str($s, $x, $y, $f, $c) { $b = New-Object System.Drawing.SolidBrush($c); $g.DrawString($s, $f, $b, [float]$x, [float]$y); $b.Dispose() }

$yahei_b = New-Object System.Drawing.Font('Microsoft YaHei', 26, [System.Drawing.FontStyle]::Bold)
$yahei   = New-Object System.Drawing.Font('Microsoft YaHei', 15)
$yahei_s = New-Object System.Drawing.Font('Microsoft YaHei', 12)

# 背景竖向渐变 深空
$bgGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(0, 0, $W, $H)),
    (Hex '#0B0B12'), (Hex '#19202E'), 90.0)
$g.FillRectangle($bgGrad, 0, 0, $W, $H); $bgGrad.Dispose()

Str '硅基生命族 · 概念艺术 v2 — 晶脉流动（Crystal Vein Flow）' 40 28 $yahei_b (Hex '#EAF7FA')
Str '规格同源：RACE_SILICON.md v1.0 · 主色 #6FD3E7 / 辅白 #F5F9FF / 线光 #A8E8F5 · 引擎 draw_* 可复现' 42 70 $yahei_s (Hex '#8AA0AC')

# ---- 背景六边晶格网格（淡）----
$gridPen = New-Object System.Drawing.Pen((Hex '#22313E'), 1)
for ($row = 0; $row -lt 9; $row++) {
    $gy = 120 + $row * 74
    for ($col = 0; $col -lt 11; $col++) {
        $gx = 60 + $col * 150 + (($row % 2) * 75)
        $pts = @()
        for ($k = 0; $k -lt 6; $k++) {
            $a = [math]::PI / 3.0 * $k + [math]::PI / 6.0
            $pts += [System.Drawing.PointF]::new(($gx + 42 * [math]::Cos($a)), ($gy + 42 * [math]::Sin($a)))
        }
        $g.DrawPolygon($gridPen, [System.Drawing.PointF[]]$pts)
    }
}
$gridPen.Dispose()

# ---- 晶脉贝塞尔主脉（三条流动）----
function Vein($x1, $y1, $x2, $y2, $cx1, $cy1, $cx2, $cy2) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p0 = [System.Drawing.PointF]::new($x1, $y1)
    $p1 = [System.Drawing.PointF]::new($cx1, $cy1)
    $p2 = [System.Drawing.PointF]::new($cx2, $cy2)
    $p3 = [System.Drawing.PointF]::new($x2, $y2)
    $path.AddBezier($p0, $p1, $p2, $p3)
    $pen = New-Object System.Drawing.Pen((Hex '#2E5468'), 6)
    $g.DrawPath($pen, $path); $pen.Dispose()
    $pen = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 2.5)
    $g.DrawPath($pen, $path); $pen.Dispose()
    $path.Dispose()
    return @([System.Drawing.PointF]::new($x1, $y1), [System.Drawing.PointF]::new($x2, $y2))
}
Vein 40 300 1560 260 500 180 1100 380
Vein 40 480 1560 700 400 620 1200 560
Vein 40 660 1560 630 600 760 1050 560

# ---- 流动光点粒子（沿脉采样 + 拖尾）----
$rnd = New-Object System.Random(20260901)
for ($i = 0; $i -lt 46; $i++) {
    $t = $rnd.NextDouble()
    # 用第二条主脉的贝塞尔近似点 + 抖动
    $px = 40 + $t * 1520
    $py = 480 + [math]::Sin($t * 6.283) * 60 + ($rnd.NextDouble() - 0.5) * 30
    $alpha = 40 + [int](60 * $rnd.NextDouble())
    $r = 2 + $rnd.Next(3)
    $c = [System.Drawing.Color]::FromArgb($alpha, 0x8F, 0xE2, 0xF7)
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillEllipse($b, $px - $r, $py - $r, $r * 2, $r * 2); $b.Dispose()
}

# ---- 发光小工具：两层递减 alpha 辉光 + 白芯 ----
function Glow($x, $y, $base, $core) {
    $layers = @(@(90, 10), @(62, 18), @(40, 30), @(26, 55))
    foreach ($L in $layers) {
        $c = [System.Drawing.Color]::FromArgb($L[1], $base.R, $base.G, $base.B)
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillEllipse($b, $x - $L[0], $y - $L[0], $L[0] * 2, $L[0] * 2); $b.Dispose()
    }
    $b = New-Object System.Drawing.SolidBrush($core)
    $g.FillEllipse($b, $x - 14, $y - 14, 28, 28); $b.Dispose()
}
function HexGlowPoly($pts, $fill, $line, $glowX, $glowY, $glowR, $glowA) {
    foreach ($rr in @($glowR, $glowR * 0.62)) {
        $c = [System.Drawing.Color]::FromArgb($glowA, $fill.R, $fill.G, $fill.B)
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillEllipse($b, $glowX - $rr, $glowY - $rr, $rr * 2, $rr * 2); $b.Dispose()
    }
    $b = New-Object System.Drawing.SolidBrush($fill)
    $g.FillPolygon($b, [System.Drawing.PointF[]]$pts); $b.Dispose()
    $p = New-Object System.Drawing.Pen($line, 2.5)
    $g.DrawPolygon($p, [System.Drawing.PointF[]]$pts); $p.Dispose()
}
function MakeHex($cx, $cy, $r) {
    $pts = @()
    for ($k = 0; $k -lt 6; $k++) {
        $a = [math]::PI / 3.0 * $k
        $pts += [System.Drawing.PointF]::new(($cx + $r * [math]::Cos($a)), ($cy + $r * [math]::Sin($a)))
    }
    return $pts
}

# 四个硅基单位剪影（规格同源）：
# 1) 晶脉枢纽（大菱形 + 扩散亮线）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((340 + 66 * [math]::Cos($a)), (430 + 66 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#6FD3E7') (Hex '#EAF7FA') 340 430 130 16
$p = New-Object System.Drawing.Pen((Hex '#A8E8F5'), 2)
foreach ($dir in @(@(-70,0), @(70,0), @(0,-70), @(0,70))) { $g.DrawLine($p, 340, 430, 340 + $dir[0], 430 + $dir[1]) }
$p.Dispose()
Str '晶脉枢纽（部署起点·不可移动）' 240 540 $yahei_s (Hex '#C8E8F2')

# 2) 硅晶核（六边形·满能强击态=白芯+金外环）
$hex = MakeHex 700 330 52
HexGlowPoly $hex (Hex '#7BD8EC') (Hex '#EAF7FA') 700 330 110 22
$p = New-Object System.Drawing.Pen((Hex '#FFE89C'), 4)
$g.DrawArc($p, 700 - 66, 330 - 66, 132, 132, -60, 300); $p.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#FFFDE9'))
$g.FillEllipse($b, 688, 318, 24, 24); $b.Dispose()
Str '硅晶核（站定蓄能 3s → 满能强击 白芯·金环=满能态）' 560 420 $yahei_s (Hex '#C8E8F2')

# 3) 硅晶刺（菱形对空·上挑亮线）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((1090 + 40 * [math]::Cos($a)), (330 + 26 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#5FBCCF') (Hex '#DDF4FA') 1090 330 80 14
$p = New-Object System.Drawing.Pen((Hex '#A8E8F5'), 3)
$g.DrawLine($p, 1090, 302, 1104, 236); $p.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#F5F9FF'))
$g.FillEllipse($b, 1100, 232, 10, 10); $b.Dispose()
Str '硅晶刺（对空·蓄能上挑光点）' 950 420 $yahei_s (Hex '#C8E8F2')

# 4) 硅晶壁（宽六边形·站定硬化 中央白缝=碎裂再凝标记）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((580 + 70 * [math]::Cos($a)), (620 + 84 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#4FAFC4') (Hex '#EAF7FA') 580 620 105 18
$p = New-Object System.Drawing.Pen((Hex '#F5F9FF'), 3)
$g.DrawLine($p, 580, 520, 580, 610); $p.Dispose()
Str '硅晶壁（站定硬度+50%·碎裂 10s 再凝=中央白缝）' 700 660 $yahei_s (Hex '#C8E8F2')

# ---- 下部：反馈语义 + 色板 + 引擎实现公式 ----
$line2 = New-Object System.Drawing.Pen((Hex '#2A3A4A'), 1)
$g.DrawLine($line2, 40, 740, 1560, 740); $line2.Dispose()

Str '反馈语义（引擎可复现＝两层递减 alpha 辉光 / DrawLine 连线条）' 40 762 $yahei (Hex '#EAF7FA')
# 蓄能中：淡外环（呼吸感）
$b = New-Object System.Drawing.SolidBrush((Hex '#2E5468'))
$g.FillEllipse($b, 70, 800, 60, 60); $b.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 2)
$g.DrawArc($p, 62, 792, 76, 76, -90, 220); $p.Dispose()
Str '蓄能中（脉动弧·呼吸）' 150 820 $yahei_s (Hex '#9AC4D6')
# 减速冰圈（四族通用反馈）
$b = New-Object System.Drawing.SolidBrush((Hex '#8F8FA8'))
$g.FillEllipse($b, 420, 800, 60, 60); $b.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 5)
$g.DrawEllipse($p, 408, 788, 84, 84); $p.Dispose()
Str '冻结/减速=冰圈（四族通用）' 510 820 $yahei_s (Hex '#9AC4D6')
# 晶脉连接线（单位之间）
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 3)
$g.DrawLine($p, 940, 830, 1120, 830); $p.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#F5F9FF'), 1)
$g.DrawLine($p, 940, 830, 1120, 830); $p.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#6FD3E7'))
$g.FillEllipse($b, 928, 822, 16, 16); $b.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#F5F9FF'))
$g.FillEllipse($b, 1112, 822, 16, 16); $b.Dispose()
Str '晶脉连线=青 3px + 白 1px 叠线（可见连接段）' 1150 820 $yahei_s (Hex '#9AC4D6')

# 色板条（精确值）
Str '精确色板（可直接输入 config.gd / unit.gd）' 40 920 $yahei (Hex '#EAF7FA')
$swatch = @(@('#6FD3E7', '主色 晶脉青'), @('#F5F9FF', '辅色 晶体白'), @('#A8E8F5', '线光 亮青'), @('#4FAFC4', '晶壁 深青'), @('#5FBCCF', '晶刺 中青'), @('#FFE89C', '满能 金环'))
$xS = 60
foreach ($s in $swatch) {
    $b = New-Object System.Drawing.SolidBrush((Hex $s[0]))
    $g.FillRectangle($b, $xS, 962, 110, 52); $b.Dispose()
    $p = New-Object System.Drawing.Pen((Hex '#3A4A5A'), 1)
    $g.DrawRectangle($p, $xS, 962, 110, 52); $p.Dispose()
    Str ($s[1]) $xS 1024 $yahei_s (Hex '#8AA0AC')
    $xS += 130
}

# 引擎实现公式（小字说明）
Str '引擎等价实现：Glow(单位)=4 层 alpha 10/18/30/55 同心圆递缩；晶脉=单位间 DrawLine 青 3px+白 1px；满能=白芯+金色 DrawArc; 全部 draw_* 无外部资产（ART_GUIDE §1 预算）' 40 1064 $yahei_s (Hex '#6E8290')

$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved: $out"

