# 四族单位：可移动、自动索敌、种族差异化行为与视觉
extends Node2D

signal died

var def: Dictionary = {}
var race := "human"
var segment := 1
var invested := 0
var hp := 1.0
var max_hp := 1.0
var home: Vector2 = Vector2.ZERO
var selected := false
var cooldown := 0.0
var as_buff := 1.0
var buff_timer := 0.0
var aura_active := false
var dead := false
var _enemies: Node2D = null
var _projectiles: Node2D = null
var _units: Node2D = null
var _main: Node = null
var _combat := false
var _locked: Node = null
var _attack_flash := 0.0
var _hit_flash := 0.0
var _shot_line_to := Vector2.ZERO
var _shot_line_timer := 0.0
var _muzzle_timer := 0.0
var _muzzle_local := Vector2.ZERO
var _charge := 0.0
var _shield_hp := 0.0
var _shield_timer := 0.0
var _paralyze_cd := 0.0
var _aura_tick := 0.0
var _burn_line_to := Vector2.ZERO
var _burn_line_timer := 0.0
var _regen_timer := 0.0
var _chain_bonus := 1.0
var split_tier := 0
var _split_timer := 0.0
var _sprite_view: Node2D = null
var _prev_pos := Vector2.ZERO
# CO-011：农民进补给站干活
var _depot: Node = null
var _depot_slot := 0
var _working := false
var _supply_timer := 0.0
var depot_stock := 0
var mana := 0.0
var max_mana := 0.0
var _heal_flash := 0.0
var _heal_line_to := Vector2.ZERO
var _heal_line_timer := 0.0

func setup(u_def: Dictionary, enemies: Node2D, projectiles: Node2D, units: Node2D, main: Node = null, p_race: String = "human", p_split_tier: int = 0) -> void:
	def = u_def
	race = p_race
	_enemies = enemies
	_projectiles = projectiles
	_units = units
	_main = main
	split_tier = p_split_tier
	segment = int(def.get("segment", 1))
	invested = int(def["cost"])
	_apply_split_tier_stats()
	hp = max_hp
	home = position
	_prev_pos = position
	_maybe_spawn_sprite_view()
	if Config.is_farmer(def):
		_supply_timer = Config.FARMER_SUPPLY_INTERVAL * 0.5
		_seek_depot()
	if Config.is_depot(def):
		depot_stock = Config.DEPOT_STOCK_MAX
	if str(def.get("kind", "")) == "healer":
		max_mana = float(def.get("mana_max", 100.0))
		mana = max_mana
	if def.get("kind", "") == "burst":
		_shield_hp = max_hp * float(def.get("shield_hp_ratio", 0.4))
		_shield_timer = float(def.get("shield_duration", 3.0))

func _maybe_spawn_sprite_view() -> void:
	var tex: Texture2D = UnitSprites.load_texture(race, int(def.get("id", -1)))
	if tex == null:
		_clear_sprite_view()
		return
	if _sprite_view != null and is_instance_valid(_sprite_view):
		if _sprite_view.has_method("setup"):
			_sprite_view.setup(tex, str(def.get("kind", "")), float(def["radius"]), race, _is_stationary(), int(def.get("id", -1)))
		return
	_clear_sprite_view()
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	if script == null:
		return
	_sprite_view = Node2D.new()
	_sprite_view.set_script(script)
	add_child(_sprite_view)
	if _sprite_view.has_method("setup"):
		_sprite_view.setup(tex, str(def.get("kind", "")), float(def["radius"]), race, _is_stationary(), int(def.get("id", -1)))
	else:
		_clear_sprite_view()

func _uses_pixel_sprite() -> bool:
	if _sprite_view == null or not is_instance_valid(_sprite_view):
		return false
	return _sprite_view.has_method("has_sprite") and _sprite_view.has_sprite()

func _clear_sprite_view() -> void:
	if _sprite_view != null and is_instance_valid(_sprite_view):
		_sprite_view.queue_free()
	_sprite_view = null

func evolve() -> bool:
	var next_id: int = int(def.get("evolves_to", -1))
	if next_id < 0:
		return false
	var next_def: Dictionary = Config.evolve_next(race, next_id)
	if next_def.is_empty():
		return false
	invested += Config.evolve_cost(def, segment)
	def = next_def
	segment = int(def["segment"])
	max_hp = float(def["hp"])
	hp = max_hp
	_clear_sprite_view()
	_maybe_spawn_sprite_view()
	queue_redraw()
	return true

func evolve_cost() -> int:
	if int(def.get("evolves_to", -1)) < 0:
		return 0
	return Config.evolve_cost(def, segment)

func sell_value() -> int:
	return Config.sell_value(invested)

func split_power_mult() -> float:
	if race != "fungus":
		return 1.0
	return pow(Config.FUNGUS_SPLIT_ATTACK_MULT, float(split_tier))

func _attack_power_mult() -> float:
	return _chain_bonus * split_power_mult()

func effective_damage() -> float:
	return float(def["damage"]) * _attack_power_mult()

func effective_rate() -> float:
	return float(def["rate"]) * as_buff * (1.15 if aura_active else 1.0)

func effective_poison_dps() -> float:
	return float(def.get("poison_dps", 0.0)) * split_power_mult()

func can_split() -> bool:
	return race == "fungus" and split_tier < Config.FUNGUS_SPLIT_MAX and not dead

func _apply_split_tier_stats() -> void:
	var hp_mult: float = 1.0
	if race == "fungus":
		hp_mult = pow(Config.FUNGUS_SPLIT_HP_MULT, float(split_tier))
	max_hp = float(def["hp"]) * hp_mult

