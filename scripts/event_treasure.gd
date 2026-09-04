# 挖宝点：点击拾取（CO-019）
extends Node2D

var _bus: Node = null
var _pulse := 0.0
var _area: Area2D = null

func setup(bus: Node) -> void:
	_bus = bus
	_area = Area2D.new()
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	cs.shape = shape
	_area.add_child(cs)
	_area.input_pickable = true
	_area.input_event.connect(_on_input_event)
	add_child(_area)
	z_index = 30
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _on_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _bus != null and _bus.has_method("on_treasure_clicked"):
			_bus.on_treasure_clicked()

func _draw() -> void:
	var a: float = 0.55 + 0.45 * sin(_pulse * 6.0)
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.85, 0.25, 0.35 * a))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.35, 0.9), 2.5, true)
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.95, 0.55, 0.95))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-14, -24), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 0.8, 0.95))
