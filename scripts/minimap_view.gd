# Dota 式左下小地图：画路径/出生终点/镜头框/单位点；点击跳转镜头
extends Control

signal jump_requested(world_pos: Vector2)

var _main: Node = null

func setup(main: Node) -> void:
	_main = main
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position
		var ms: Vector2 = Config.MAP_SIZE
		if size.x <= 1.0 or size.y <= 1.0:
			return
		var world := Vector2(local.x / size.x * ms.x, local.y / size.y * ms.y)
		jump_requested.emit(world)
		accept_event()

func _draw() -> void:
	var ms: Vector2 = Config.MAP_SIZE
	if size.x < 2.0 or size.y < 2.0 or ms.x < 1.0:
		return
	var sx: float = size.x / ms.x
	var sy: float = size.y / ms.y
	# 可建区底
	draw_rect(Rect2(Vector2.ZERO, size), Color("386640"))
	# 路径
	var pts: Array = Config.PATH_POINTS
	if pts.size() >= 2:
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i] * Vector2(sx, sy)
			var b: Vector2 = pts[i + 1] * Vector2(sx, sy)
			draw_line(a, b, Color(0.35, 0.28, 0.16), 5.0)
			draw_line(a, b, Color("C7B380"), 3.0)
		draw_circle(pts[0] * Vector2(sx, sy), 5.0, Color(0.35, 0.9, 0.4))
		draw_circle(pts[pts.size() - 1] * Vector2(sx, sy), 5.0, Color("BF4A2F"))
	# 单位 / 敌人点
	if _main != null:
		if _main.units_layer != null:
			for u in _main.units_layer.get_children():
				if u != null and is_instance_valid(u):
					draw_circle(u.position * Vector2(sx, sy), 2.2, Color(0.55, 0.75, 1.0))
		if _main.enemies_layer != null:
			for e in _main.enemies_layer.get_children():
				if e != null and is_instance_valid(e):
					draw_circle(e.position * Vector2(sx, sy), 2.0, Color(0.95, 0.35, 0.25))
		if _main.hq != null and is_instance_valid(_main.hq):
			draw_circle(_main.hq.position * Vector2(sx, sy), 3.5, Color(1.0, 0.85, 0.3))
	# 镜头可见框（战场为纯 16:9 VIEW_SIZE）
	var cam := _find_cam()
	if cam != null:
		var vp: Vector2 = Config.VIEW_SIZE
		var half := Vector2(vp.x * 0.5 / cam.zoom.x, vp.y * 0.5 / cam.zoom.y)
		var tl: Vector2 = (cam.position - half) * Vector2(sx, sy)
		var sz: Vector2 = half * 2.0 * Vector2(sx, sy)
		draw_rect(Rect2(tl, sz), Color(1, 1, 1, 0.85), false, 1.5)

func _find_cam() -> Camera2D:
	if _main == null:
		return null
	var bc = _main.get("battle_cam")
	if bc is Camera2D:
		return bc as Camera2D
	var wr = _main.get("world_root")
	if wr != null:
		for c in wr.get_children():
			if c is Camera2D:
				return c as Camera2D
	for c in _main.get_children():
		if c is Camera2D:
			return c as Camera2D
	return null
