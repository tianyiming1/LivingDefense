# 敌人：沿路径行进，索敌追击，支持毒/烧/麻痹/冰冻/感染；三怪外形各异
extends Node2D

signal died(reward: int)
signal escaped

var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var reward := 0
var wave_index := 1
var waypoint_index := 1
var slow_factor := 1.0
var slow_timer := 0.0
var alive := true
var infected := false
var _units: Node2D = null
var _main: Node = null
var _attack_timer := 0.9
var _blocked := false
var _unit_locked: Node = null
var _attack_flash := 0.0
var _hit_flash := 0.0
var _attack_line_to := Vector2.ZERO
var _poison_timer := 0.0
var _poison_dps := 0.0
var _burn_timer := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _paralyze_timer := 0.0
var _frozen_timer := 0.0
var _spore_timer := 0.0
var _carpet_tick := 0.0
var _sprite_view: Node2D = null
var _prev_pos := Vector2.ZERO

func setup(e_def: Dictionary, wave: int, units: Node2D, main: Node = null) -> void:
	def = e_def
	_units = units
	_main = main
	wave_index = maxi(1, wave)
	hp = Config.enemy_hp(int(def["id"]), wave_index)
	max_hp = hp
	speed = float(def["speed"])
	reward = int(def["reward"])
	_spawn_offset()
	_attack_timer = float(def.get("attack_interval", 0.9))
	_prev_pos = position
	_maybe_spawn_sprite_view()

func _maybe_spawn_sprite_view() -> void:
	var tex: Texture2D = UnitSprites.load_enemy_texture(int(def.get("id", 0)))
	if tex == null:
		return
	if _sprite_view != null:
		return
	_sprite_view = Node2D.new()
	_sprite_view.set_script(load("res://scripts/enemy_sprite_view.gd"))
	add_child(_sprite_view)
	_sprite_view.setup(tex, int(def.get("id", 0)))

func _uses_pixel_sprite() -> bool:
	if _sprite_view == null or not is_instance_valid(_sprite_view):
		return false
	return _sprite_view.has_method("has_sprite") and _sprite_view.has_sprite()

func _spawn_offset() -> void:
	var pts: Array[Vector2] = Config.PATH_POINTS
	var dir: Vector2 = (pts[1] - pts[0]).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var slot: int = get_instance_id() % 5
	var lane: float = float(slot) - 2.0
	var back: float = float((get_instance_id() / 5) % 4) * Config.ENEMY_MIN_SEP * 0.6
	position = pts[0] - dir * back + perp * lane * (Config.ENEMY_MIN_SEP * 0.45)

func _physics_process(delta: float) -> void:
	if not alive or hp <= 0.0:
		return
	_tick_status(delta)
	if _frozen_timer > 0.0 or _paralyze_timer > 0.0:
		queue_redraw()
		return
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	if _attack_flash > 0.0:
		_attack_flash -= delta
	if _hit_flash > 0.0:
		_hit_flash -= delta
	var pts: Array[Vector2] = Config.PATH_POINTS
	if waypoint_index >= pts.size():
		alive = false
		escaped.emit()
		queue_free()
		return
	if _blocked:
		_blocked = _any_blocker_within(34.0)
	else:
		_blocked = _any_blocker_within(28.0)
	if _blocked:
		var chase_unit := _acquire_unit()
		if chase_unit != null:
			position = position.move_toward(chase_unit.position, speed * slow_factor * delta)
		else:
			var target: Vector2 = pts[waypoint_index]
			position = position.move_toward(target, speed * slow_factor * delta)
			if position.distance_to(target) < 6.0:
				waypoint_index += 1
	else:
		var target: Vector2 = pts[waypoint_index]
		position = position.move_toward(target, speed * slow_factor * delta)
		if position.distance_to(target) < 6.0:
			waypoint_index += 1
	_attack_timer -= delta * _attack_rate_mult()
	if _attack_timer <= 0.0 and _units != null:
		_attack_timer = float(def.get("attack_interval", 0.9))
		_attack_nearest()
	_apply_carpet(delta)
	_apply_separation()
	var moved: float = position.distance_to(_prev_pos)
	if _sprite_view != null:
		var moving: bool = moved > 0.4 and _frozen_timer <= 0.0 and _paralyze_timer <= 0.0
		if _sprite_view.has_method("set_moving"):
			_sprite_view.set_moving(moving)
		if _sprite_view.has_method("set_facing_toward"):
			var face_pos: Vector2 = global_position + Vector2.RIGHT
			if _unit_locked != null and is_instance_valid(_unit_locked):
				face_pos = _unit_locked.global_position
			elif moved > 0.15:
				var vel: Vector2 = position - _prev_pos
				if vel.length_squared() > 0.0001:
					face_pos = global_position + vel.normalized() * 32.0
			_sprite_view.set_facing_toward(face_pos)
	if _uses_pixel_sprite():
		z_index = UnitSprites.depth_z(position.y)
	_prev_pos = position
	queue_redraw()

