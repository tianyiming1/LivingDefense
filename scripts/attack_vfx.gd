# 攻击特效：枪口闪光 / 命中火花 / 龙焰吐息爆发（短生命周期）
extends Node2D

var _timer := 0.0
var _duration := 0.14
var _col := Color.WHITE
var _mode := "impact"
var _radius := 18.0

func play_muzzle(col: Color, dir: Vector2) -> void:
	_col = col
	_mode = "muzzle"
	rotation = dir.angle()
	_timer = _duration
	z_index = 24
	set_process(true)

func play_impact(col: Color) -> void:
	_col = col
	_mode = "impact"
	_timer = 0.18
	_duration = 0.18
	z_index = 24
	set_process(true)

func play_dragon_breath(center: Vector2, radius: float = 90.0) -> void:
	global_position = center
	_col = Color(1.0, 0.45, 0.12)
	_mode = "breath"
	_radius = radius
	_duration = 0.55
	_timer = _duration
	z_index = 28
	set_process(true)

func play_arcane_burst(center: Vector2, radius: float = 36.0) -> void:
	global_position = center
	_col = Color(0.65, 0.40, 1.0)
	_mode = "breath"
	_radius = radius
	_duration = 0.35
	_timer = _duration
	z_index = 28
	set_process(true)

## CO-046：梦雾环（冰蓝紫，非橙焰）
func play_dream_mist(center: Vector2, radius: float = 56.0) -> void:
	global_position = center
	_col = Color(0.55, 0.72, 1.0, 0.85)
	_mode = "mist"
	_radius = radius
	_duration = 0.45
	_timer = _duration
	z_index = 26
	set_process(true)

## CO-046：单目标睡眠命中环（淡紫月牙 + 星尘，非 arcane/橙焰）
func play_sleep_ring(center: Vector2, radius: float = 32.0) -> void:
	global_position = center
	_col = Color(0.773, 0.710, 0.992, 0.92) # #C4B5FD
	_mode = "sleep_ring"
	_radius = radius
	_duration = 0.4
	_timer = _duration
	z_index = 27
	set_process(true)

## CO-047：群体睡眠扩散波
func play_sleep_wave(center: Vector2, radius: float = 78.0) -> void:
	global_position = center
	_col = Color(0.77, 0.71, 0.98, 0.9)
	_mode = "sleep_wave"
	_radius = radius
	_duration = 0.5
	_timer = _duration
	z_index = 27
	set_process(true)

func _process(delta: float) -> void:
	_timer -= delta
	queue_redraw()
	if _timer <= 0.0:
		queue_free()

func _draw() -> void:
	var a: float = clampf(_timer / _duration, 0.0, 1.0)
	if _mode == "muzzle":
		draw_circle(Vector2.ZERO, 10.0 * a, Color(1, 0.95, 0.7, 0.85 * a))
		draw_circle(Vector2(14, 0), 6.0 * a, Color(_col, 0.9 * a))
		draw_line(Vector2(4, 0), Vector2(22, 0), Color(1, 1, 1, 0.9 * a), 4.0 * a, true)
	elif _mode == "sleep_ring":
		var grow: float = 1.0 - a
		var r: float = _radius * (0.55 + 0.5 * grow)
		var c0 := Color(0.494, 0.784, 1.0, 0.35 * a) # #7EC8FF
		var c1 := Color(0.773, 0.710, 0.992, 0.75 * a)
		draw_arc(Vector2.ZERO, r, PI * 0.15, PI * 0.85, 28, c1, 3.2, true)
		draw_arc(Vector2.ZERO, r * 0.72, PI * 0.2, PI * 0.8, 22, c0, 2.0, true)
		for i in range(5):
			var ang := PI * 0.35 + float(i) * 0.18 + grow * 0.4
			var dist := r * (0.35 + float(i) * 0.08)
			var p := Vector2(cos(ang), sin(ang)) * dist + Vector2(0.0, -10.0 * grow)
			draw_circle(p, 1.8 + float(i % 2), Color(0.85, 0.78, 1.0, 0.7 * a))
	elif _mode == "mist" or _mode == "sleep_wave":
		var grow: float = 1.0 - a
		var r: float = _radius * (0.4 + 0.75 * grow)
		var c0 := Color(0.42, 0.28, 0.72, 0.22 * a)
		var c1 := Color(_col.r, _col.g, _col.b, 0.35 * a)
		var c2 := Color(0.77, 0.71, 0.98, 0.8 * a)
		draw_circle(Vector2.ZERO, r, c0)
		draw_circle(Vector2.ZERO, r * 0.55, c1)
		draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 40, c2, 3.0, true)
		if _mode == "sleep_wave":
			draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 32, Color(0.9, 0.88, 1.0, 0.55 * a), 2.0, true)
	elif _mode == "breath":
		var grow: float = 1.0 - a
		var r: float = _radius * (0.35 + 0.9 * grow)
		# 若调用方传入了非火色（如 arcane），跟 _col；否则默认橙焰
		var is_fire: bool = _col.r > 0.85 and _col.g < 0.55
		var o0 := Color(1.0, 0.35, 0.08, 0.28 * a) if is_fire else Color(_col.r, _col.g, _col.b, 0.28 * a)
		var o1 := Color(1.0, 0.75, 0.25, 0.4 * a) if is_fire else Color(1.0, 1.0, 1.0, 0.35 * a)
		var o2 := Color(1.0, 0.55, 0.15, 0.85 * a) if is_fire else Color(_col, 0.85 * a)
		draw_circle(Vector2.ZERO, r, o0)
		draw_circle(Vector2.ZERO, r * 0.55, o1)
		draw_arc(Vector2.ZERO, r * 0.9, 0.0, TAU, 36, o2, 4.0, true)
		for i in range(8):
			var ang := float(i) * TAU / 8.0 + grow * 0.6
			var tip := Vector2(cos(ang), sin(ang)) * r
			var lc := Color(1.0, 0.85, 0.4, 0.7 * a) if is_fire else Color(_col, 0.7 * a)
			draw_line(tip * 0.2, tip, lc, 3.0 * a, true)
	else:
		draw_circle(Vector2.ZERO, 14.0 * a, Color(_col, 0.5 * a))
		draw_circle(Vector2.ZERO, 7.0 * a, Color(1, 1, 1, 0.85 * a))
		for i in range(6):
			var ang := float(i) * TAU / 6.0
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 18.0 * a, Color(_col, 0.75 * a), 2.5 * a, true)
