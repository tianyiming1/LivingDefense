# 攻击特效：枪口闪光 / 命中火花（短生命周期）
extends Node2D

var _timer := 0.0
var _duration := 0.14
var _col := Color.WHITE
var _mode := "impact"

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
	else:
		draw_circle(Vector2.ZERO, 14.0 * a, Color(_col, 0.5 * a))
		draw_circle(Vector2.ZERO, 7.0 * a, Color(1, 1, 1, 0.85 * a))
		for i in range(6):
			var ang := float(i) * TAU / 6.0
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * 18.0 * a, Color(_col, 0.75 * a), 2.5 * a, true)
