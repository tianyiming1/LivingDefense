extends Node2D
# 游戏画面预览 v2：AI 战士帧动画放进完整游戏画面（地图/影子/敌人/HUD）
const FPS := 7.0
const EnemyDrawn = preload("res://demo_sprite_walk/enemy_drawn.gd")
const SPEED := 100.0
const BOB_AMP := 4.0
const BOB_FREQ := 2.6
var path_pts: Array[Vector2] = [
	Vector2(80, 500), Vector2(340, 380), Vector2(560, 430),
	Vector2(760, 250), Vector2(980, 330), Vector2(1150, 600),
]
var t := 0.0
var anim: AnimatedSprite2D
var shadow: Sprite2D
var particles: CPUParticles2D
var enemies: Array[Node2D] = []
var enemy_t := 0.0
var hud: CanvasLayer
var label: Label

func _ready() -> void:
	# 背景远景板（转制压暗）
	var bg_tex := load("res://docs/repurpose_demo/bg_veins_dark.png")
	var bg := Sprite2D.new()
	bg.texture = bg_tex
	bg.centered = false
	bg.position = Vector2.ZERO
	bg.scale = Vector2(1280.0 / bg_tex.get_width(), 720.0 / bg_tex.get_height())
	add_child(bg)
	# 战场暗化层
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.04, 0.06, 0.45)
	dark.position = Vector2.ZERO
	dark.size = Vector2(1280, 720)
	add_child(dark)

	# 主路径
	var line := Line2D.new()
	line.points = path_pts
	line.width = 56.0
	line.default_color = Color(0.12, 0.13, 0.16, 0.7)
	line.closed = false
	add_child(line)

	# 基地（右下六边形）
	var base := Polygon2D.new()
	var r := 56.0
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2(1130, 600) + Vector2(cos(i * PI / 3), sin(i * PI / 3)) * r)
	base.polygon = pts
	base.color = Color(0.2, 0.25, 0.35, 0.75)
	add_child(base)
	var rim := Line2D.new()
	rim.points = pts
	rim.closed = true
	rim.width = 3.0
	rim.default_color = Color(0.435, 0.827, 0.906, 0.9)
	add_child(rim)

	# AI 战士帧动画
	var sf := SpriteFrames.new()
	sf.add_animation("walk")
	sf.set_animation_speed("walk", FPS)
	for name in ["w1", "w2", "w3", "w4"]:
		sf.add_frame("walk", load("res://docs/repurpose_demo/walk_frames/" + name + "_128.png"))
	anim = AnimatedSprite2D.new()
	anim.sprite_frames = sf
	anim.animation = "walk"
	anim.scale = Vector2(1.6, 1.6)
	anim.play()
	add_child(anim)

	# 脚下影子
	shadow = Sprite2D.new()
	var sh_tex := GradientTexture2D.new()
	sh_tex.gradient = Gradient.new()
	sh_tex.gradient.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	sh_tex.width = 64
	sh_tex.height = 18
	sh_tex.fill_from = Vector2(0.5, 0)
	sh_tex.fill_to = Vector2(0.5, 1)
	sh_tex.fill = GradientTexture2D.FILL_LINEAR
	shadow.texture = sh_tex
	shadow.centered = true
	add_child(shadow)

	# 粒子尾迹
	particles = CPUParticles2D.new()
	particles.amount = 40
	particles.lifetime = 0.6
	particles.emitting = true
	particles.direction = Vector2(1, 0)
	particles.spread = 35.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 70.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.435, 0.827, 0.906)
	add_child(particles)

	# 敌方单位（暗红菱形，对向沿路径走）
	var enemy_col := Color(0.91, 0.40, 0.29, 1.0)  # 敌方色板（与友方亮度差 >= 40）
	var ed := EnemyDrawn.new()
	ed.color = enemy_col
	ed.scale = Vector2(1.4, 1.4)
	enemies.append(ed)
	add_child(ed)
	for i in 3:
		var e := EnemyDrawn.new()
		e.color = enemy_col
		e.scale = Vector2(1.2, 1.2)
		enemies.append(e)
		add_child(e)

	# HUD
	hud = CanvasLayer.new()
	add_child(hud)
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.05, 0.08, 0.85)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 48)
	hud.add_child(bar)
	var lbl1 := Label.new()
	lbl1.text = "晶能  128/200"
	lbl1.position = Vector2(20, 8)
	lbl1.add_theme_font_size_override("font_size", 20)
	lbl1.add_theme_color_override("font_color", Color(0.87, 0.95, 1.0))
	hud.add_child(lbl1)
	var lbl2 := Label.new()
	lbl2.text = "波次 3 / 12    矿石 240"
	lbl2.position = Vector2(930, 8)
	lbl2.add_theme_font_size_override("font_size", 20)
	hud.add_child(lbl2)

	var foot := Label.new()
	foot.text = "游戏画面效果预览：AI 战士（帧动画） vs 敌方（程序绘制）沿路径对向推进"
	foot.position = Vector2(170, 690)
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	add_child(foot)

func _process(delta: float) -> void:
	t += delta * SPEED
	enemy_t += delta * 46.0
	var total := 0.0
	for i in path_pts.size() - 1:
		total += path_pts[i].distance_to(path_pts[i + 1])
	var dist := fmod(t, total)
	var pos := _point_at(dist)
	var bob := sin(Time.get_ticks_msec() / 1000.0 * BOB_FREQ) * BOB_AMP
	anim.position = pos + Vector2(0, bob)
	shadow.position = pos + Vector2(0, 34)
	particles.position = pos + Vector2(0, bob)
	# 敌人对向走（路径反向等距错开）
	var e_total := 0.0
	for i in enemies.size():
		var ed2: float = fmod(enemy_t + float(i) * 130.0, total)
		var epos := _point_at_forward(total - ed2)
		enemies[i].position = epos

func _point_at(dist: float) -> Vector2:
	var acc := 0.0
	for i in path_pts.size() - 1:
		var a := path_pts[i]
		var b := path_pts[i + 1]
		var seg_len := a.distance_to(b)
		if dist <= acc + seg_len:
			return a.lerp(b, (dist - acc) / seg_len)
		acc += seg_len
	return path_pts[path_pts.size() - 1]

func _point_at_forward(dist: float) -> Vector2:
	return _point_at(dist)
