# 美术样本图生成器 v1（几何剪影 x 色板概念板，与 unit.gd/enemy.gd 画法同源）
# 用法：pwsh tools/mk_art_sample.ps1
Add-Type -AssemblyName System.Drawing

$W = 1600; $H = 1120
$out = Join-Path $PSScriptRoot '..\docs\art_samples_v1.png'
$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(28, 28, 36))

$yahei_b = New-Object System.Drawing.Font('Microsoft YaHei', 24, [System.Drawing.FontStyle]::Bold)
$yahei   = New-Object System.Drawing.Font('Microsoft YaHei', 15)
$yahei_s = New-Object System.Drawing.Font('Microsoft YaHei', 12)

function Hex([string]$hex) { return [System.Drawing.ColorTranslator]::FromHtml($hex) }
function FillPoly($pts, $color) {
    $arr = [System.Drawing.Point[]]$pts
    $br = New-Object System.Drawing.SolidBrush($color)
    $g.FillPolygon($br, $arr)
    $br.Dispose()
}
function Str($s, $x, $y, $font, $color) {
    $br = New-Object System.Drawing.SolidBrush($color)
    $g.DrawString($s, $font, $br, [float]$x, [float]$y)
    $br.Dispose()
}

# 标题
Str 'TowerDefense Proto - 美术样本 v1（几何剪影 x 色板，四族敌我可辨）' 40 28 $yahei_b (Hex '#E8E8F0')
Str '验收口径：主色精确值可截图比对 | 剪影同屏可辨识 | 敌我色差 >= 40 亮度单位（ART_GUIDE.md §1-§2）' 42 66 $yahei_s (Hex '#9A9AA8')

# ---- 四张种族卡 ----
$cards = @(
    @{ name='人族 HUMAN'; c1='#6B82B8'; c2='#4D6AA8'; shape='rect';   mark='段星 1-3(黄) + 牧师白亮环' },
    @{ name='龙族 DRAGON'; c1='#D8572A'; c2='#E8A13C'; shape='dragon'; mark='尖三角翼形(精英 14-16) + 翼纹' },
    @{ name='硅基族 SILICON'; c1='#6FD3E7'; c2='#F5F9FF'; shape='hex'; mark='晶脉亮线 + 蓄能发光 + 碎裂再凝' },
    @{ name='菌族 FUNGUS'; c1='#8A5CBF'; c2='#6FBF4A'; shape='mush'; mark='菌毯染色 + 传染紫 + 孢子闪爆' }
)
$cx = @(220, 620, 1020, 1420)
foreach ($i in 0..3) {
    $card = $cards[$i]; $x0 = $cx[$i] - 180; $y0 = 110
    # 卡框
    $framePen = New-Object System.Drawing.Pen((Hex '#3A3A48'), 2)
    $g.DrawRectangle($framePen, $x0, $y0, 360, 480)
    $framePen.Dispose()
    Str $card.name ($x0 + 18) ($y0 + 20) $yahei_b (Hex '#FFFFFF')
    Str ("主 " + $card.c1 + "  辅 " + $card.c2) ($x0 + 18) ($y0 + 54) $yahei_s (Hex '#B0B0C0')
    $cy = $y0 + 250
    $mid = $x0 + 180
    switch ($card.shape) {
        'rect' {
            $r = [System.Drawing.Rectangle]::new($mid - 28, $cy - 36, 56, 72)
            $br = New-Object System.Drawing.SolidBrush((Hex $card.c1))
            $g.FillRectangle($br, $r); $br.Dispose()
            $p = New-Object System.Drawing.Pen((Hex '#2A2A36'), 3)
            $g.DrawRectangle($p, $r); $p.Dispose()
            for ($s2 = 0; $s2 -lt 3; $s2++) {
                $br = New-Object System.Drawing.SolidBrush((Hex '#FFE89C'))
                $g.FillEllipse($br, $mid - 15 + $s2 * 11, $cy - 46, 7, 7); $br.Dispose()
            }
        }
        'dragon' {
            FillPoly @([System.Drawing.Point]::new($mid, $cy - 58), [System.Drawing.Point]::new($mid + 36, $cy + 30), [System.Drawing.Point]::new($mid, $cy + 8), [System.Drawing.Point]::new($mid - 36, $cy + 30)) (Hex $card.c1)
            $p = New-Object System.Drawing.Pen((Hex $card.c2), 3)
            $g.DrawLine($p, $mid, $cy + 14, $mid, $cy + 14)   # 翼纹中心轴占位
            $g.DrawLine($p, $mid - 20, $cy - 20, $mid + 20, $cy - 20)
            $p.Dispose()
        }
        'hex' {
            $pts = @()
            for ($k = 0; $k -lt 6; $k++) {
                $ang = [math]::PI / 3.0 * $k
                $pts += [System.Drawing.Point]::new($mid + [int](48 * [math]::Cos($ang)), $cy + [int](48 * [math]::Sin($ang)))
            }
            FillPoly $pts (Hex $card.c1)
            $p = New-Object System.Drawing.Pen((Hex '#F5F9FF'), 2)
            $g.DrawLine($p, $mid - 48, $cy, $mid + 48, $cy)
            $p.Dispose()
        }
        'mush' {
            $br = New-Object System.Drawing.SolidBrush((Hex $card.c1))
            $g.FillEllipse($br, $mid - 46, $cy - 30, 92, 60); $br.Dispose()
            $br = New-Object System.Drawing.SolidBrush((Hex '#B8A98F'))
            $g.FillRectangle($br, $mid - 10, $cy + 20, 20, 34); $br.Dispose()
            $br = New-Object System.Drawing.SolidBrush((Hex '#FFFFFF'))
            foreach ($sp in @(-24, 0, 22)) { $g.FillEllipse($br, $mid + $sp, $cy - 16, 8, 8) }
            $br.Dispose()
        }
    }
    # 特征标记文字 + 色板条
    Str ("特征: " + $card.mark) ($x0 + 18) ($y0 + 330) $yahei_s (Hex '#C8C8D4')
    $br1 = New-Object System.Drawing.SolidBrush((Hex $card.c1))
    $g.FillRectangle($br1, $x0 + 18, $y0 + 370, 150, 46); $br1.Dispose()
    $br2 = New-Object System.Drawing.SolidBrush((Hex $card.c2))
    $g.FillRectangle($br2, $x0 + 192, $y0 + 370, 120, 46); $br2.Dispose()
    Str ('剪影参考半径: ' + $(switch ($card.shape) { 'dragon' { '14-16' } 'mush' { '9-11' } 'hex' { '10-14' } default { '11-12' } })) ($x0 + 18) ($y0 + 432) $yahei_s (Hex '#8A8A98')
}

