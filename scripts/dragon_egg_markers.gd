# CO-015：龙族重孵蛋简易场上标记（位置 + 倒计时可读）
extends Node2D

var eggs: Array = []  # [{pos: Vector2, time: float}, ...]

func set_eggs(src: Array) -> void:
	eggs = src
	queue_redraw()

func _process(_delta: float) -> void:
	if not eggs.is_empty():
		queue_redraw()

func _draw() -> void:
	if eggs.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	for egg in eggs:
		var pos: Vector2 = egg.get("pos", Vector2.ZERO)
		var t: float = float(egg.get("time", 0.0))
		var a: float = 0.35 + 0.45 * pulse
		draw_circle(pos, 18.0, Color(1.0, 0.45, 0.12, 0.22 * pulse))
		draw_arc(pos, 16.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.2, a), 2.2, true)
		draw_circle(pos, 7.0, Color(1.0, 0.75, 0.35, 0.75))
		var sec_txt := "%ds" % int(ceil(t))
		draw_string(font, pos + Vector2(-10, -22), sec_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.92, 0.7, 0.95))
