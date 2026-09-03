extends Node2D
# 骨骼行走 v2：两个硅基战士（关节步态+前倾+呼吸）在地图上行进 + 敌群 + HUD
const PATH: Array[Vector2] = [
    Vector2(80, 520), Vector2(300, 400), Vector2(540, 430),
    Vector2(760, 270), Vector2(1000, 340), Vector2(1180, 580),
]
const SPEED := 120.0
const STEP_PHASE := 7.5
const LEG_SWING := 0.55
const ARM_SWING := 0.35
const KNEE_BEND := 0.85
const BOB_AMP := 8.0
const BODY_H := 56.0
const LEG_L := 28.0
const ARM_L := 20.0
const TILT := 0.10            # 行进前倾

var t := 0.0
var enemy_t := 0.0
var phase_a := 0.0
var phase_b := 3.14159        # 第二人错位半步

func _ready() -> void:
    # 背景板
    var bg_tex := load("res://docs/repurpose_demo/bg_veins_dark.png")
    var bg := Sprite2D.new()
    bg.texture = bg_tex
    bg.centered = false
    bg.scale = Vector2(1280.0 / bg_tex.get_width(), 720.0 / bg_tex.get_height())
    add_child(bg)
    var dark := ColorRect.new()
    dark.color = Color(0.03, 0.04, 0.06, 0.4)
    dark.size = Vector2(1280, 720)
    add_child(dark)
    # 路径
    var line := Line2D.new()
    line.points = PATH
    line.width = 56.0
    line.default_color = Color(0.12, 0.13, 0.16, 0.7)
    add_child(line)
    # 基地
    var hex := PackedVector2Array()
    for i in 6:
        hex.append(Vector2(1130, 600) + Vector2(cos(i * PI / 3), sin(i * PI / 3)) * 56.0)
    var base := Polygon2D.new()
    base.polygon = hex
    base.color = Color(0.2, 0.25, 0.35, 0.75)
    add_child(base)
    var rim := Line2D.new()
    rim.points = hex
    rim.closed = true
    rim.width = 3.0
    rim.default_color = Color(0.435, 0.827, 0.906, 0.9)
    add_child(rim)
    # HUD
    var hud := CanvasLayer.new()
    add_child(hud)
    var bar := ColorRect.new()
    bar.color = Color(0.04, 0.05, 0.08, 0.85)
    bar.size = Vector2(1280, 48)
    hud.add_child(bar)
    var lbl := Label.new()
    lbl.text = "晶能 128/200    波次 3/12    矿石 240"
    lbl.position = Vector2(20, 10)
    lbl.add_theme_font_size_override("font_size", 20)
    hud.add_child(lbl)

func _process(delta: float) -> void:
    t += delta * SPEED
    enemy_t += delta * 46.0
    phase_a += delta * STEP_PHASE
    phase_b += delta * STEP_PHASE
    queue_redraw()

func _draw() -> void:
    var total := 0.0
    for i in PATH.size() - 1:
        total += PATH[i].distance_to(PATH[i + 1])
    _draw_warrior(_point_at(fmod(t, total)), phase_a)
    _draw_warrior(_point_at(fmod(t + 130.0, total)), phase_b)
    # 敌群（暗红菱形）
    for i in 4:
        var ed: float = fmod(enemy_t + i * 140.0, total)
        var epos := _point_at(fmod(total - ed, total))
        var r := 13.0
        var pts := PackedVector2Array([Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])
        var poly := PackedVector2Array()
        for p in pts:
            poly.append(epos + p)
        draw_polygon(poly, PackedColorArray([Color(0.91, 0.40, 0.29)]))
        draw_circle(epos, 4.0, Color(0.45, 0.2, 0.15))