func after_bud_as_parent() -> void:
	if not can_split():
		return
	split_tier += 1
	_apply_split_tier_stats()
	hp = minf(hp, max_hp)
	_split_timer = Config.FUNGUS_SPLIT_INTERVAL
	queue_redraw()

func _try_auto_bud() -> void:
	if not can_split() or _main == null:
		return
	var spot: Vector2 = _main.find_fungus_bud_spot(position, float(def["radius"]))
	if spot == Vector2.ZERO:
		_split_timer = Config.FUNGUS_SPLIT_INTERVAL * 0.5
		return
	_main.spawn_fungus_bud(self, spot)

func set_combat(b: bool) -> void:
	_combat = b
	if not _combat:
		cooldown = 0.0
		_charge = 0.0
	elif race == "fungus":
		_split_timer = Config.FUNGUS_SPLIT_FIRST_DELAY
	if _combat and def.get("kind", "") == "burst":
		_shield_hp = max_hp * float(def.get("shield_hp_ratio", 0.4))
		_shield_timer = float(def.get("shield_duration", 3.0))

func apply_attack_speed_buff(mult: float, duration: float) -> void:
	as_buff = mult
	buff_timer = duration

func apply_heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	_heal_flash = 0.22
	queue_redraw()

func apply_enemy_damage(dmg: float) -> void:
	if dead or _regen_timer > 0.0:
		return
	if bool(def.get("can_fly", false)):
		return
	var actual := dmg
	if def.get("kind", "") == "wall" and position.distance_to(home) < 8.0:
		actual *= 1.0 - float(def.get("damage_reduction", 0.5))
	if _shield_hp > 0.0:
		var absorbed: float = minf(_shield_hp, actual)
		_shield_hp -= absorbed
		actual -= absorbed
	_hit_flash = 0.18
	hp -= actual
	if hp <= 0.0:
		_on_death()

func _on_death() -> void:
	if dead:
		return
	var kind: String = def.get("kind", "")
	if kind == "explode":
		_explode_aoe()
		return
	if kind == "wall":
		dead = true
		hp = 0.0
		_regen_timer = float(def.get("regen_time", 10.0))
		# 晶壁再凝：不计永久战损
		queue_redraw()
		return
	_finish_death(true)

func _explode_aoe() -> void:
	if _enemies != null:
		var r: float = float(def.get("explode_radius", 60.0))
		var dmg: float = float(def.get("explode_damage", 80.0))
		for e in _enemies.get_children():
			if e.global_position.distance_to(global_position) <= r:
				e.apply_damage(dmg, 1.0, 0.0, false, "splash")
	_finish_death(true)

func _finish_death(do_free: bool) -> void:
	if Config.is_depot(def):
		eject_depot_workers()
	if race == "dragon" and _main != null and _main.has_method("queue_dragon_reincubate"):
		_main.queue_dragon_reincubate(def.duplicate(true), home)
		dead = true
		if do_free:
			queue_free()
		return
	dead = true
	died.emit()
	if do_free:
		queue_free()

func eject_depot_workers() -> void:
	if _units == null:
		return
	for u in _units.get_children():
		if u == self or u == null or not is_instance_valid(u):
			continue
		if u.get("_depot") == self and u.has_method("leave_depot"):
			u.leave_depot(true)

func refill_depot_stock() -> void:
	if Config.is_depot(def) and not dead:
		depot_stock = Config.DEPOT_STOCK_MAX
		queue_redraw()

func take_depot_stock(amount: int) -> int:
	if not Config.is_depot(def) or dead or amount <= 0:
		return 0
	var got: int = mini(amount, depot_stock)
	depot_stock -= got
	queue_redraw()
	return got

func leave_depot(from_destroy: bool = false) -> void:
	_depot = null
	_depot_slot = 0
	_working = false
	modulate = Color(1, 1, 1, 1)
	visible = true
	if from_destroy:
		home = position

func depot_worker_count() -> int:
	if _units == null:
		return 0
	var n := 0
	for u in _units.get_children():
		if u != null and is_instance_valid(u) and u.get("_depot") == self:
			n += 1
	return n

func _seek_depot() -> void:
	_depot = null
	_depot_slot = 0
	_working = false
	if _units == null:
		return
	var best: Node = null
	var best_d := INF
	var best_slot := 0
	for u in _units.get_children():
		if u == null or not is_instance_valid(u) or not Config.is_depot(u.def):
			continue
		if bool(u.get("dead")):
			continue
		var used: int = u.depot_worker_count() if u.has_method("depot_worker_count") else 0
		# 自己若已登记在该站，不算占额外位
		if u == _depot:
			used = maxi(0, used - 1)
		if used >= Config.DEPOT_SLOTS:
			continue
		var d: float = position.distance_to(u.position)
		if d < best_d:
			best_d = d
			best = u
			best_slot = used
	if best != null:
		_depot = best
		_depot_slot = best_slot

func _depot_work_pos() -> Vector2:
	if _depot == null or not is_instance_valid(_depot):
		return home
	return _depot.position + Config.depot_slot_offset(_depot_slot)