# ---- 敌兵色板行 ----
Str '敌方色板（与四族主色全错开）' 40 640 $yahei (Hex '#E8E8F0')
$enemies = @(@{ n='Grunt'; c='#BF4A2F'; r=24 }, @{ n='Runner'; c='#3A8FC6'; r=24 }, @{ n='Tank'; c='#6E5A73'; r=24 })
$ex = 60
foreach ($e in $enemies) {
    $br = New-Object System.Drawing.SolidBrush((Hex $e.c))
    $g.FillEllipse($br, $ex, 690, 48, 48); $br.Dispose()
    $p = New-Object System.Drawing.Pen((Hex '#000000'), 2)
    $g.DrawEllipse($p, $ex, 690, 48, 48); $p.Dispose()
    Str $e.n ($ex + 8) 748 $yahei (Hex '#FFFFFF')
    $ex += 130
}
Str 'BOSS(M2+): 半径 24+ / 身周暗环 3 层' ($ex + 10) 640 $yahei (Hex '#E8E8F0')

# ---- 反馈语言行 ----
Str '反馈语义（每事件一个可见反馈）' 40 810 $yahei (Hex '#E8E8F0')
# 受击闪白
$br = New-Object System.Drawing.SolidBrush((Hex '#6B82B8'))
$g.FillEllipse($br, 60, 850, 44, 44); $br.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#FFFFFF'), 4)
$g.DrawEllipse($p, 54, 844, 56, 56); $p.Dispose()
Str '受击闪白 0.15s' 130 862 $yahei_s (Hex '#C8C8D4')
# 减速冰圈
$br = New-Object System.Drawing.SolidBrush((Hex '#BF4A2F'))
$g.FillEllipse($br, 330, 850, 44, 44); $br.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#6FD3E7'), 4)
$g.DrawEllipse($p, 320, 840, 64, 64); $p.Dispose()
Str '减速 = 冰圈' 400 862 $yahei_s (Hex '#C8C8D4')
# 攻速光环
$br = New-Object System.Drawing.SolidBrush((Hex '#6B82B8'))
$g.FillEllipse($br, 590, 850, 44, 44); $br.Dispose()
$p = New-Object System.Drawing.Pen((Hex '#FFE89C'), 4)
$g.DrawEllipse($p, 576, 836, 72, 72); $p.Dispose()
Str '攻速 buff = 金色加速环' 664 862 $yahei_s (Hex '#C8C8D4')
# 血条
Str '血条统一（同类唯一差异 = 长度）' 940 810 $yahei (Hex '#E8E8F0')
$br = New-Object System.Drawing.SolidBrush((Hex '#22222C'))
$g.FillRectangle($br, 940, 850, 200, 16); $br.Dispose()
$br = New-Object System.Drawing.SolidBrush((Hex '#E8A13C'))
$g.FillRectangle($br, 940, 850, 140, 16); $br.Dispose()
Str '己方金' 1160 848 $yahei_s (Hex '#C8C8D4')
$br = New-Object System.Drawing.SolidBrush((Hex '#22222C'))
$g.FillRectangle($br, 940, 882, 200, 16); $br.Dispose()
$br = New-Object System.Drawing.SolidBrush((Hex '#40C95C'))
$g.FillRectangle($br, 940, 882, 110, 16); $br.Dispose()
Str '敌方绿' 1160 880 $yahei_s (Hex '#C8C8D4')

$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "saved: $out"
