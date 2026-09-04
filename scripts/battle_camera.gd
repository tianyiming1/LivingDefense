# CO-ART-PROD-001 W3：战地式镜头——视口只看地图局部，可缩放/平移
# 开局锁大本营；底栏 HUD 叠加时用 offset + usable_h 抬高战场，避免挡路。
extends Camera2D

const ZOOM_MIN := 0.7
const ZOOM_MAX := 1.6
const ZOOM_STEP := 0.08
const START_ZOOM := 1.35
const PAN_SPEED := 640.0
const EDGE_PX := 22.0
const HQ_LOOK_BIAS := Vector2(-220.0, 0.0)

var _dragging := false
var _home_pos := Vector2.ZERO

func _ready() -> void:
	make_current()
	zoom = Vector2(START_ZOOM, START_ZOOM)
	position = Config.MAP_SIZE * 0.5
	_home_pos = position
	_apply_hud_safe_offset()
	call_deferred("_clamp_to_map")

func focus_world(pos: Vector2) -> void:
	position = pos
	_home_pos = pos
	_apply_hud_safe_offset()
	_clamp_to_map()

func focus_hq(pos: Vector2) -> void:
	zoom = Vector2(START_ZOOM, START_ZOOM)
	focus_world(pos + HQ_LOOK_BIAS)

func _vp_size() -> Vector2:
	return Config.VIEW_SIZE

func _hud_bottom() -> float:
	return Config.HUD_BOTTOM_PX

func _apply_hud_safe_offset() -> void:
	var hud: float = _hud_bottom()
	offset = Vector2(0.0, (hud * 0.5) / maxf(zoom.y, 0.01))

func _view_half() -> Vector2:
	var vp := _vp_size()
	var usable_h: float = maxf(120.0, vp.y - _hud_bottom())
	return Vector2(vp.x * 0.5 / zoom.x, usable_h * 0.5 / zoom.y)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_add_zoom(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_add_zoom(-ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position -= mm.relative / zoom.x
		_clamp_to_map()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME:
			zoom = Vector2(START_ZOOM, START_ZOOM)
			focus_world(_home_pos if _home_pos != Vector2.ZERO else Config.MAP_SIZE * 0.5)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	var win := get_window()
	var vp := _vp_size()
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var hud: float = _hud_bottom()
	if win != null and win.has_focus() and Rect2(Vector2.ZERO, Vector2(vp.x, vp.y - hud)).grow(-1.0).has_point(mouse):
		if mouse.x <= EDGE_PX:
			dir.x -= 1.0
		elif mouse.x >= vp.x - EDGE_PX:
			dir.x += 1.0
		if mouse.y <= EDGE_PX:
			dir.y -= 1.0
		elif mouse.y >= vp.y - hud - EDGE_PX:
			dir.y += 1.0
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_to_map()

func _add_zoom(delta_z: float) -> void:
	var z: float = clampf(zoom.x + delta_z, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	_apply_hud_safe_offset()
	_clamp_to_map()

func _clamp_to_map() -> void:
	_apply_hud_safe_offset()
	var half := _view_half()
	var ms: Vector2 = Config.MAP_SIZE
	if half.x * 2.0 >= ms.x:
		position.x = ms.x * 0.5
	else:
		position.x = clampf(position.x, half.x, ms.x - half.x)
	if half.y * 2.0 >= ms.y:
		position.y = ms.y * 0.5
	else:
		position.y = clampf(position.y, half.y, ms.y - half.y)
