# 敌人：沿路径行进，索敌追击，支持毒/烧/麻痹/冰冻/感染；三怪外形各异
extends Node2D

signal died(reward: int)
signal escaped(dmg: int)

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
var selected := false
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
var _sleep_timer := 0.0
var _spore_timer := 0.0
var _carpet_tick := 0.0
var _was_on_carpet := false
var _carpet_enter_flash := 0.0
var _infect_flash := 0.0
var _infect_pulse := 0.0
var _sprite_view: Node2D = null
var _prev_pos := Vector2.ZERO
var shield_hp := 0.0
var max_shield := 0.0
var _aura_tick := 0.0
var _boss_half_done := false
var _armor_phase := 0  # 0=近战硬 1=远程硬
var _armor_phase_cd := 0.0
var _base_speed := 1.0

func setup(e_def: Dictionary, wave: int, units: Node2D, main: Node = null) -> void:
	def = e_def
	_units = units
	_main = main
	wave_index = maxi(1, wave)
	hp = Config.enemy_hp(int(def["id"]), wave_index)
	max_hp = hp
	max_shield = float(def.get("shield_hp", 0.0))
	shield_hp = max_shield
	speed = float(def["speed"]) * Config.wave_enemy_speed_mult
	_base_speed = speed
	reward = int(round(float(def["reward"]) * Config.wave_enemy_reward_mult))
	_boss_half_done = false
	_armor_phase = 0
	_armor_phase_cd = 8.0 if bool(def.get("phase_armor", false)) else 0.0
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
	_tick_elite_aura(delta)
	_tick_boss(delta)
	if _frozen_timer > 0.0 or _paralyze_timer > 0.0 or _sleep_timer > 0.0:
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
	if _carpet_enter_flash > 0.0:
		_carpet_enter_flash -= delta
	if _infect_flash > 0.0:
		_infect_flash -= delta
	if infected:
		_infect_pulse += delta
	var pts: Array[Vector2] = Config.PATH_POINTS
	if waypoint_index >= pts.size():
		alive = false
		escaped.emit(Config.hq_leak_damage(def))
		queue_free()
		return
	# CO-030/040：近战挡住 → 站住；附近远程也会被追打
	# CO-039：飞行敌掠过走廊，不受近战阻挡，但仍可俯冲咬远程
	var block_r: float = 34.0 if _blocked else 28.0
	if bool(def.get("elite", false)) or bool(def.get("boss", false)):
		block_r += 6.0
	var melee_block: bool = false if Config.is_flying_enemy(def) else _any_combat_blocker_within(block_r)
	_unit_locked = _acquire_unit()
	var chasing_ranged := false
	if _unit_locked != null and is_instance_valid(_unit_locked):
		var pd: float = position.distance_to(_unit_locked.position)
		if pd <= Config.WAVE_ENEMY_ATTACK_RANGE:
			melee_block = true  # 进入交战距离：站住输出（含远程）
		elif pd <= Config.ENEMY_AGGRO_RANGE and not melee_block:
			# 短暂脱离走廊去咬远程/牧师
			position = position.move_toward(_unit_locked.position, speed * slow_factor * delta)
			chasing_ranged = true
	_blocked = melee_block
	if not _blocked and not chasing_ranged:
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
		var moving: bool = moved > 0.4 and _frozen_timer <= 0.0 and _paralyze_timer <= 0.0 and _sleep_timer <= 0.0
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
	if Config.is_flying_enemy(def):
		z_index = maxi(z_index, 40)
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
	if _sleep_timer > 0.0:
		_sleep_timer -= delta

func _apply_carpet(delta: float) -> void:
	if _main == null or not _main.has_method("carpet_effect_at"):
		return
	var eff: Dictionary = _main.carpet_effect_at(position)
	var on_carpet: bool = bool(eff.get("on_carpet", false))
	if on_carpet and not _was_on_carpet:
		_carpet_enter_flash = 0.6
		if _main.has_method("notify_fungus_carpet_step"):
			_main.notify_fungus_carpet_step()
	_was_on_carpet = on_carpet
	if not on_carpet:
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
	if u == null or not is_instance_valid(u) or not u.is_inside_tree():
		return false
	var dead_v = u.get("dead")
	if dead_v != null and dead_v == true:
		return false
	if u.get("def") == null:
		return false
	# 农民/补给站不吸引仇恨；战斗单位（含远程/牧师）可被打
	if Config.is_farmer(u.def) or Config.is_depot(u.def):
		return false
	if bool(u.def.get("can_fly", false)):
		return false
	return true