func _tick_farmer_logistics(delta: float) -> void:
	if _depot == null or not is_instance_valid(_depot) or bool(_depot.get("dead")):
		_seek_depot()
		_working = false
		modulate = Color(1, 1, 1, 1)
		visible = true
	if _depot == null:
		# 无站：停在放置点，不产补给
		if position.distance_to(home) > 2.0:
			position = position.move_toward(home, Config.FARMER_SPEED * delta)
		return
	var target: Vector2 = _depot_work_pos()
	if not _working:
		position = position.move_toward(target, Config.FARMER_SPEED * delta)
		if position.distance_to(target) <= Config.DEPOT_ENTER_DIST:
			_working = true
			position = target
			home = target
			# 「进站」：半透明叠在工位上
			modulate = Color(1, 1, 1, 0.55)
		return
	position = target
	_supply_timer -= delta
	if _supply_timer <= 0.0:
		_supply_timer = Config.FARMER_SUPPLY_INTERVAL
		if _main == null or not _main.has_method("add_supply"):
			return
		# 玩家库存已满，或站内库存空 → 停产
		if int(_main.supply) >= Config.MAX_SUPPLY:
			return
		if _depot == null or not _depot.has_method("take_depot_stock"):
			return
		var want: int = Config.FARMER_SUPPLY_AMOUNT
		var room: int = Config.MAX_SUPPLY - int(_main.supply)
		want = mini(want, room)
		var got: int = _depot.take_depot_stock(want)
		if got > 0:
			_main.add_supply(got)

var _aura_check := 0.0
func _physics_process(delta: float) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			hp = max_hp
			dead = false
			_hit_flash = 0.0
		queue_redraw()
		return
	if dead:
		return
	if Config.is_farmer(def):
		_tick_farmer_logistics(delta)
		var moved_f: float = position.distance_to(_prev_pos)
		if _sprite_view != null and _sprite_view.has_method("set_moving"):
			_sprite_view.set_moving(moved_f > 0.5 and not _working)
		if _sprite_view != null and moved_f > 0.5 and not _working and _sprite_view.has_method("set_facing_toward"):
			_sprite_view.set_facing_toward(global_position + (position - _prev_pos).normalized() * 32.0)
		_prev_pos = position
		queue_redraw()
		return
	if _heal_flash > 0.0:
		_heal_flash -= delta
	if _heal_line_timer > 0.0:
		_heal_line_timer -= delta
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			as_buff = 1.0
	if _shield_timer > 0.0:
		_shield_timer -= delta
	_aura_check -= delta
	if _aura_check <= 0.0:
		_aura_check = 0.5
		_update_aura_state()
	_update_chain_bonus()
	cooldown -= delta
	if _attack_flash > 0.0:
		_attack_flash -= delta
	if _hit_flash > 0.0:
		_hit_flash -= delta
	if _shot_line_timer > 0.0:
		_shot_line_timer -= delta
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
	if _burn_line_timer > 0.0:
		_burn_line_timer -= delta
	if _paralyze_cd > 0.0:
		_paralyze_cd -= delta
	var combat_target: Node = null
	if _combat:
		_tick_fungus_carpet(delta)
		if race == "fungus" and can_split():
			_split_timer -= delta
			if _split_timer <= 0.0:
				_try_auto_bud()
		if str(def.get("kind", "")) == "healer":
			_tick_healer(delta)
		else:
			combat_target = _acquire_target()
			if combat_target != null:
				if _uses_pixel_sprite() and _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
					_sprite_view.set_facing_toward(combat_target.global_position)
				else:
					rotation = lerp_angle(rotation, position.angle_to_point(combat_target.position), minf(1.0, 10.0 * delta))
				_do_move_or_attack(combat_target, delta)
			else:
				_return_home(delta)
	else:
		_return_home(delta)
	var moved: float = position.distance_to(_prev_pos)
	if _sprite_view != null:
		var moving: bool = moved > maxf(0.8, float(def["speed"]) * delta * 0.35)
		var atk: bool = _sprite_view.has_method("is_attacking") and _sprite_view.is_attacking()
		if _sprite_view.has_method("set_moving"):
			_sprite_view.set_moving(moving and not atk)
		# 有战斗目标时保持面朝目标；无目标才按移动方向转身
		if combat_target == null and moving and not atk and _sprite_view.has_method("set_facing_toward"):
			var vel: Vector2 = position - _prev_pos
			if vel.length_squared() > 0.0001:
				_sprite_view.set_facing_toward(global_position + vel.normalized() * 32.0)
		if _uses_pixel_sprite():
			z_index = UnitSprites.depth_z(position.y)
	_prev_pos = position
	queue_redraw()

func _tick_healer(delta: float) -> void:
	# 蓝量回复（战斗中）
	mana = minf(max_mana, mana + float(def.get("mana_regen", 6.0)) * delta)
	var ally: Node = _acquire_heal_target()
	if ally == null:
		_return_home(delta)
		_apply_friendly_sep(delta)
		return
	if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
		_sprite_view.set_facing_toward(ally.global_position)
	else:
		rotation = lerp_angle(rotation, position.angle_to_point(ally.position), minf(1.0, 10.0 * delta))
	var reach: float = float(def.get("range", 155.0))
	var dist: float = position.distance_to(ally.position)
	if dist > reach:
		position = position.move_toward(ally.position, float(def["speed"]) * delta)
		_apply_friendly_sep(delta)
		return
	var cost: float = float(def.get("mana_cost", 20.0))
	if cooldown <= 0.0 and mana >= cost:
		mana -= cost
		ally.apply_heal(float(def.get("heal_amount", 50.0)))
		_heal_line_to = ally.position - position
		_heal_line_timer = 0.3
		_attack_flash = 0.14
		cooldown = 1.0 / maxf(0.1, effective_rate())
	_apply_friendly_sep(delta)