func _draw_warrior(pos: Vector2, ph: float) -> void:
    var dir: float = 1.0 if _dir_x(pos) >= 0 else -1.0
    var bob := sin(ph) * BOB_AMP
    var hip := Vector2(pos.x, pos.y - BODY_H * 0.45 + bob)
    var shou := Vector2(hip.x + dir * TILT * BODY_H * 0.9, hip.y - BODY_H * 0.5)
    var head_c := Vector2(shou.x + dir * TILT * 12.0, shou.y - 15.0)
    var hs := 12.0
    # 头
    draw_rect(Rect2(head_c.x - hs, head_c.y - hs, hs * 2, hs * 2), Color(0.85, 0.9, 1.0))
    var eye_x: float = head_c.x + (hs * 0.4 if dir > 0 else -hs * 1.4)
    draw_rect(Rect2(eye_x, head_c.y - 2.0, 3.0, 3.0), Color(0.1, 0.15, 0.2))
    # 躯干
    var body := PackedVector2Array([
        Vector2(hip.x, hip.y), Vector2(shou.x + dir * 6.0, shou.y + 5.0),
        Vector2(shou.x, shou.y), Vector2(shou.x - dir * 6.0, shou.y + 5.0),
    ])
    draw_polygon(body, PackedColorArray([Color(0.435, 0.827, 0.906)]))
    draw_circle(shou + Vector2(0, 8), 3.5, Color(0.96, 0.98, 1.0))
    # 腿
    var lsin := sin(ph)
    var lcos := cos(ph)
    for pair in [[-1.0, 0.0], [1.0, 3.14159]]:
        var side: float = pair[0]
        var off: float = pair[1]
        var sw: float = sin(ph + off) * LEG_SWING
        var knee := Vector2(hip.x + side * 7.0 + sin(sw) * LEG_L, hip.y + cos(sw) * LEG_L)
        var bend: float = cos(ph + off) * KNEE_BEND
        var foot := Vector2(knee.x - sin(bend) * LEG_L * 0.6, knee.y + cos(bend) * LEG_L)
        if abs(sin(ph + off)) < 0.12:
            foot.y = hip.y + LEG_L * 1.35
        draw_line(hip, knee, Color(0.2, 0.25, 0.32), 5.0)
        draw_line(knee, foot, Color(0.2, 0.25, 0.32), 4.0)
    # 手臂
    for pair in [[-1.0, 0.0], [1.0, 3.14159]]:
        var side: float = pair[0]
        var off: float = pair[1]
        var sw: float = -sin(ph + off) * ARM_SWING
        var elb := Vector2(shou.x + side * 6.0 + sin(sw) * ARM_L, shou.y + cos(sw) * ARM_L * 0.6)
        var hand := Vector2(elb.x + sin(sw) * ARM_L * 0.85, elb.y + cos(sw) * ARM_L * 0.9)
        draw_line(shou, elb, Color(0.28, 0.32, 0.4), 3.5)
        draw_line(elb, hand, Color(0.28, 0.32, 0.4), 3.0)
    # 影子
    var sh_pts := PackedVector2Array()
    for a in range(0, 360, 12):
        var rad := deg_to_rad(a)
        sh_pts.append(Vector2(pos.x + cos(rad) * 22.0, pos.y + sin(rad) * 6.0))
    draw_polygon(sh_pts, PackedColorArray([Color(0, 0, 0, 0.35)]))

func _dir_x(pos: Vector2) -> float:
    return _point_at(fmod(t + 40.0, _path_total())).x - pos.x

func _path_total() -> float:
    var total := 0.0
    for i in PATH.size() - 1:
        total += PATH[i].distance_to(PATH[i + 1])
    return total

func _point_at(dist: float) -> Vector2:
    var acc := 0.0
    for i in PATH.size() - 1:
        var a := PATH[i]
        var b := PATH[i + 1]
        var seg_len := a.distance_to(b)
        if dist <= acc + seg_len:
            return a.lerp(b, (dist - acc) / seg_len)
        acc += seg_len
    return PATH[PATH.size() - 1]