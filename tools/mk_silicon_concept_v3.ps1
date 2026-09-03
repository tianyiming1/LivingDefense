# 硅基生命族 · 概念艺术 v3（粒子特效升级版）— 规格同源 RACE_SILICON.md
# 使用：powershell.exe -NoProfile -ExecutionPolicy Bypass -File 本文件
Add-Type -AssemblyName System.Drawing

$W = 1600; $H = 1120
$out = Join-Path (Split-Path $PSScriptRoot) 'docs\silicon_concept_v3.png'
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

function Hex([string]$h) { [System.Drawing.ColorTranslator]::FromHtml($h) }
function Str($s, $x, $y, $f, $c) { $b = New-Object System.Drawing.SolidBrush($c); $g.DrawString($s, $f, $b, [float]$x, [float]$y); $b.Dispose() }

$yahei_b = New-Object System.Drawing.Font('Microsoft YaHei', 26, [System.Drawing.FontStyle]::Bold)
$yahei   = New-Object System.Drawing.Font('Microsoft YaHei', 15)
$yahei_s = New-Object System.Drawing.Font('Microsoft YaHei', 12)

# 背景渐变
$bgGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $W, $H)), (Hex '#0B0B12'), (Hex '#19202E'), 90.0)
$g.FillRectangle($bgGrad, 0, 0, $W, $H); $bgGrad.Dispose()

Str '硅基生命族 · 概念艺术 v3 — 晶脉流动 × 粒子特效' 40 28 $yahei_b (Hex '#EAF7FA')
Str '主色 #6FD3E7 / 白 #F5F9FF / 线光 #A8E8F5 · 粒子：流动拖尾群 / 悬浮尘埃 / 轨道环 / 拐点火花' 42 70 $yahei_s (Hex '#8AA0AC')

# 背景六边晶格
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

# ---- 三条贝塞尔晶脉 ----
function Vein($x1, $y1, $x2, $y2, $cx1, $cy1, $cx2, $cy2) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddBezier([System.Drawing.PointF]::new($x1, $y1), [System.Drawing.PointF]::new($cx1, $cy1), [System.Drawing.PointF]::new($cx2, $cy2), [System.Drawing.PointF]::new($x2, $y2))
    $pen = New-Object System.Drawing.Pen((Hex '#2E5468'), 6)
    $g.DrawPath($pen, $path); $pen.Dispose()
    $pen = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 2.5)
    $g.DrawPath($pen, $path); $pen.Dispose()
    $path.Dispose()
}
Vein 40 300 1560 260 500 180 1100 380
Vein 40 480 1560 700 400 620 1200 560
Vein 40 660 1560 630 600 760 1050 560

# ---- 粒子系统 1：主脉流动群（沿曲线采样 + 拖尾沿曲线回退）----
$rnd = New-Object System.Random(20260901)
$veinY = @(
    @{ y0 = 300.0; y1 = 260.0; c1y = 180.0; c2y = 380.0 },
    @{ y0 = 480.0; y1 = 700.0; c1y = 620.0; c2y = 560.0 },
    @{ y0 = 660.0; y1 = 630.0; c1y = 760.0; c2y = 560.0 }
)
function FlowX($t) { return 40.0 + $t * 1520.0 }
function FlowY($vy, $t) {
    # 3 阶 Bezier 近似（t 线性近似主曲率即可，视觉足够）
    return $vy.y0 + $t * ($vy.y1 - $vy.y0) + [math]::Sin($t * 6.283) * 60.0
}
$flowCount = 0
foreach ($v in $veinY) {
    for ($i = 0; $i -lt 40; $i++) {
        $t = [double]($i + 0.5) / 40.0
        $t = $t + ($rnd.NextDouble() - 0.5) * 0.02
        $px = FlowX $t
        $py = FlowY $v $t + ($rnd.NextDouble() - 0.5) * 22
        # 拖尾 3 段：沿曲线 t 回退（平滑、不弯折）
        for ($k = 1; $k -le 3; $k++) {
            $tt = $t - $k * 0.016
            if ($tt -lt 0.02) { continue }
            $tx = FlowX $tt
            $ty = FlowY $v $tt
            $a = [int](70 * (1.0 - $k * 0.24))
            $r = 4.0 * (1.0 - $k * 0.2)
            $c = [System.Drawing.Color]::FromArgb($a, 0x8F, 0xE2, 0xF7)
            $b = New-Object System.Drawing.SolidBrush($c)
            $g.FillEllipse($b, $tx - $r, $ty - $r, $r * 2, $r * 2); $b.Dispose()
        }
        # 主点
        $c = [System.Drawing.Color]::FromArgb(190, 0xCF, 0xF0, 0xFA)
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillEllipse($b, $px - 4.5, $py - 4.5, 9, 9); $b.Dispose()
        $flowCount++
    }
}
# 星芒高亮（每脉随机挑 3 个亮粒加十字）
for ($m = 0; $m -lt 9; $m++) {
    $t = $rnd.NextDouble()
    $v = $veinY[$m % 3]
    $px = FlowX $t; $py = FlowY $v $t
    $p = New-Object System.Drawing.Pen((Hex '#EAF7FA'), 1.5)
    $g.DrawLine($p, $px - 7, $py, $px + 7, $py)
    $g.DrawLine($p, $px, $py - 7, $px, $py + 7)
    $p.Dispose()
}