func _acquire_heal_target() -> Node:
	if _units == null:
		return null
	var best: Node = null
	var best_score := -INF
	var chase: float = float(def.get("range", 155.0)) + 90.0
	for u in _units.get_children():
		if u == self or u == null or not is_instance_valid(u):
			continue
		if bool(u.get("dead")):
			continue
		if Config.is_depot(u.def):
			continue
		var uhp: float = float(u.hp)
		var umax: float = float(u.max_hp)
		if umax <= 0.0 or uhp >= umax - 0.5:
			continue
		var d: float = position.distance_to(u.position)
		if d > chase:
			continue
		var missing: float = 1.0 - uhp / umax
		var score: float = missing * 100000.0 - d
		if score > best_score:
			best_score = score
			best = u
	return best

func _update_aura_state() -> void:
	aura_active = false
	if _units == null or def.get("kind", "") == "aura":
		return
	if race != "human":
		return
	for u in _units.get_children():
		if u == self or u.def.get("kind", "") != "aura":
			continue
		if position.distance_to(u.position) <= float(u.def.get("aura_range", 170.0)):
			aura_active = true
			break

func _update_chain_bonus() -> void:
	if race != "silicon" or _units == null:
		_chain_bonus = 1.0
		return
	var links := 0
	for u in _units.get_children():
		if u == self:
			continue
		if position.distance_to(u.position) <= Config.SILICON_LINK_RANGE:
			links += 1
	_chain_bonus = 1.0 + float(links) * Config.SILICON_CHAIN_BONUS

func _tick_fungus_carpet(delta: float) -> void:
	if race != "fungus" or def.get("kind", "") != "aura":
		return
	if _main != null:
		_main.boost_carpet_at(position, float(def.get("carpet_grow_mult", 1.35)))
	_aura_tick -= delta
	if _aura_tick > 0.0 or _enemies == null:
		return
	_aura_tick = float(def.get("aura_tick_interval", 0.8))
	var ar: float = float(def.get("aura_range", 55.0))
	var extra_slow: float = float(def.get("aura_slow", Config.CARPET_AURA_SLOW))
	for e in _enemies.get_children():
		if e.position.distance_to(position) <= ar:
			e.apply_carpet_aura(extra_slow)

func _is_stationary() -> bool:
	return bool(def.get("stationary", false)) or race == "fungus"

func _is_ranged_kind() -> bool:
	return def.get("kind", "") in ["single", "splash", "aa", "charge", "spike"]

func _do_move_or_attack(t: Node, delta: float) -> void:
	var kind: String = def.get("kind", "")
	if _is_stationary():
		if _can_hit(t.position) and cooldown <= 0.0:
			_perform_attack(t)
		return
	if kind == "fly":
		_do_fly(t, delta)
		return
	if kind in ["charge", "spike"]:
		_do_charge_attack(t, delta)
		return
	var chase: float = Config.MELEE_CHASE if kind in ["melee", "wall", "burst", "explode"] else Config.RANGED_CHASE
	var reach: float = _attack_reach()
	var dist: float = position.distance_to(t.position)
	if not _can_hit(t.position):
		if kind in ["melee", "wall", "burst", "explode"]:
			if _should_intercept_march(t, dist):
				position = position.move_toward(t.position, float(def["speed"]) * delta)
			elif dist <= reach + chase:
				position = position.move_toward(t.position, float(def["speed"]) * delta)
			else:
				_return_home(delta)
		else:
			if _is_ranged_kind() and dist <= _aggro_range():
				pass
			else:
				_return_home(delta)
		_apply_friendly_sep(delta)
		return
	if cooldown <= 0.0:
		if _sprite_view != null and is_instance_valid(_sprite_view) and _sprite_view.has_method("is_attacking") and _sprite_view.is_attacking():
			_apply_friendly_sep(delta)
			return
		_perform_attack(t)
	_apply_friendly_sep(delta)

func _apply_fly_strike(t: Node) -> void:
	if not is_instance_valid(t):
		return
	t.apply_damage(effective_damage(), 1.0, 0.0, race == "fungus", "melee")
	t.apply_burn(float(def.get("burn_dps", 8.0)), float(def.get("burn_duration", 5.0)))

func _do_fly(t: Node, delta: float) -> void:
	var dist: float = position.distance_to(t.position)
	var reach: float = _attack_reach()
	if dist > reach:
		position = position.move_toward(t.position, float(def["speed"]) * delta)
	elif cooldown <= 0.0:
		if _sprite_view != null and _sprite_view.has_method("start_attack"):
			_sprite_view.start_attack(_apply_fly_strike.bind(t))
		else:
			_apply_fly_strike(t)
		_burn_line_to = t.position - position
		_burn_line_timer = 0.2
		_attack_flash = 0.12
		cooldown = 1.0 / max(0.1, float(def["rate"]) * as_buff)

func _do_charge_attack(t: Node, delta: float) -> void:
	var moving: bool = position.distance_to(home) > 6.0 or position.distance_to(t.position) > _attack_reach() + 10.0
	if moving:
		_charge = 0.0
		if not _can_hit(t.position):
			_return_home(delta)
		return
	if not _can_hit(t.position):
		return
	_charge += delta
	var need: float = float(def.get("charge_time", 3.0))
	if _charge >= need and cooldown <= 0.0:
		var dmg: float = effective_damage()
		if def.get("kind", "") == "spike" and int(t.def.get("id", -1)) == 1:
			dmg *= 1.35
		if def.get("kind", "") == "spike":
			_fire(t, dmg)
		else:
			if _sprite_view != null and _sprite_view.has_method("start_attack"):
				_sprite_view.start_attack(_deal_enemy_damage.bind(t, dmg))
			else:
				_deal_enemy_damage(t, dmg)
		_attack_flash = 0.16
		_charge = 0.0
		cooldown = 1.0 / max(0.1, float(def["rate"]) * as_buff)