func _tick_status(delta: float) -> void:
	if _poison_timer > 0.0:
		_poison_timer -= delta
		hp -= _poison_dps * delta
		if hp <= 0.0:
			_die()
			return
	if _burn_timer > 0.0:
		_burn_timer -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			hp -= _burn_dps * 0.5
			if hp <= 0.0:
				_die()
				return
	if _spore_timer > 0.0:
		_spore_timer -= delta
	if _paralyze_timer > 0.0:
		_paralyze_timer -= delta
	if _frozen_timer > 0.0:
		_frozen_timer -= delta

func _apply_carpet(delta: float) -> void:
	if _main == null or not _main.has_method("carpet_effect_at"):
		return
	var eff: Dictionary = _main.carpet_effect_at(position)
	if not bool(eff.get("on_carpet", false)):
		return
	slow_factor = minf(slow_factor, float(eff.get("slow", 1.0)))
	slow_timer = maxf(slow_timer, 0.4)
	_carpet_tick -= delta
	if _carpet_tick <= 0.0:
		_carpet_tick = Config.CARPET_TICK_INTERVAL
		apply_spore_debuff()

func _acquire_unit() -> Node:
	if _unit_locked != null and is_instance_valid(_unit_locked) and _unit_locked.is_inside_tree():
		var d: float = position.distance_to(_unit_locked.position)
		if d <= Config.ENEMY_AGGRO_RANGE + 20.0 and _can_target(_unit_locked):
			return _unit_locked
	var best: Node = null
	var best_d := INF
	for u in _units.get_children():
		if not _can_target(u):
			continue
		var d: float = position.distance_to(u.position)
		if d <= Config.ENEMY_AGGRO_RANGE and d < best_d:
			best_d = d
			best = u
	_unit_locked = best
	return best

func _can_target(u: Node) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	if bool(u.def.get("can_fly", false)):
		return false
	return true

func _attack_nearest() -> void:
	var best: Node = null
	var best_d := INF
	for u in _units.get_children():
		if not _can_target(u):
			continue
		var d: float = position.distance_to(u.position)
		if d <= Config.WAVE_ENEMY_ATTACK_RANGE and d < best_d:
			best_d = d
			best = u
	if best != null:
		var atk: float = float(def.get("attack", 0.0)) * Config.enemy_attack_mult(wave_index)
		best.apply_enemy_damage(atk)
		_attack_flash = 0.16
		_attack_line_to = best.position - position
		if _sprite_view != null and _sprite_view.has_method("play_bite"):
			_sprite_view.play_bite()

func _any_blocker_within(radius: float) -> bool:
	if _units == null:
		return false
	for u in _units.get_children():
		var k: String = u.def.get("kind", "")
		if k in ["melee", "wall", "explode", "burst", "farmer"] and position.distance_to(u.position) <= radius:
			return true
	return false

func _apply_separation() -> void:
	var layer := get_parent()
	if layer == null:
		return
	var push := Vector2.ZERO
	for e in layer.get_children():
		if e == self:
			continue
		var diff: Vector2 = position - e.position
		var dist: float = diff.length()
		if dist < 0.001:
			diff = Vector2.from_angle(float(get_instance_id() % 628) / 100.0)
			dist = 0.001
		if dist < Config.ENEMY_MIN_SEP:
			push += diff.normalized() * (Config.ENEMY_MIN_SEP - dist)
	if push.length_squared() > 0.0:
		position += push * 0.55

func _attack_rate_mult() -> float:
	if _spore_timer > 0.0:
		return maxf(0.35, 1.0 - Config.CARPET_ATTACK_SLOW)
	return 1.0

func apply_spore_debuff() -> void:
	_spore_timer = maxf(_spore_timer, 1.4)

func apply_carpet_aura(extra_slow: float) -> void:
	slow_factor = minf(slow_factor, 1.0 - extra_slow)
	slow_timer = maxf(slow_timer, 0.5)
	apply_spore_debuff()

func apply_damage(dmg: float, slow: float, slow_time: float, from_fungus: bool = false, dmg_kind: String = "generic") -> void:
	_hit_flash = 0.16
	if _sprite_view != null and _sprite_view.has_method("play_hit"):
		_sprite_view.play_hit()
	var actual: float = dmg * Config.armor_damage_mult(def, dmg_kind)
	if from_fungus and _spore_timer > 0.0:
		actual *= 1.0 + Config.CARPET_SPORE_VULN
	hp -= actual
	if slow < 1.0:
		slow_factor = slow
		slow_timer = slow_time
	if hp <= 0.0 and alive:
		_die()

func apply_poison(dps: float, duration: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)

func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_timer = maxf(_burn_timer, duration)

func apply_paralyze(duration: float) -> void:
	_paralyze_timer = maxf(_paralyze_timer, duration)

func apply_freeze(duration: float) -> void:
	_frozen_timer = maxf(_frozen_timer, duration)

