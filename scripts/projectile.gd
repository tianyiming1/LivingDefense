# 子弹：追踪目标；命中溅射/感染；高对比度弹道便于看见
extends Node2D

var target: Node = null
var _enemies: Node2D = null
var damage := 0.0
var speed := 430.0
var splash_radius := 0.0
var slow := 1.0
var slow_time := 0.0
var travelled := 0.0
var color := Color(1.0, 0.95, 0.55)
var kind := "single"
var _last_dir := Vector2.RIGHT
var _boom_timer := 0.0
var _boom_pos := Vector2.ZERO
var _done := false
var _trail: Array[Vector2] = []

var _from_fungus := false

func setup(tower: Node, enemies: Node2D, tgt: Node, dmg: float, sp: float, splash: float, s: float, st: float, col: Color = Color.WHITE, pk: String = "single") -> void:
	_enemies = enemies
	target = tgt
	damage = dmg
	speed = sp
	splash_radius = splash
	slow = s
	slow_time = st
	color = col
	kind = pk
	_from_fungus = pk == "spore" or (tower != null and tower.get("race") == "fungus")
	# 调用方已设好枪口坐标时不要覆盖回脚底
	z_index = 25
	if tgt != null and is_instance_valid(tgt):
		_last_dir = global_position.direction_to(tgt.global_position)
		if _last_dir.length_squared() < 0.0001:
			_last_dir = Vector2.RIGHT

func _physics_process(delta: float) -> void:
	if _done:
		_boom_timer -= delta
		queue_redraw()
		if _boom_timer <= 0.0:
			queue_free()
		return
	if target == null or not is_instance_valid(target):
		queue_free()
		return
	var to: Vector2 = target.global_position
	var dir := global_position.direction_to(to)
	if dir.length_squared() > 0.001:
		_last_dir = dir
	_trail.append(global_position)
	if _trail.size() > 12:
		_trail.pop_front()
	global_position += dir * speed * delta
	travelled += speed * delta
	queue_redraw()
	if global_position.distance_to(to) <= 16.0 or travelled > 1000.0:
		_hit()

func _hit() -> void:
	if splash_radius > 0.0 and _enemies != null:
		_boom_pos = global_position
		_boom_timer = 0.22
		_done = true
		for e in _enemies.get_children():
			if e.global_position.distance_to(global_position) <= splash_radius:
				e.apply_damage(damage, slow, slow_time, _from_fungus, kind)
		_spawn_impact(global_position)
	else:
		if target != null and is_instance_valid(target):
			var dk: String = kind
			if kind == "spore":
				dk = "single"
			target.apply_damage(damage, slow, slow_time, _from_fungus, dk)
		if has_meta("infect_radius") and target != null and is_instance_valid(target):
			target.mark_infected()
		_spawn_impact(global_position)
		queue_free()

func _spawn_impact(pos: Vector2) -> void:
	var fx: Node = load("res://scripts/attack_vfx.gd").new()
	get_parent().add_child(fx)
	fx.global_position = pos
	fx.play_impact(color)

func _draw() -> void:
	if _done:
		var a: float = clampf(_boom_timer / 0.22, 0.0, 1.0)
		var local_boom: Vector2 = _boom_pos - global_position
		draw_arc(local_boom, splash_radius * (1.1 - a * 0.3), 0.0, TAU, 48, Color(1.0, 0.55, 0.15, 0.55 * a), 3.5, true)
		draw_circle(local_boom, 16.0 * a, Color(1.0, 0.75, 0.25, 0.45 * a))
		draw_circle(local_boom, 8.0 * a, Color(1.0, 0.95, 0.7, 0.7 * a))
		return
	for i in range(_trail.size()):
		var t: float = float(i + 1) / float(_trail.size())
		var lp: Vector2 = _trail[i] - global_position
		draw_circle(lp, 3.5 * t, Color(color, 0.4 * t))
	match kind:
		"splash", "spore":
			_draw_mortar_round()
		"aa":
			_draw_bolt(22.0, 7.0)
		_:
			_draw_bolt(20.0, 6.0)

func _draw_bolt(tail: float, r: float) -> void:
	draw_line(Vector2.ZERO, -_last_dir * tail, Color(color, 0.7), 8.0, true)
	draw_line(Vector2.ZERO, -_last_dir * tail * 0.65, Color(1, 1, 1, 0.95), 4.0, true)
	draw_circle(Vector2.ZERO, r + 6.0, Color(color, 0.45))
	draw_circle(Vector2.ZERO, r + 2.0, Color(1, 1, 1, 0.9))
	draw_circle(Vector2.ZERO, r, color)

func _draw_mortar_round() -> void:
	var tail := 14.0
	draw_line(Vector2.ZERO, -_last_dir * tail, Color(0.45, 0.75, 0.2, 0.75), 7.0, true)
	draw_line(Vector2.ZERO, -_last_dir * tail * 0.5, Color(0.85, 1.0, 0.55, 0.9), 3.0, true)
	draw_circle(Vector2.ZERO, 10.0, Color(0.45, 0.75, 0.2, 0.55))
	draw_circle(Vector2.ZERO, 6.0, Color(0.25, 0.45, 0.1))