func _deal_enemy_damage(t: Node, dmg: float, slow: float = 1.0, slow_time: float = 0.0, dmg_kind: String = "") -> void:
	var dk: String = dmg_kind
	if dk.is_empty():
		var k: String = str(def.get("kind", "generic"))
		if k in ["melee", "wall", "burst", "explode", "fly"]:
			dk = "melee"
		elif k == "splash":
			dk = "splash"
		elif k in ["single", "aa", "spike"]:
			dk = k if k != "spike" else "single"
		else:
			dk = "generic"
	t.apply_damage(dmg, slow, slow_time, race == "fungus", dk)

func _apply_melee_strike(t: Node) -> void:
	if not is_instance_valid(t):
		return
	var dmg: float = effective_damage()
	_deal_enemy_damage(t, dmg, 1.0, 0.0, "melee")
	if bool(def.get("apply_poison", false)):
		t.apply_poison(effective_poison_dps(), float(def.get("poison_duration", 4.0)))

func _apply_burst_strike(t: Node) -> void:
	if not is_instance_valid(t):
		return
	var dmg: float = effective_damage()
	_deal_enemy_damage(t, dmg, 1.0, 0.0, "melee")
	t.apply_burn(float(def.get("burn_dps", 12.0)), float(def.get("burn_duration", 8.0)))

func _perform_attack(t: Node) -> void:
	var kind: String = def.get("kind", "")
	var rate: float = effective_rate()
	var dmg: float = effective_damage()
	match kind:
		"melee", "wall", "explode":
			if _sprite_view != null and _sprite_view.has_method("start_attack"):
				_attack_flash = 0.14
				cooldown = 1.0 / max(0.1, rate)
				_sprite_view.start_attack(_apply_melee_strike.bind(t))
				return
			_apply_melee_strike(t)
			_attack_flash = 0.14
		"burst":
			if _sprite_view != null and _sprite_view.has_method("start_attack"):
				_attack_flash = 0.14
				cooldown = 1.0 / max(0.1, rate)
				_sprite_view.start_attack(_apply_burst_strike.bind(t))
				return
			_apply_burst_strike(t)
			_attack_flash = 0.14
		"single":
			if race == "fungus" and _paralyze_cd <= 0.0:
				t.apply_paralyze(float(def.get("paralyze_duration", 2.5)))
				_paralyze_cd = float(def.get("paralyze_cd", 3.0))
			if _sprite_view != null and _sprite_view.has_method("start_shoot"):
				_sprite_view.start_shoot()
			_fire(t, dmg)
			_attack_flash = 0.12
		"splash", "aa":
			if _sprite_view != null and _sprite_view.has_method("start_shoot"):
				_sprite_view.start_shoot()
			_fire(t, dmg)
			_attack_flash = 0.12
		"aura", "healer":
			pass
	cooldown = 1.0 / max(0.1, rate)

func _apply_friendly_sep(_delta: float) -> void:
	if _is_stationary() or _units == null:
		return
	var min_d: float = float(def["radius"]) * 2.0 + 6.0
	var push := Vector2.ZERO
	for u in _units.get_children():
		if u == self:
			continue
		var diff: Vector2 = position - u.position
		var d: float = diff.length()
		if d < min_d and d > 0.001:
			push += diff.normalized() * (min_d - d)
	if push.length_squared() > 0.0:
		position += push * 0.35

func _attack_reach() -> float:
	var kind: String = def.get("kind", "")
	if kind == "melee" and _is_stationary():
		return float(def.get("range", 50.0))
	if kind in ["melee", "wall", "burst", "explode"]:
		return 22.0 if kind != "wall" else 26.0
	return float(def["range"])

func _ranged_standoff() -> float:
	return maxf(0.0, Config.dist_to_path(position) - Config.PATH_HALF_WIDTH - float(def["radius"]))

func _effective_range() -> float:
	var kind: String = def.get("kind", "")
	if kind in ["melee", "wall", "burst", "explode"]:
		return _attack_reach()
	if kind == "fly":
		return float(def["range"])
	return _attack_reach() + _ranged_standoff() + Config.RANGED_COMBAT_BONUS

func _can_hit(pos: Vector2) -> bool:
	if race == "fungus" and _main != null and _main.is_on_carpet(pos):
		return true
	var kind: String = def.get("kind", "")
	var d: float = position.distance_to(pos)
	if kind in ["melee", "wall", "burst", "explode"]:
		return d <= _attack_reach()
	return d <= _effective_range()

func _return_home(delta: float) -> void:
	if _is_stationary():
		return
	if position.distance_to(home) > 2.0:
		position = position.move_toward(home, float(def["speed"]) * delta)

func _acquire_target() -> Node:
	var kind: String = def.get("kind", "")
	if kind == "farmer" or kind == "depot" or kind == "healer":
		return null
	if kind == "aura" and race == "fungus":
		return null
	var chase: float = Config.MELEE_CHASE if kind in ["melee", "wall", "burst", "explode", "fly"] else Config.RANGED_CHASE
	var lock_range: float = _aggro_range() + chase + 20.0
	if kind in ["melee", "wall", "burst", "explode"]:
		lock_range = _aggro_range() + chase + 20.0
	if _locked != null and is_instance_valid(_locked) and _locked.is_inside_tree():
		var dist_locked: float = position.distance_to(_locked.position)
		if dist_locked <= lock_range:
			if _can_hit(_locked.position):
				return _locked
			if _is_ranged_kind() and dist_locked <= _aggro_range():
				return _locked
			if race == "fungus" and _main != null and _main.is_on_carpet(_locked.position):
				return _locked
	_locked = _scan_target()
	return _locked