# ---- 粒子系统 2：悬浮尘埃（全场缓慢上浮，短竖尾）----
for ($i = 0; $i -lt 60; $i++) {
    $ex = $rnd.Next(40, 1560)
    $ey = $rnd.Next(300, 700)
    $r = 1.5 + $rnd.Next(2)
    $a = 16 + $rnd.Next(26)
    $c = [System.Drawing.Color]::FromArgb($a, 0x9A, 0xD8, 0xEA)
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillEllipse($b, $ex - $r, $ey - $r, $r * 2, $r * 2); $b.Dispose()
    # 上浮短尾 2 段
    $c2 = [System.Drawing.Color]::FromArgb([int]($a * 0.5), 0x9A, 0xD8, 0xEA)
    $b = New-Object System.Drawing.SolidBrush($c2)
    $g.FillEllipse($b, $ex - $r * 0.8, $ey - 8 - $r * 0.8, $r * 1.6, $r * 1.6); $b.Dispose()
    $c3 = [System.Drawing.Color]::FromArgb([int]($a * 0.22), 0x9A, 0xD8, 0xEA)
    $b = New-Object System.Drawing.SolidBrush($c3)
    $g.FillEllipse($b, $ex - $r * 0.6, $ey - 16 - $r * 0.6, $r * 1.2, $r * 1.2); $b.Dispose()
}

# ---- 粒子系统 3a：拐点火花（贝塞尔控制点附近的放射短线）----
$spark = @(@(500, 180), @(1100, 380), @(400, 620), @(1200, 560), @(600, 760))
foreach ($sp in $spark) {
    $rot = $rnd.NextDouble() * 6.283
    for ($i = 0; $i -lt 6; $i++) {
        $a = $rot + $i * 1.047
        $len = 8 + $rnd.Next(11)
        $x1 = $sp[0] + [math]::Cos($a) * 6; $y1 = $sp[1] + [math]::Sin($a) * 6
        $x2 = $sp[0] + [math]::Cos($a) * $len; $y2 = $sp[1] + [math]::Sin($a) * $len
        $p = New-Object System.Drawing.Pen((Hex '#A8E8F5'), 1.4)
        $g.DrawLine($p, $x1, $y1, $x2, $y2); $p.Dispose()
    }
}

# ---- 发光工具（两层递减 alpha 辉光）----
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

# ---- 粒子系统 3b：单位轨道环绕粒子（枢纽 8 / 晶核 8 / 晶壁 6）----
function Orbit($cx, $cy, $R, $n, $phase, $alpha, $colR, $colG, $colB) {
    for ($i = 0; $i -lt $n; $i++) {
        $a = $phase + $i * 6.283 / $n
        $x = $cx + [math]::Cos($a) * $R
        $y = $cy + [math]::Sin($a) * $R
        # 拖尾 = 后退 0.4 rad
        $a2 = $a - 0.4
        for ($k = 1; $k -le 2; $k++) {
            $aa = $a - $k * 0.35
            $tx = $cx + [math]::Cos($aa) * ($R - $k * 2)
            $ty = $cy + [math]::Sin($aa) * ($R - $k * 2)
            $c = [System.Drawing.Color]::FromArgb([int]($alpha * 0.4 / $k), $colR, $colG, $colB)
            $b = New-Object System.Drawing.SolidBrush($c)
            $g.FillEllipse($b, $tx - 2.5, $ty - 2.5, 5, 5); $b.Dispose()
        }
        $c = [System.Drawing.Color]::FromArgb($alpha, $colR, $colG, $colB)
        $b = New-Object System.Drawing.SolidBrush($c)
        $g.FillEllipse($b, $x - 3.2, $y - 3.2, 6.4, 6.4); $b.Dispose()
        $a2 = $null
    }
}

# 1) 晶脉枢纽（菱形 + 扩散亮线 + 轨道 8）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((340 + 66 * [math]::Cos($a)), (430 + 66 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#6FD3E7') (Hex '#EAF7FA') 340 430 130 16
$p = New-Object System.Drawing.Pen((Hex '#A8E8F5'), 2)
foreach ($dir in @(@(-70,0), @(70,0), @(0,-70), @(0,70))) { $g.DrawLine($p, 340, 430, 340 + $dir[0], 430 + $dir[1]) }
$p.Dispose()
Orbit 340 430 96 8 0.0 110 0x8F 0xE2 0xF7
Str '晶脉枢纽（部署起点·轨道粒子环）' 200 560 $yahei_s (Hex '#C8E8F2')