func _attack_nearest() -> void:
	var best: Node = null
	var best_d := INF
	var best_pri := -1
	for u in _units.get_children():
		if not _can_target(u):
			continue
		var d: float = position.distance_to(u.position)
		if d > Config.WAVE_ENEMY_ATTACK_RANGE:
			continue
		# 近战优先，其次远程/治疗（贴廊射手也会挨打）
		var k: String = str(u.def.get("kind", ""))
		var pri: int = 2 if k in ["melee", "wall", "burst", "explode"] else 1
		if pri > best_pri or (pri == best_pri and d < best_d):
			best_pri = pri
			best_d = d
			best = u
	if best != null:
		var atk: float = float(def.get("attack", 0.0)) * Config.enemy_attack_mult(wave_index)
		best.apply_enemy_damage(atk)
		_attack_flash = 0.16
		_attack_line_to = best.position - position
		_unit_locked = best
		if _sprite_view != null and _sprite_view.has_method("play_bite"):
			_sprite_view.play_bite()

func _any_combat_blocker_within(radius: float) -> bool:
	if _units == null:
		return false
	for u in _units.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		# 农民不挡路；补给站/远程也不挡——只有近战系卡住走廊
		var k: String = str(u.def.get("kind", ""))
		if k not in ["melee", "wall", "explode", "burst"]:
			continue
		if position.distance_to(u.position) <= radius:
			return true
	return false

func _any_blocker_within(radius: float) -> bool:
	# 兼容旧名
	return _any_combat_blocker_within(radius)

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
		# 精英/Boss 质量更大，不被小兵挤着滑
		var mass := 0.55
		if bool(def.get("boss", false)):
			mass = 0.12
		elif bool(def.get("elite", false)):
			mass = 0.22
		position += push * mass

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
	# CO-028：Boss 护甲相位（软克制，混编可解）
	if bool(def.get("phase_armor", false)):
		actual *= _boss_phase_mult(dmg_kind)
	if bool(def.get("armored", false)) and AudioController:
		AudioController.play("impact_heavy", global_position, 0.9)
	if from_fungus and _spore_timer > 0.0:
		actual *= 1.0 + Config.CARPET_SPORE_VULN
	if shield_hp > 0.0:
		var absorb: float = minf(shield_hp, actual)
		shield_hp -= absorb
		actual -= absorb
	hp -= actual
	if slow < 1.0:
		slow_factor = slow
		slow_timer = slow_time
	if hp <= 0.0 and alive:
		_die()
	elif alive and bool(def.get("boss", false)):
		_check_boss_half()

func _boss_phase_mult(dmg_kind: String) -> float:
	# 相位 0：近战硬；相位 1：远程硬；溅射中等
	match _armor_phase:
		0:
			match dmg_kind:
				"melee":
					return 0.48
				"splash":
					return 0.95
				"single", "aa", "ranged":
					return 1.08
				_:
					return 1.0
		_:
			match dmg_kind:
				"melee":
					return 1.08
				"splash":
					return 0.90
				"single", "aa", "ranged":
					return 0.55
				_:
					return 1.0

func _tick_boss(delta: float) -> void:
	if not bool(def.get("boss", false)) or not alive:
		return
	if bool(def.get("phase_armor", false)):
		_armor_phase_cd -= delta
		if _armor_phase_cd <= 0.0:
			_armor_phase = 1 - _armor_phase
			_armor_phase_cd = 9.0
			if _main != null and _main.hud != null:
				if _armor_phase == 0:
					_main.hud.set_status(tr("boss_phase_melee"))
				else:
					_main.hud.set_status(tr("boss_phase_ranged"))

func _check_boss_half() -> void:
	if _boss_half_done or max_hp <= 0.0:
		return
	if hp > max_hp * 0.5:
		return
	_boss_half_done = true
	speed = _base_speed * 1.10
	if _main == null:
		return
	# 一次增援 2 跑者（门禁：不刷 4+）
	_main.spawn_queue.append(1)
	_main.spawn_queue.append(1)
	_main.enemies_alive += 2
	if _main.hud != null:
		_main.hud.set_status(tr("boss_half_adds"))
	if AudioController:
		AudioController.play("impact_heavy", global_position)

func _tick_elite_aura(delta: float) -> void:
	var haste: float = float(def.get("aura_haste", 0.0))
	if haste <= 1.01:
		return
	_aura_tick -= delta
	if _aura_tick > 0.0 or _main == null:
		return
	_aura_tick = 0.35
	var layer: Node = _main.enemies_layer
	if layer == null:
		return
	var ar: float = float(def.get("aura_range", 70.0))
	for e in layer.get_children():
		if e == self or e == null or not is_instance_valid(e) or not e.alive:
			continue
		if position.distance_to(e.position) <= ar:
			e.slow_factor = maxf(float(e.slow_factor), haste)
			e.slow_timer = maxf(float(e.slow_timer), 0.45)