func _aggro_range() -> float:
	if def.get("kind", "") in ["melee", "wall", "burst", "explode"]:
		return Config.MELEE_AGGRO_RANGE
	if def.get("kind", "") == "fly":
		return 400.0
	if _is_ranged_kind():
		return _effective_range() + Config.RANGED_AGGRO_EXTRA
	return _effective_range()

func _should_intercept_march(t: Node, dist: float) -> bool:
	if dist > Config.MELEE_AGGRO_RANGE:
		return false
	if home.distance_to(position) >= Config.MELEE_INTERCEPT_LEASH:
		return false
	if Config.dist_to_path(t.position) <= Config.PATH_HALF_WIDTH + 8.0:
		return true
	return dist <= 22.0 + Config.MELEE_CHASE + 5.0

func _scan_target() -> Node:
	var best: Node = null
	var best_score := -INF
	var aggro: float = _aggro_range()
	for e in _enemies.get_children():
		if _is_stationary():
			if not _can_hit(e.position):
				continue
		elif def.get("kind", "") in ["melee", "wall", "burst", "explode"]:
			if e.position.distance_to(position) > aggro:
				continue
		elif def.get("kind", "") == "fly":
			if e.position.distance_to(position) > aggro:
				continue
		elif _is_ranged_kind():
			if e.position.distance_to(position) > aggro:
				continue
		elif not _can_hit(e.position):
			continue
		var score: float = _target_score(e)
		if score > best_score:
			best_score = score
			best = e
	return best

func _target_score(e: Node) -> float:
	var d: float = e.position.distance_to(position)
	var on_carpet: float = 120000.0 if race == "fungus" and _main != null and _main.is_on_carpet(e.position) else 0.0
	var pts: Array[Vector2] = Config.PATH_POINTS
	var prog: float = float(e.waypoint_index) * 10000.0 - float(e.position.distance_to(pts[min(e.waypoint_index, pts.size() - 1)]))
	match def.get("kind", ""):
		"splash":
			var ss: float = _splash_score(e, d) + on_carpet
			if int(e.def.get("id", -1)) == 3:
				ss += 60000.0  # 铁皮怕溅射
			return ss
		"aa", "spike":
			var s: float = 100000.0 - d
			if int(e.def.get("id", -1)) == 1:
				s += 80000.0
			return s
		"single":
			var s2: float = 100000.0 - d + on_carpet
			if _ally_melee_near(e.position, 90.0):
				s2 += 35000.0
			if int(e.def.get("id", -1)) == 3:
				s2 += 55000.0  # 火枪优先点铁皮
			return s2
		"melee", "wall", "explode", "burst":
			var ms: float = prog + on_carpet
			if int(e.def.get("id", -1)) == 3:
				ms -= 25000.0  # 近战少纠结刮铁皮
			return ms
		"fly":
			return 100000.0 - d + prog * 0.5
		"charge":
			if int(e.def.get("id", -1)) == 2:
				return 120000.0 - d
			return 100000.0 - d
		_:
			return prog

func _splash_score(e: Node, d: float) -> float:
	var splash_r: float = float(def.get("splash_radius", 70.0))
	var cluster := 0
	for o in _enemies.get_children():
		if o.global_position.distance_to(e.global_position) <= splash_r:
			cluster += 1
	return float(cluster) * 15000.0 - d

func _ally_melee_near(pos: Vector2, radius: float) -> bool:
	if _units == null:
		return false
	for u in _units.get_children():
		if u == self:
			continue
		var k: String = u.def.get("kind", "")
		if k not in ["melee", "wall", "explode"]:
			continue
		if u.position.distance_to(pos) <= radius:
			return true
	return false

func _projectile_speed() -> float:
	match def.get("kind", ""):
		"splash":
			return Config.PROJECTILE_SPEED_SPLASH
		"aa", "spike":
			return Config.PROJECTILE_SPEED_AA
		_:
			return Config.PROJECTILE_SPEED_SINGLE

func _muzzle_origin(aim_dir: Vector2) -> Vector2:
	var face_right: bool = aim_dir.x >= 0.0
	if _sprite_view != null and _sprite_view.has_method("facing_right"):
		face_right = bool(_sprite_view.facing_right())
	var local: Vector2 = UnitSprites.muzzle_local(face_right, float(def.get("radius", 11.0)))
	# 再沿瞄准方向略微前伸，避免贴着身体
	return global_position + local + aim_dir.normalized() * 6.0

func _fire(target: Node, dmg_override: float = -1.0) -> void:
	if _projectiles == null:
		return
	var dmg: float = effective_damage() if dmg_override < 0.0 else dmg_override
	var aim: Vector2 = target.global_position - global_position
	if aim.length_squared() < 0.0001:
		aim = Vector2.RIGHT
	var dir: Vector2 = aim.normalized()
	if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
		_sprite_view.set_facing_toward(target.global_position)
	var muzzle: Vector2 = _muzzle_origin(dir)
	# 弹道/枪线从枪口算起，指向目标
	var shot: Vector2 = target.global_position - muzzle
	if shot.length_squared() < 0.0001:
		shot = dir
	dir = shot.normalized()
	_muzzle_local = muzzle - global_position
	_shot_line_to = _muzzle_local + dir * minf(shot.length(), 90.0)
	_shot_line_timer = 0.38
	_muzzle_timer = 0.16
	if _sprite_view != null and _sprite_view.has_method("start_shoot"):
		_sprite_view.start_shoot()
	_spawn_muzzle_at(muzzle, dir)
	var p: Node = load("res://scripts/projectile.gd").new()
	_projectiles.add_child(p)
	p.global_position = muzzle
	var pk: String = "spore" if race == "fungus" else String(def["kind"])
	p.setup(self, _enemies, target, dmg, _projectile_speed(),
		float(def.get("splash_radius", 0.0)), 1.0, 0.0, Color(def["color"]), pk)
	if race == "fungus" and def.get("kind", "") == "splash":
		p.set_meta("infect_radius", float(def.get("infect_radius", 90.0)))