func mark_infected() -> void:
	infected = true

func _die() -> void:
	if not alive:
		return
	alive = false
	if _sprite_view != null and _sprite_view.has_method("play_death"):
		_sprite_view.play_death()
	if infected or (_main != null and bool(_main.get("spore_burst_active"))):
		_spread_infection()
	died.emit(reward)
	queue_free()

func _spread_infection() -> void:
	var layer := get_parent()
	if layer == null:
		return
	for e in layer.get_children():
		if e == self or not e.has_method("mark_infected"):
			continue
		if e.global_position.distance_to(global_position) <= Config.SPORE_INFECT_RADIUS:
			e.mark_infected()
			e.apply_poison(2.0, 2.5)

func _draw() -> void:
	if def.is_empty():
		return
	var eid: int = int(def.get("id", 0))
	if _attack_flash > 0.0:
		var a: float = _attack_flash / 0.16
		draw_line(Vector2.ZERO, _attack_line_to, Color(1.0, 0.45, 0.35, 0.85 * a), 2.5, true)
		draw_circle(_attack_line_to, 5.0, Color(1.0, 0.55, 0.25, 0.7 * a))
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 4.0, Color(1.0, 0.9, 0.9, 0.5 * (_hit_flash / 0.16)))
	if not _uses_pixel_sprite():
		_draw_body(eid)
	if infected:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 5.0, 0.0, TAU, 20, Color(0.55, 0.95, 0.25, 0.55), 1.5, true)
	if _poison_timer > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 3.0, Color(0.35, 0.85, 0.2, 0.35))
	if _main != null and _main.is_on_carpet(position):
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 7.0, 0.0, TAU, 20, Color(0.4, 0.85, 0.25, 0.4), 1.5, true)
	if _spore_timer > 0.0:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 5.0, 0.0, TAU, 16, Color(0.55, 0.95, 0.35, 0.5), 1.2, true)
	if _burn_timer > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 2.0, Color(1.0, 0.45, 0.1, 0.4))
	if _paralyze_timer > 0.0 or _frozen_timer > 0.0:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 6.0, 0.0, TAU, 24, Color(0.55, 0.85, 1.0, 0.65), 2.0, true)
	if slow_factor < 1.0:
		draw_circle(Vector2.ZERO, 13.0, Color(0.55, 0.85, 1.0, 0.35))
	var w := 24.0
	var fill := clampf(hp / max_hp, 0.0, 1.0)
	var bar_y := (-34.0 if _uses_pixel_sprite() else -18.0) - float(get_index() % 3) * 5.0
	draw_rect(Rect2(-w * 0.5, bar_y, w, 4.0), Color(0.1, 0.1, 0.1, 0.8))
	var bar_col := Color(0.25, 0.9, 0.3)
	if eid == 1:
		bar_col = Color(0.35, 0.75, 1.0)
	elif eid == 2:
		bar_col = Color(0.75, 0.55, 0.9)
	elif eid == 3:
		bar_col = Color(0.75, 0.78, 0.82)
	draw_rect(Rect2(-w * 0.5, bar_y, w * fill, 4.0), bar_col)
	# 铁皮：护甲板外圈提示
	if eid == 3 and bool(def.get("armored", false)):
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 5.0, 0.0, TAU, 20, Color(0.85, 0.88, 0.92, 0.55), 2.0, true)

func _draw_body(eid: int) -> void:
	var col := Color(def["color"])
	match eid:
		0:  # Grunt: 圆角方块
			draw_rect(Rect2(-9, -9, 18, 18), col)
			draw_rect(Rect2(-9, -9, 18, 18), Color(0, 0, 0, 0.35), false, 1.5, true)
		1:  # Runner: 尖三角
			var pts := PackedVector2Array([Vector2(12, 0), Vector2(-8, -9), Vector2(-8, 9)])
			draw_colored_polygon(pts, col)
			draw_polyline(pts, Color(0, 0, 0, 0.4), 1.5, true)
		2:  # Tank: 双层六边形
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 3.0, Color(col, 0.35))
			for i in range(6):
				var a0 := float(i) * TAU / 6.0
				var a1 := float(i + 1) * TAU / 6.0
				draw_line(Vector2(cos(a0), sin(a0)) * Config.ENEMY_RADIUS, Vector2(cos(a1), sin(a1)) * Config.ENEMY_RADIUS, col, 3.0, true)
		3:  # Armored: 厚盾牌形
			draw_rect(Rect2(-10, -11, 20, 22), col, true)
			draw_rect(Rect2(-10, -11, 20, 22), Color(0.15, 0.15, 0.18, 0.8), false, 2.0, true)
			draw_rect(Rect2(-6, -7, 12, 14), Color(0.75, 0.78, 0.85, 0.55), true)
			draw_line(Vector2(0, -9), Vector2(0, 9), Color(0.2, 0.22, 0.25, 0.7), 2.0, true)
		_:
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS, col)