# 2) 硅晶核（六边形·满能态 白芯+金环+金闪轨道 4）
$hex = @()
for ($k = 0; $k -lt 6; $k++) { $a = [math]::PI / 3.0 * $k; $hex += [System.Drawing.PointF]::new((700 + 52 * [math]::Cos($a)), (330 + 52 * [math]::Sin($a))) }
HexGlowPoly $hex (Hex '#7BD8EC') (Hex '#EAF7FA') 700 330 110 22
$p = New-Object System.Drawing.Pen((Hex '#FFE89C'), 4)
$g.DrawArc($p, 700 - 66, 330 - 66, 132, 132, -60, 300); $p.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#FFFDE9'))
$g.FillEllipse($b, 688, 318, 24, 24); $b.Dispose()
Orbit 700 330 82 4 0.5 150 0xFF 0xE8 0x9C
Str '硅晶核（满能强击·金闪轨道粒子=充能完成）' 560 420 $yahei_s (Hex '#C8E8F2')

# 3) 硅晶刺（菱形对空·上挑亮线 + 光点尾）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((1090 + 40 * [math]::Cos($a)), (330 + 26 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#5FBCCF') (Hex '#DDF4FA') 1090 330 80 14
$p = New-Object System.Drawing.Pen((Hex '#A8E8F5'), 3)
$g.DrawLine($p, 1090, 302, 1104, 236); $p.Dispose()
for ($tt = 0; $tt -lt 3; $tt++) {
    $c = [System.Drawing.Color]::FromArgb(60 + $tt * 40, 0xF5, 0xF9, 0xFF)
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillEllipse($b, 1104 - $tt * 8, 236 + $tt * 6, 8, 8); $b.Dispose()
}
Str '硅晶刺（对空·发射光点拖尾）' 950 420 $yahei_s (Hex '#C8E8F2')

# 4) 硅晶壁（宽菱形·中央白缝 + 轨道 6）
$pts = @()
foreach ($k in 0..3) { $a = [math]::PI / 2.0 * $k + [math]::PI / 4.0; $pts += [System.Drawing.PointF]::new((580 + 70 * [math]::Cos($a)), (620 + 84 * [math]::Sin($a))) }
HexGlowPoly $pts (Hex '#4FAFC4') (Hex '#EAF7FA') 580 620 105 18
$p = New-Object System.Drawing.Pen((Hex '#F5F9FF'), 3)
$g.DrawLine($p, 580, 520, 580, 610); $p.Dispose()
Orbit 580 620 100 6 1.2 95 0x8F 0xE2 0xF7
Str '硅晶壁（碎裂 10s 再凝=中央白缝·防御轨道环）' 700 660 $yahei_s (Hex '#C8E8F2')

# ---- 下部：反馈 + 色板 + 引擎实现 ----
$line2 = New-Object System.Drawing.Pen((Hex '#2A3A4A'), 1)
$g.DrawLine($line2, 40, 740, 1560, 740); $line2.Dispose()

Str '反馈语义（引擎等价实现见底部公式）' 40 762 $yahei (Hex '#EAF7FA')
$b = New-Object System.Drawing.SolidBrush((Hex '#2E5468'))
$g.FillEllipse($b, 70, 800, 60, 60); $b.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 2)
$g.DrawArc($p, 62, 792, 76, 76, -90, 220); $p.Dispose()
Str '蓄能中（脉动弧·呼吸）' 150 820 $yahei_s (Hex '#9AC4D6')
$b = New-Object System.Drawing.SolidBrush((Hex '#8F8FA8'))
$g.FillEllipse($b, 420, 800, 60, 60); $b.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 5)
$g.DrawEllipse($p, 408, 788, 84, 84); $p.Dispose()
Str '冻结/减速=冰圈（四族通用）' 510 820 $yahei_s (Hex '#9AC4D6')
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 3)
$g.DrawLine($p, 940, 830, 1120, 830); $p.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#F5F9FF'), 1)
$g.DrawLine($p, 940, 830, 1120, 830); $p.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#6FD3E7'))
$g.FillEllipse($b, 928, 822, 16, 16); $b.Dispose()
$b = New-Object System.Drawing.SolidBrush((Hex '#F5F9FF'))
$g.FillEllipse($b, 1112, 822, 16, 16); $b.Dispose()
Str '晶脉连线=青 3px + 白 1px 叠线' 1150 820 $yahei_s (Hex '#9AC4D6')

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

Str '引擎等价：辉光=4 层递减 alpha 圆；晶脉叠线 DrawLine；粒子=单位 _process 自绘 3 点拖尾(每帧擦旧)；轨道粒子=每帧绕圆心转 0.35rad；火花=6 放射短线；全部 draw_* 无外部资产（ART_GUIDE §1）' 40 1064 $yahei_s (Hex '#6E8290')

$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved: $out | flow particles=$flowCount + dust=60 + sparks=5x6 + orbit=18"