func _spawn_muzzle_at(pos: Vector2, dir: Vector2) -> void:
	if _projectiles == null:
		return
	var fx: Node = load("res://scripts/attack_vfx.gd").new()
	_projectiles.add_child(fx)
	fx.global_position = pos
	fx.play_muzzle(Color(def["color"]), dir)

func _draw() -> void:
	if def.is_empty():
		return
	if _regen_timer > 0.0:
		draw_circle(Vector2.ZERO, float(def["radius"]), Color(def["color"], 0.25))
		draw_arc(Vector2.ZERO, float(def["radius"]) + 4.0, 0.0, TAU, 24, Color(0.55, 0.85, 1.0, 0.5), 2.0, true)
		return
	var r: float = float(def["radius"])
	var kind: String = def.get("kind", "")
	if _combat:
		if kind == "healer":
			draw_arc(Vector2.ZERO, float(def.get("range", 155.0)), 0.0, TAU, 96, Color(0.45, 0.85, 1.0, 0.12), 1.0, true)
		elif kind == "aura" and race == "human":
			draw_arc(Vector2.ZERO, float(def.get("aura_range", 170.0)), 0.0, TAU, 96, Color(0.95, 0.95, 1.0, 0.1), 1.0, true)
		elif kind == "aura" and race == "fungus":
			draw_arc(Vector2.ZERO, float(def.get("aura_range", 55.0)), 0.0, TAU, 96, Color(0.35, 0.75, 0.2, 0.15), 1.0, true)
		elif kind not in ["melee", "wall", "burst", "explode", "aura", "healer", "farmer", "depot"]:
			draw_arc(Vector2.ZERO, _effective_range(), 0.0, TAU, 96, Color(def["color"].r, def["color"].g, def["color"].b, 0.1), 1.0, true)
			if float(def.get("range", 0.0)) > 0.0:
				draw_arc(Vector2.ZERO, float(def["range"]), 0.0, TAU, 96, Color(1, 1, 1, 0.18), 1.0, true)
	if _heal_line_timer > 0.0:
		var ha: float = _heal_line_timer / 0.3
		draw_line(Vector2.ZERO, _heal_line_to, Color(0.4, 0.95, 1.0, 0.85 * ha), 3.5, true)
		draw_circle(_heal_line_to, 8.0 * ha, Color(0.55, 1.0, 0.85, 0.65 * ha))
	if _heal_flash > 0.0:
		draw_circle(Vector2.ZERO, r + 5.0, Color(0.4, 1.0, 0.7, 0.45 * (_heal_flash / 0.22)))
	if _burn_line_timer > 0.0:
		var ba: float = _burn_line_timer / 0.2
		draw_line(Vector2.ZERO, _burn_line_to, Color(1.0, 0.45, 0.1, 0.85 * ba), 4.0, true)
	if _shot_line_timer > 0.0 and kind not in ["melee", "aura", "wall", "burst", "explode"]:
		var a: float = _shot_line_timer / 0.38
		draw_line(_muzzle_local, _shot_line_to, Color(def["color"].r, def["color"].g, def["color"].b, 0.75 * a), 5.0, true)
		draw_line(_muzzle_local, _shot_line_to, Color(1, 1, 1, 0.95 * a), 2.0, true)
		draw_circle(_muzzle_local, 5.0 * a, Color(1, 0.95, 0.6, 0.9 * a))
	if _muzzle_timer > 0.0:
		var ma: float = _muzzle_timer / 0.16
		draw_circle(_muzzle_local, 8.0 * ma, Color(1, 0.95, 0.7, 0.85 * ma))
	if _attack_flash > 0.0:
		var fa: float = _attack_flash / 0.14
		draw_arc(Vector2.ZERO, r + 6.0, 0.0, TAU, 32, Color(1.0, 0.92, 0.35, 0.75 * fa), 2.5, true)
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, r + 3.0, Color(1.0, 0.35, 0.35, 0.55 * (_hit_flash / 0.18)))
	if _shield_hp > 0.0:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 32, Color(1.0, 0.55, 0.15, 0.55), 2.0, true)
	if kind in ["charge", "spike"] and _charge > 0.0:
		var ca: float = clampf(_charge / float(def.get("charge_time", 3.0)), 0.0, 1.0)
		draw_arc(Vector2.ZERO, r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * ca, 32, Color(0.4, 0.9, 1.0, 0.8), 2.5, true)
	if not _uses_pixel_sprite():
		draw_circle(Vector2.ZERO, r, Color(def["color"]))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0, 0, 0, 0.4), 1.5, true)
	else:
		# 像素精灵仍画脚底占位，避免贴图过淡/失败时“部署了却看不见”
		draw_circle(Vector2(0, 2), r * 0.55, Color(0, 0, 0, 0.28))
		draw_circle(Vector2.ZERO, r * 0.35, Color(def["color"].r, def["color"].g, def["color"].b, 0.35))
	if _is_stationary():
		draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 20, Color(0.35, 0.65, 0.2, 0.45), 1.2, true)
	if race == "fungus" and split_tier > 0:
		for i in range(split_tier):
			var ang := PI * 0.25 + float(i) * TAU / float(max(split_tier, 1))
			draw_circle(Vector2(cos(ang) * r * 0.65, sin(ang) * r * 0.65), 2.2, Color(0.95, 0.98, 0.55))
	if not _uses_pixel_sprite():
		_draw_role_marker(kind, r)
	if race == "silicon" and _chain_bonus > 1.01:
		draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(0.35, 0.85, 1.0, 0.45), 1.5, true)
	for i in range(segment):
		var sa := -PI * 0.5 + float(i) * TAU / float(max(segment, 1))
		draw_circle(Vector2(cos(sa) * r * 0.45, sin(sa) * r * 0.45), 2.4, Color(1, 1, 0.8))
	if aura_active:
		draw_arc(Vector2.ZERO, r + 5.0, 0.0, TAU, 24, Color(1, 0.95, 0.6, 0.6), 1.5, true)
	var w := 26.0
	var fill := clampf(hp / max_hp, 0.0, 1.0)
	var bar_y := -r - (38.0 if _uses_pixel_sprite() else 12.0)
	draw_rect(Rect2(-w * 0.5, bar_y, w, 4.0), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(-w * 0.5, bar_y, w * fill, 4.0), Color(0.9, 0.85, 0.35))
	if kind == "healer" and max_mana > 0.0:
		var mf: float = clampf(mana / max_mana, 0.0, 1.0)
		var my: float = bar_y + 5.0
		draw_rect(Rect2(-w * 0.5, my, w, 3.5), Color(0.08, 0.1, 0.18, 0.85))
		draw_rect(Rect2(-w * 0.5, my, w * mf, 3.5), Color(0.35, 0.7, 1.0))
	if selected:
		var dr: float = _effective_range() if kind not in ["melee", "aura", "healer", "wall", "burst", "explode"] else 55.0
		if kind == "aura":
			dr = float(def.get("aura_range", 55.0))
		elif kind == "healer":
			dr = float(def.get("range", 155.0))
		draw_arc(Vector2.ZERO, dr, 0.0, TAU, 96, Color(1, 1, 1, 0.85), 1.5, true)