func apply_poison(dps: float, duration: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_timer = maxf(_poison_timer, duration)

func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_timer = maxf(_burn_timer, duration)

func apply_paralyze(duration: float) -> void:
	_paralyze_timer = maxf(_paralyze_timer, duration)

func apply_sleep(duration: float) -> void:
	_sleep_timer = maxf(_sleep_timer, duration)

## 移速乘子（1=正常；0.85=减速15%）；与菌毯等同通道，取更慢并延长计时
func apply_move_slow(speed_mult: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(speed_mult, 0.55, 1.0))
	slow_timer = maxf(slow_timer, duration)

func apply_freeze(duration: float) -> void:
	_frozen_timer = maxf(_frozen_timer, duration)

func mark_infected() -> void:
	if not infected:
		_infect_flash = 0.55
	infected = true
	queue_redraw()

func play_infect_flash() -> void:
	_infect_flash = 0.55
	queue_redraw()

func _die() -> void:
	if not alive:
		return
	alive = false
	if selected and _main != null and _main.get("selected_enemy") == self:
		if _main.has_method("_deselect_enemy"):
			_main._deselect_enemy()
	if _sprite_view != null and _sprite_view.has_method("play_death"):
		_sprite_view.play_death()
	if infected or (_main != null and bool(_main.get("spore_burst_active"))):
		_spread_infection()
		if _main != null and _main.has_method("notify_fungus_infect_burst"):
			_main.notify_fungus_infect_burst(global_position)
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
	if selected:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 10.0, 0.0, TAU, 40, Color(1.0, 0.55, 0.25, 0.95), 2.5, true)
	var eid: int = int(def.get("id", 0))
	if _attack_flash > 0.0:
		var a: float = _attack_flash / 0.16
		draw_line(Vector2.ZERO, _attack_line_to, Color(1.0, 0.45, 0.35, 0.85 * a), 2.5, true)
		draw_circle(_attack_line_to, 5.0, Color(1.0, 0.55, 0.25, 0.7 * a))
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 4.0, Color(1.0, 0.9, 0.9, 0.5 * (_hit_flash / 0.16)))
	if not _uses_pixel_sprite():
		_draw_body(eid)
	# CO-014：踩毯入场闪 + 持续绿环/脚底孢子点
	if _carpet_enter_flash > 0.0:
		var ca: float = _carpet_enter_flash / 0.6
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 10.0 * ca, Color(0.35, 0.95, 0.25, 0.35 * ca))
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 12.0 * ca, 0.0, TAU, 28, Color(0.55, 1.0, 0.35, 0.85 * ca), 3.0, true)
	if _was_on_carpet or (_main != null and _main.has_method("is_on_carpet") and _main.is_on_carpet(position)):
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 8.0, 0.0, TAU, 24, Color(0.35, 0.9, 0.2, 0.75), 2.4, true)
		draw_circle(Vector2(0, Config.ENEMY_RADIUS * 0.7), 3.5, Color(0.4, 0.95, 0.3, 0.65))
		draw_circle(Vector2(-5, Config.ENEMY_RADIUS * 0.55), 2.5, Color(0.55, 1.0, 0.4, 0.5))
		draw_circle(Vector2(5, Config.ENEMY_RADIUS * 0.55), 2.5, Color(0.55, 1.0, 0.4, 0.5))
	if infected:
		var ip: float = 0.55 + 0.45 * sin(_infect_pulse * 7.0)
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 6.0, 0.0, TAU, 24, Color(0.7, 1.0, 0.2, 0.7 * ip), 2.2, true)
		for i in range(3):
			var ang := _infect_pulse * 3.0 + float(i) * TAU / 3.0
			var p := Vector2(cos(ang), sin(ang)) * (Config.ENEMY_RADIUS + 9.0)
			draw_circle(p, 2.8, Color(0.85, 1.0, 0.35, 0.85 * ip))
	if _infect_flash > 0.0:
		var ia: float = _infect_flash / 0.55
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 14.0 * ia, Color(0.75, 1.0, 0.25, 0.4 * ia))
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 16.0 * ia, 0.0, TAU, 28, Color(0.95, 1.0, 0.4, 0.9 * ia), 3.5, true)
	if _poison_timer > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 3.0, Color(0.35, 0.85, 0.2, 0.35))
	if _spore_timer > 0.0:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 5.0, 0.0, TAU, 16, Color(0.55, 0.95, 0.35, 0.55), 1.4, true)
	if _burn_timer > 0.0:
		draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 2.0, Color(1.0, 0.45, 0.1, 0.4))
	if _paralyze_timer > 0.0 or _frozen_timer > 0.0:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 6.0, 0.0, TAU, 24, Color(0.55, 0.85, 1.0, 0.65), 2.0, true)
	if _sleep_timer > 0.0:
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 7.0, 0.0, TAU, 24, Color(0.72, 0.55, 1.0, 0.7), 2.2, true)
		draw_circle(Vector2(8.0, -Config.ENEMY_RADIUS - 4.0), 2.2, Color(0.85, 0.7, 1.0, 0.85))
		draw_circle(Vector2(12.0, -Config.ENEMY_RADIUS - 9.0), 1.6, Color(0.75, 0.6, 1.0, 0.7))
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
	elif eid == 4:
		bar_col = Color(1.0, 0.55, 0.2)
	elif eid == 5:
		bar_col = Color(0.75, 0.4, 1.0)
	draw_rect(Rect2(-w * 0.5, bar_y, w * fill, 4.0), bar_col)
	if max_shield > 0.0 and shield_hp > 0.0:
		var sf: float = clampf(shield_hp / max_shield, 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5, bar_y - 5.0, w, 3.0), Color(0.1, 0.12, 0.2, 0.85))
		draw_rect(Rect2(-w * 0.5, bar_y - 5.0, w * sf, 3.0), Color(0.45, 0.85, 1.0))
	# 铁皮：护甲板外圈提示
	if eid == 3 and bool(def.get("armored", false)):
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 5.0, 0.0, TAU, 20, Color(0.85, 0.88, 0.92, 0.55), 2.0, true)
	if bool(def.get("elite", false)):
		var ring_col := Color(1.0, 0.85, 0.25, 0.75)
		if bool(def.get("boss", false)):
			ring_col = Color(1.0, 0.25, 0.35, 0.9)
			draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 11.0, 0.0, TAU, 32, ring_col, 3.0, true)
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 8.0, 0.0, TAU, 28, ring_col, 2.2, true)
		draw_circle(Vector2(0, -Config.ENEMY_RADIUS - 12.0), 3.5, ring_col)
	if bool(def.get("phase_armor", false)):
		var pc := Color(0.95, 0.55, 0.2, 0.7) if _armor_phase == 0 else Color(0.35, 0.75, 1.0, 0.7)
		draw_arc(Vector2.ZERO, Config.ENEMY_RADIUS + 14.0, 0.0, TAU, 24, pc, 2.0, true)

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
		4:  # Siege Herald: 大八角+冠
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 4.0, Color(col, 0.35))
			for i in range(8):
				var a0 := float(i) * TAU / 8.0
				var a1 := float(i + 1) * TAU / 8.0
				draw_line(Vector2(cos(a0), sin(a0)) * (Config.ENEMY_RADIUS + 2.0), Vector2(cos(a1), sin(a1)) * (Config.ENEMY_RADIUS + 2.0), col, 3.5, true)
			draw_circle(Vector2.ZERO, 7.0, col)
		5:  # Night Courier: 菱形疾影
			var diamond := PackedVector2Array([Vector2(14, 0), Vector2(0, -10), Vector2(-10, 0), Vector2(0, 10)])
			draw_colored_polygon(diamond, col)
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, Color(0.8, 0.5, 1.0, 0.45), 1.5, true)
		6:  # Rampart Maw Boss: 双颚
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 6.0, Color(col, 0.4))
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS + 2.0, col)
			draw_rect(Rect2(-14, -4, 12, 8), Color(0.15, 0.05, 0.08))
			draw_rect(Rect2(2, -4, 12, 8), Color(0.15, 0.05, 0.08))
			draw_circle(Vector2(-6, 0), 3.0, Color(1.0, 0.85, 0.3))
			draw_circle(Vector2(6, 0), 3.0, Color(1.0, 0.85, 0.3))
		7:  # Sky Raider: 飞翼菱形 + 阴影
			draw_circle(Vector2(0, 10), 6.0, Color(0, 0, 0, 0.25))
			var wing_l := PackedVector2Array([Vector2(-4, 0), Vector2(-18, -6), Vector2(-6, 4)])
			var wing_r := PackedVector2Array([Vector2(4, 0), Vector2(18, -6), Vector2(6, 4)])
			draw_colored_polygon(wing_l, Color(col, 0.85))
			draw_colored_polygon(wing_r, Color(col, 0.85))
			draw_circle(Vector2(0, -2), 7.0, col)
			draw_circle(Vector2(-2, -3), 1.5, Color(1, 1, 1, 0.9))
			draw_circle(Vector2(2, -3), 1.5, Color(1, 1, 1, 0.9))
		_:
			draw_circle(Vector2.ZERO, Config.ENEMY_RADIUS, col)