func _draw_role_marker(kind: String, r: float) -> void:
	var fwd := Vector2(cos(rotation), sin(rotation)) * r
	match kind:
		"melee":
			draw_line(fwd * 0.3, fwd * 1.6, Color(0.75, 0.85, 1.0, 0.9), 3.0, true)
		"single":
			draw_line(Vector2.ZERO, fwd * 1.8, Color(0.6, 0.75, 1.0, 0.95), 2.5, true)
		"splash":
			draw_circle(fwd * 0.5, 4.5, Color(0.3, 0.55, 0.12))
			draw_line(Vector2.ZERO, fwd * 1.2, Color(0.35, 0.5, 0.18), 4.0, true)
		"aa", "spike":
			draw_line(fwd * 0.8, fwd * 1.5, Color(0.85, 0.85, 0.9), 2.0, true)
		"aura":
			if race == "fungus":
				draw_circle(Vector2.ZERO, r * 0.4, Color(0.45, 0.75, 0.2))
			else:
				draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.5, true)
		"healer":
			draw_line(Vector2(0, -r * 0.9), Vector2(0, r * 0.9), Color(0.45, 0.85, 1.0), 3.0, true)
			draw_line(Vector2(-r * 0.7, 0), Vector2(r * 0.7, 0), Color(0.45, 0.85, 1.0), 3.0, true)
		"fly":
			var wing := Vector2(-fwd.y, fwd.x) * 0.5
			draw_line(-wing, wing, Color(1.0, 0.5, 0.2, 0.8), 2.5, true)
			draw_line(Vector2.ZERO, fwd * 1.4, Color(1.0, 0.35, 0.1), 3.0, true)
		"burst":
			draw_circle(fwd * 0.6, 5.0, Color(1.0, 0.55, 0.15))
		"explode":
			draw_rect(Rect2(-r * 0.6, -r * 0.6, r * 1.2, r * 1.2), Color(0.55, 0.1, 0.05), false, 2.5, true)
		"wall":
			draw_rect(Rect2(-r, -r * 0.7, r * 2.0, r * 1.4), Color(0.55, 0.75, 0.95, 0.5), false, 2.0, true)
		"farmer":
			draw_rect(Rect2(-r * 0.55, -r * 0.35, r * 1.1, r * 0.7), Color(0.7, 0.55, 0.2, 0.85), true)
			draw_line(Vector2(0, -r * 0.2), Vector2(0, -r * 1.1), Color(0.45, 0.35, 0.15), 2.5, true)
		"depot":
			draw_rect(Rect2(-r * 0.9, -r * 0.75, r * 1.8, r * 1.5), Color(0.35, 0.5, 0.22, 0.9), true)
			draw_rect(Rect2(-r * 0.9, -r * 0.75, r * 1.8, r * 1.5), Color(0.15, 0.25, 0.1, 0.9), false, 2.0, true)
			draw_rect(Rect2(-r * 0.35, -r * 0.15, r * 0.7, r * 0.9), Color(0.25, 0.2, 0.12, 0.95), true)
			# 站内库存条
			var ratio: float = clampf(float(depot_stock) / float(Config.DEPOT_STOCK_MAX), 0.0, 1.0)
			var bar_w: float = r * 1.6
			draw_rect(Rect2(-bar_w * 0.5, r + 4.0, bar_w, 4.0), Color(0.1, 0.1, 0.1, 0.7), true)
			draw_rect(Rect2(-bar_w * 0.5, r + 4.0, bar_w * ratio, 4.0), Color(0.55, 0.9, 0.35, 0.95), true)
		"charge":
			draw_circle(fwd * 0.8, 4.0, Color(0.3, 0.9, 1.0))
