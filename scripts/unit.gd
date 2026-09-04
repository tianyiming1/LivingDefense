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
var dmg_buff := 1.0
var dmg_buff_timer := 0.0
var aura_active := false
var dead := false
var _enemies: Node2D = null
var _projectiles: Node2D = null
var _units: Node2D = null
var _main: Node = null
var _combat := false
var _locked: Node = null
var _assist_timer := 0.0
var _assist_call_cd := 0.0
## CO-042：玩家指令 move | attack_move | attack_target
var _order := ""
var _order_pos := Vector2.ZERO
var _order_target: Node = null
var _order_marker_timer := 0.0
## CO-046：移动播飞（默认）或走（Shift）
var _order_fly := true
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
var _sleep_cd := 0.0
var _aura_tick := 0.0
var _burn_line_to := Vector2.ZERO
var _burn_line_timer := 0.0
var _regen_timer := 0.0
var _chain_bonus := 1.0
var _chain_links: Array[Vector2] = []
var split_tier := 0
var _split_timer := 0.0
var _split_flash := 0.0
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
var _dream_ally_flash := 0.0
var _heal_line_to := Vector2.ZERO
var _heal_line_timer := 0.0
# CO-033：人族从大本营行军至落点
var _deploying := false
var _combat_after_deploy := false

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
	if race == "human":
		refresh_tech_stats()
	hp = max_hp
	home = position
	_prev_pos = position
	_maybe_spawn_sprite_view()
	if Config.is_farmer(def):
		_supply_timer = Config.FARMER_SUPPLY_INTERVAL * 0.5
		_seek_depot()
	if Config.is_depot(def):
		var cap: int = int(def.get("stock_max", Config.DEPOT_STOCK_MAX))
		if _main != null and _main.get("human_tech") != null:
			cap += int(_main.human_tech.stock_bonus(def))
		depot_stock = cap
	if str(def.get("kind", "")) == "healer":
		max_mana = float(def.get("mana_max", 100.0))
		if race == "human" and _main != null and _main.get("human_tech") != null:
			max_mana *= float(_main.human_tech.mana_mult(def))
		mana = max_mana
	if def.get("kind", "") == "burst":
		_shield_hp = max_hp * float(def.get("shield_hp_ratio", 0.4))
		_shield_timer = float(def.get("shield_duration", 3.0))

## CO-033：从大本营走出；target 为落点；arrive_combat 表示到达后是否开战
func begin_hq_deploy(target: Vector2, arrive_combat: bool = false) -> void:
	home = target
	_deploying = true
	_combat_after_deploy = arrive_combat
	# 行军中暂不交战；抵达后再开战（勿长期清掉已有开战标记之外的逻辑）
	_combat = false
	# 农民：行军中不寻站，到达后再 _seek_depot
	_depot = null
	_working = false

func _tick_hq_deploy(delta: float) -> void:
	var spd: float = float(def.get("speed", 50.0)) * 1.4
	if spd < 1.0:
		spd = 70.0
	position = position.move_toward(home, spd * delta)
	var moved: float = position.distance_to(_prev_pos)
	if _sprite_view != null and _sprite_view.has_method("set_moving"):
		_sprite_set_moving(moved > 0.4)
	if moved > 0.4 and _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
		_sprite_view.set_facing_toward(home)
	_prev_pos = position
	if position.distance_to(home) <= 3.0:
		position = home
		_deploying = false
		if Config.is_farmer(def):
			_seek_depot()
		else:
			# CO-039：抵达后若已开战 → 自动进入拦截
			if _combat_after_deploy or _combat:
				set_combat(true)
			elif _main != null and int(_main.state) == 1:
				set_combat(true)
	queue_redraw()

func _maybe_spawn_sprite_view() -> void:
	var tex: Texture2D = UnitSprites.load_texture(race, int(def.get("id", -1)))
	if tex == null:
		_clear_sprite_view()
		return
	if _sprite_view != null and is_instance_valid(_sprite_view):
		if _sprite_view.has_method("setup"):
			_sprite_view.setup(tex, str(def.get("kind", "")), float(def["radius"]), race, _is_stationary(), int(def.get("id", -1)), bool(def.get("hover_idle", false)))
		return
	_clear_sprite_view()
	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	if script == null:
		return
	_sprite_view = Node2D.new()
	_sprite_view.set_script(script)
	add_child(_sprite_view)
	if _sprite_view.has_method("setup"):
		_sprite_view.setup(tex, str(def.get("kind", "")), float(def["radius"]), race, _is_stationary(), int(def.get("id", -1)), bool(def.get("hover_idle", false)))
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
	if str(def.get("kind", "")) == "healer":
		max_mana = float(def.get("mana_max", 100.0))
		mana = max_mana
	if Config.is_depot(def):
		depot_stock = int(def.get("stock_max", Config.DEPOT_STOCK_MAX))
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
	return _chain_bonus * split_power_mult() * dmg_buff

func effective_damage() -> float:
	var m: float = 1.0
	if race == "human" and _main != null and _main.get("human_tech") != null:
		m = float(_main.human_tech.damage_mult(def))
	return float(def["damage"]) * _attack_power_mult() * m

func effective_rate() -> float:
	return float(def["rate"]) * as_buff * (1.15 if aura_active else 1.0)

func refresh_tech_stats() -> void:
	# 科技升级后刷新血量上限（当前血按比例保留）
	var ratio: float = 1.0 if max_hp <= 0.0 else clampf(hp / max_hp, 0.0, 1.0)
	var base: float = float(def["hp"])
	if race == "fungus":
		base *= pow(Config.FUNGUS_SPLIT_HP_MULT, float(split_tier))
	var hm: float = 1.0
	if race == "human" and _main != null and _main.get("human_tech") != null:
		hm = float(_main.human_tech.hp_mult(def))
	max_hp = base * hm
	hp = max_hp * ratio
	if str(def.get("kind", "")) == "healer" and _main != null and _main.get("human_tech") != null:
		max_mana = float(def.get("mana_max", 100.0)) * float(_main.human_tech.mana_mult(def))
		mana = minf(mana, max_mana)
	if Config.is_depot(def) and _main != null and _main.get("human_tech") != null:
		var cap: int = int(def.get("stock_max", Config.DEPOT_STOCK_MAX)) + int(_main.human_tech.stock_bonus(def))
		depot_stock = mini(depot_stock, cap)
	queue_redraw()

func effective_poison_dps() -> float:
	return float(def.get("poison_dps", 0.0)) * split_power_mult()

func can_split() -> bool:
	return race == "fungus" and split_tier < Config.FUNGUS_SPLIT_MAX and not dead

func _apply_split_tier_stats() -> void:
	var hp_mult: float = 1.0
	if race == "fungus":
		hp_mult = pow(Config.FUNGUS_SPLIT_HP_MULT, float(split_tier))
	var hm: float = 1.0
	if race == "human" and _main != null and _main.get("human_tech") != null:
		hm = float(_main.human_tech.hp_mult(def))
	max_hp = float(def["hp"]) * hp_mult * hm

func after_bud_as_parent() -> void:
	if not can_split():
		return
	split_tier += 1
	_apply_split_tier_stats()
	hp = minf(hp, max_hp)
	_split_timer = Config.FUNGUS_SPLIT_INTERVAL
	play_split_flash()
	queue_redraw()

func play_split_flash() -> void:
	_split_flash = 0.6
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
	if b:
		_combat_after_deploy = true
	if not _combat:
		cooldown = 0.0
		_charge = 0.0
	elif race == "fungus":
		_split_timer = Config.FUNGUS_SPLIT_FIRST_DELAY
	if _combat and def.get("kind", "") == "burst":
		_shield_hp = max_hp * float(def.get("shield_hp_ratio", 0.4))
		_shield_timer = float(def.get("shield_duration", 3.0))

func can_player_order() -> bool:
	if dead or _deploying:
		return false
	if _is_stationary():
		return false
	var kind: String = str(def.get("kind", ""))
	if kind in ["farmer", "depot"]:
		return false
	return true

func clear_player_order() -> void:
	_order = ""
	_order_target = null
	_order_fly = _default_fly_loco()


func _default_fly_loco() -> bool:
	if str(def.get("kind", "")) == "fly":
		return true
	return bool(def.get("can_fly_move", false))


## 右键默认飞；按住 Shift = 贴地走（可飞可走单位）
func _prefer_fly_loco() -> bool:
	if str(def.get("kind", "")) == "fly":
		return true
	if bool(def.get("can_fly_move", false)):
		return not Input.is_physical_key_pressed(KEY_SHIFT)
	return false


func _sprite_set_moving(moving: bool) -> void:
	if _sprite_view == null or not _sprite_view.has_method("set_moving"):
		return
	var use_fly := _order_fly if _order in ["move", "attack_move"] else _default_fly_loco()
	_sprite_view.set_moving(moving, use_fly)

func issue_move_to(pos: Vector2) -> bool:
	if not can_player_order():
		return false
	_order = "move"
	_order_pos = pos
	_order_target = null
	_order_fly = _prefer_fly_loco()
	_locked = null
	_assist_timer = 0.0
	home = pos
	_order_marker_timer = 1.4
	queue_redraw()
	return true

func issue_attack_area(pos: Vector2) -> bool:
	if not can_player_order():
		return false
	if str(def.get("kind", "")) == "healer":
		return issue_move_to(pos)
	_order = "attack_move"
	_order_pos = pos
	_order_target = null
	_order_fly = _prefer_fly_loco()
	_locked = null
	_assist_timer = 0.0
	home = pos
	_order_marker_timer = 1.4
	queue_redraw()
	return true

func issue_attack_target(enemy: Node) -> bool:
	if not can_player_order():
		return false
	if str(def.get("kind", "")) == "healer":
		return false
	if not _can_target_enemy(enemy):
		return false
	_order = "attack_target"
	_order_target = enemy
	_order_pos = enemy.position
	_order_fly = _default_fly_loco()
	_locked = enemy
	_assist_timer = Config.ASSIST_HOLD_SEC
	_order_marker_timer = 1.4
	queue_redraw()
	return true

func apply_attack_speed_buff(mult: float, duration: float) -> void:
	as_buff = mult
	buff_timer = duration

## CO-027：祭品契约等短时伤害 Buff
func apply_damage_buff(mult: float, duration: float) -> void:
	dmg_buff = maxf(dmg_buff, mult)
	dmg_buff_timer = maxf(dmg_buff_timer, duration)

## 无售价牺牲（祭品契约）
func force_sacrifice() -> void:
	if dead:
		return
	_on_death()

func apply_heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	hp = minf(max_hp, hp + amount)
	_heal_flash = 0.22
	if AudioController:
		AudioController.play("heal_chime", global_position)
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
		if AudioController:
			AudioController.play("wall_shatter", global_position)
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
			_queue_free_after_death_anim()
		return
	dead = true
	died.emit()
	if do_free:
		_queue_free_after_death_anim()

func _queue_free_after_death_anim() -> void:
	if _sprite_view != null and is_instance_valid(_sprite_view) and _sprite_view.has_method("play_death"):
		_sprite_view.play_death()
		var t := get_tree().create_timer(0.6)
		t.timeout.connect(queue_free)
	else:
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
		depot_stock = int(def.get("stock_max", Config.DEPOT_STOCK_MAX))
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
		var want: int = int(def.get("supply_amount", Config.FARMER_SUPPLY_AMOUNT))
		if race == "human" and _main != null and _main.get("human_tech") != null:
			want += int(_main.human_tech.supply_bonus(def))
		if want <= 0:
			want = Config.FARMER_SUPPLY_AMOUNT
		var room: int = Config.MAX_SUPPLY - int(_main.supply)
		want = mini(want, room)
		var got: int = _depot.take_depot_stock(want)
		if got > 0:
			_main.add_supply(got)
			if AudioController:
				AudioController.play("supply_tick", global_position)

var _aura_check := 0.0
func _physics_process(delta: float) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			hp = max_hp
			dead = false
			_hit_flash = 0.0
			if AudioController:
				AudioController.play("crystal_clink", global_position)
		queue_redraw()
		return
	if dead:
		return
	if _deploying:
		_tick_hq_deploy(delta)
		return
	if Config.is_farmer(def):
		_tick_farmer_logistics(delta)
		var moved_f: float = position.distance_to(_prev_pos)
		if _sprite_view != null and _sprite_view.has_method("set_moving"):
			_sprite_set_moving(moved_f > 0.5 and not _working)
		if _sprite_view != null and moved_f > 0.5 and not _working and _sprite_view.has_method("set_facing_toward"):
			_sprite_view.set_facing_toward(global_position + (position - _prev_pos).normalized() * 32.0)
		_prev_pos = position
		queue_redraw()
		return
	if _heal_flash > 0.0:
		_heal_flash -= delta
	if _dream_ally_flash > 0.0:
		_dream_ally_flash -= delta
	if _heal_line_timer > 0.0:
		_heal_line_timer -= delta
	if buff_timer > 0.0:
		buff_timer -= delta
		if buff_timer <= 0.0:
			as_buff = 1.0
	if dmg_buff_timer > 0.0:
		dmg_buff_timer -= delta
		if dmg_buff_timer <= 0.0:
			dmg_buff = 1.0
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
	if _split_flash > 0.0:
		_split_flash -= delta
	if _shot_line_timer > 0.0:
		_shot_line_timer -= delta
	if _muzzle_timer > 0.0:
		_muzzle_timer -= delta
	if _burn_line_timer > 0.0:
		_burn_line_timer -= delta
	if _paralyze_cd > 0.0:
		_paralyze_cd -= delta
	if _sleep_cd > 0.0:
		_sleep_cd -= delta
	var combat_target: Node = null
	if _order_marker_timer > 0.0:
		_order_marker_timer -= delta
	if _assist_timer > 0.0:
		_assist_timer -= delta
	if _assist_call_cd > 0.0:
		_assist_call_cd -= delta
	# 有玩家指令时可在非开战态移动；开战态优先执行指令
	if not _order.is_empty() or _combat:
		_tick_fungus_carpet(delta)
		if race == "fungus" and can_split():
			_split_timer -= delta
			if _split_timer <= 0.0:
				_try_auto_bud()
		if not _order.is_empty():
			combat_target = _execute_player_order(delta)
		elif str(def.get("kind", "")) == "healer":
			_tick_healer(delta)
		else:
			combat_target = _acquire_target()
			if combat_target != null:
				if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
					_sprite_view.set_facing_toward(combat_target.global_position)
				else:
					rotation = lerp_angle(rotation, position.angle_to_point(combat_target.position), minf(1.0, 10.0 * delta))
				_do_move_or_attack(combat_target, delta)
				_try_call_allies(combat_target)
			else:
				_return_home(delta)
	else:
		_return_home(delta)
	var moved: float = position.distance_to(_prev_pos)
	if _sprite_view != null:
		var moving: bool = moved > maxf(0.8, float(def["speed"]) * delta * 0.35)
		var atk: bool = _sprite_view.has_method("is_attacking") and _sprite_view.is_attacking()
		if _sprite_view.has_method("set_moving"):
			_sprite_set_moving(moving and not atk)
		# 有战斗目标时保持面朝目标；无目标才按移动方向转身
		if combat_target == null and moving and not atk and _sprite_view.has_method("set_facing_toward"):
			var vel: Vector2 = position - _prev_pos
			if vel.length_squared() > 0.0001:
				_sprite_view.set_facing_toward(global_position + vel.normalized() * 32.0)
		if _uses_pixel_sprite():
			z_index = UnitSprites.depth_z(position.y)
	_prev_pos = position
	queue_redraw()

## CO-042：执行玩家右键指令；返回当前交战目标（供朝向）
func _execute_player_order(delta: float) -> Node:
	if _order == "move":
		if str(def.get("kind", "")) == "healer":
			# 牧师也可被派往新站位
			pass
		var dist: float = position.distance_to(_order_pos)
		if dist <= Config.ORDER_ARRIVE_DIST:
			position = _order_pos
			home = _order_pos
			clear_player_order()
			_apply_friendly_sep(delta)
			return null
		position = position.move_toward(_order_pos, float(def.get("speed", 50.0)) * delta)
		if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
			_sprite_view.set_facing_toward(_order_pos)
		_apply_friendly_sep(delta)
		return null
	if _order == "attack_target":
		if not _can_target_enemy(_order_target):
			clear_player_order()
			_return_home(delta)
			return null
		_locked = _order_target
		_order_pos = _order_target.position
		if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
			_sprite_view.set_facing_toward(_order_target.global_position)
		_do_move_or_attack(_order_target, delta)
		_try_call_allies(_order_target)
		return _order_target
	if _order == "attack_move":
		var focus: Node = _scan_order_area_target()
		if focus != null:
			_locked = focus
			if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
				_sprite_view.set_facing_toward(focus.global_position)
			_do_move_or_attack(focus, delta)
			_try_call_allies(focus)
			return focus
		var d2: float = position.distance_to(_order_pos)
		if d2 <= Config.ORDER_ARRIVE_DIST:
			position = _order_pos
			home = _order_pos
			clear_player_order()
			_apply_friendly_sep(delta)
			return null
		position = position.move_toward(_order_pos, float(def.get("speed", 50.0)) * delta)
		if _sprite_view != null and _sprite_view.has_method("set_facing_toward"):
			_sprite_view.set_facing_toward(_order_pos)
		_apply_friendly_sep(delta)
		return null
	clear_player_order()
	return null

func _scan_order_area_target() -> Node:
	if _enemies == null:
		return null
	var best: Node = null
	var best_score := -INF
	var area_r: float = Config.ORDER_AREA_RADIUS
	for e in _enemies.get_children():
		if not _can_target_enemy(e):
			continue
		var to_area: float = e.position.distance_to(_order_pos)
		var to_me: float = e.position.distance_to(position)
		# 优先点选区域附近的怪；途中也可接敌（自身 aggro 内）
		if to_area > area_r and to_me > _aggro_range():
			continue
		var score: float = 200000.0 - to_area * 2.0 - to_me
		if to_area <= area_r:
			score += 50000.0
		if score > best_score:
			best_score = score
			best = e
	return best

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
		ally.apply_heal(float(def.get("heal_amount", 50.0)) * _human_heal_mult())
		_heal_line_to = ally.position - position
		_heal_line_timer = 0.3
		_attack_flash = 0.14
		cooldown = 1.0 / maxf(0.1, effective_rate())
	_apply_friendly_sep(delta)

func _human_heal_mult() -> float:
	if race == "human" and _main != null and _main.get("human_tech") != null:
		return float(_main.human_tech.heal_mult(def))
	return 1.0

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
		_chain_links.clear()
		return
	var links := 0
	_chain_links.clear()
	for u in _units.get_children():
		if u == self or not is_instance_valid(u):
			continue
		if position.distance_to(u.position) <= Config.SILICON_LINK_RANGE:
			links += 1
			# 只画向 instance_id 更大的一侧，避免双边双线
			if u.get_instance_id() > get_instance_id():
				_chain_links.append(u.position - position)
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
	return def.get("kind", "") in ["single", "splash", "aa", "charge", "spike", "spell"]

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
			if _should_intercept_march(t, dist) or _should_assist_march(t):
				position = position.move_toward(t.position, float(def["speed"]) * delta)
			elif dist <= reach + chase:
				position = position.move_toward(t.position, float(def["speed"]) * delta)
			else:
				_return_home(delta)
		else:
			if (_is_ranged_kind() and dist <= _aggro_range()) or (_assist_timer > 0.0 and _should_assist_march(t)):
				if _assist_timer > 0.0 and dist > _effective_range():
					position = position.move_toward(t.position, float(def["speed"]) * delta)
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

## 攻击动画回调：勿 bind 存活节点，否则目标已释放时 Callable 调入即类型错误
func _hit_cb_melee(target_id: int) -> void:
	var t: Object = instance_from_id(target_id)
	if t is Node:
		_apply_melee_strike(t as Node)

func _hit_cb_burst(target_id: int) -> void:
	var t: Object = instance_from_id(target_id)
	if t is Node:
		_apply_burst_strike(t as Node)

func _hit_cb_fly(target_id: int) -> void:
	var t: Object = instance_from_id(target_id)
	if t is Node:
		_apply_fly_strike(t as Node)

func _hit_cb_spell(target_id: int) -> void:
	var t: Object = instance_from_id(target_id)
	if t is Node:
		_apply_spell_strike(t as Node)

func _apply_spell_strike(t: Node) -> void:
	if t == null or not is_instance_valid(t):
		return
	_fire(t, effective_damage(), true)
	if t.has_method("apply_burn") and float(def.get("burn_dps", 0.0)) > 0.0:
		var bd: float = float(def.get("burn_dps", 10.0))
		if race == "human" and _main != null and _main.get("human_tech") != null:
			bd *= float(_main.human_tech.burn_mult(def))
		t.apply_burn(bd, float(def.get("burn_duration", 4.5)))
	_try_apply_sleep(t)
	if _projectiles != null:
		var fx: Node = load("res://scripts/attack_vfx.gd").new()
		_projectiles.add_child(fx)
		var uid: int = int(def.get("id", -1))
		if race == "dragon" and float(def.get("sleep_duration", 0.0)) > 0.0:
			var ring_r: float = 32.0
			if uid >= 17:
				ring_r = 40.0
			elif uid >= 16:
				ring_r = 38.0
			elif uid >= 15:
				ring_r = 38.4 # +20% vs 幼龙
			if fx.has_method("play_sleep_ring"):
				fx.play_sleep_ring(t.global_position, ring_r)
			elif fx.has_method("play_arcane_burst"):
				fx.play_arcane_burst(t.global_position, ring_r)
		elif race == "dragon":
			fx.play_dragon_breath(t.global_position, 48.0)
		elif fx.has_method("play_arcane_burst"):
			fx.play_arcane_burst(t.global_position, 36.0)
		else:
			fx.play_impact(Color(0.65, 0.40, 1.0))
			fx.global_position = t.global_position

func _try_apply_sleep(t: Node) -> void:
	if t == null or not is_instance_valid(t):
		return
	var dur: float = float(def.get("sleep_duration", 0.0))
	if dur <= 0.0 or _sleep_cd > 0.0:
		return
	if not t.has_method("apply_sleep"):
		return
	_sleep_cd = float(def.get("sleep_cd", 5.0))
	var slept := 1
	t.apply_sleep(dur)
	if AudioController:
		AudioController.play("sleep_chime", t.global_position)
	# CO-045/047：成年群体睡眠（同半径同时长，上限 N；刷新不叠时）
	var aoe_r: float = float(def.get("sleep_aoe_radius", 0.0))
	var aoe_max: int = int(def.get("sleep_aoe_max", 0))
	if aoe_r > 0.0 and aoe_max > 1 and _enemies != null:
		var candidates: Array = []
		for e in _enemies.get_children():
			if e == null or not is_instance_valid(e) or e == t:
				continue
			if bool(e.get("dead")):
				continue
			if not e.has_method("apply_sleep"):
				continue
			var d: float = t.position.distance_to(e.position)
			if d > aoe_r:
				continue
			candidates.append({"n": e, "d": d})
		candidates.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
		var room: int = aoe_max - 1
		for i in range(mini(room, candidates.size())):
			var en: Node = candidates[i]["n"]
			en.apply_sleep(dur)
			slept += 1
		if _projectiles != null and slept >= 2:
			var wave_fx: Node = load("res://scripts/attack_vfx.gd").new()
			_projectiles.add_child(wave_fx)
			if wave_fx.has_method("play_sleep_wave"):
				wave_fx.play_sleep_wave(t.global_position, aoe_r)
			if _main != null and _main.get("hud") != null and _main.hud.has_method("set_status"):
				_main.hud.set_status(tr("msg_dream_mass_sleep"))
			_flash_dream_allies()
	# 兼容旧字段：溅射短眠（若配置仍带）
	var splash_r: float = float(def.get("sleep_splash_radius", 0.0))
	var splash_dur: float = float(def.get("sleep_splash_duration", 0.0))
	if aoe_r <= 0.0 and splash_r > 0.0 and splash_dur > 0.0 and _enemies != null:
		for e in _enemies.get_children():
			if e == null or not is_instance_valid(e) or e == t:
				continue
			if bool(e.get("dead")):
				continue
			if t.position.distance_to(e.position) > splash_r:
				continue
			if e.has_method("apply_sleep"):
				e.apply_sleep(splash_dur)
	# 梦雾：仅睡眠窗；圈内减速（含未入睡）
	var mist_r: float = float(def.get("dream_mist_radius", 0.0))
	var mist_slow: float = float(def.get("dream_mist_slow", 0.0))
	if mist_r > 0.0 and mist_slow > 0.0 and _enemies != null:
		var slow_mult: float = clampf(1.0 - mist_slow, 0.55, 1.0)
		for e in _enemies.get_children():
			if e == null or not is_instance_valid(e):
				continue
			if bool(e.get("dead")):
				continue
			if t.position.distance_to(e.position) > mist_r:
				continue
			if e.has_method("apply_move_slow"):
				e.apply_move_slow(slow_mult, dur)
			elif e.has_method("apply_carpet_aura"):
				e.apply_carpet_aura(mist_slow)
		if _projectiles != null:
			var mist_fx: Node = load("res://scripts/attack_vfx.gd").new()
			_projectiles.add_child(mist_fx)
			if mist_fx.has_method("play_dream_mist"):
				mist_fx.play_dream_mist(t.global_position, mist_r)

func _flash_dream_allies() -> void:
	## CO-047 L1：群梦窗内友军冰蓝描边闪 0.15s
	if _units == null:
		return
	for u in _units.get_children():
		if u == null or not is_instance_valid(u) or u == self:
			continue
		if u.has_method("play_dream_ally_flash"):
			u.play_dream_ally_flash()

func play_dream_ally_flash() -> void:
	_dream_ally_flash = 0.15

func _hit_cb_deal(target_id: int, dmg: float) -> void:
	var t: Object = instance_from_id(target_id)
	if t is Node:
		_deal_enemy_damage(t as Node, dmg)

func _do_fly(t: Node, delta: float) -> void:
	var dist: float = position.distance_to(t.position)
	var reach: float = _attack_reach()
	if dist > reach:
		position = position.move_toward(t.position, float(def["speed"]) * delta)
	elif cooldown <= 0.0:
		if _sprite_view != null and _sprite_view.has_method("start_attack"):
			_sprite_view.start_attack(_hit_cb_fly.bind(t.get_instance_id()))
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
				_sprite_view.start_attack(_hit_cb_deal.bind(t.get_instance_id(), dmg))
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
		elif k in ["single", "aa", "spike", "spell"]:
			dk = k if k != "spike" and k != "spell" else "single"
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
				_sprite_view.start_attack(_hit_cb_melee.bind(t.get_instance_id()))
				return
			_apply_melee_strike(t)
			_attack_flash = 0.14
		"burst":
			if _sprite_view != null and _sprite_view.has_method("start_attack"):
				_attack_flash = 0.14
				cooldown = 1.0 / max(0.1, rate)
				_sprite_view.start_attack(_hit_cb_burst.bind(t.get_instance_id()))
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
		"spell":
			# 龙人施法：施法动作命中时放出元素弹 + 吐息特效
			if _sprite_view != null and _sprite_view.has_method("start_attack"):
				_attack_flash = 0.14
				cooldown = 1.0 / max(0.1, rate)
				_sprite_view.start_attack(_hit_cb_spell.bind(t.get_instance_id()))
				return
			_apply_spell_strike(t)
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
	var bonus: float = 0.0
	if race == "human" and _main != null and _main.get("human_tech") != null:
		bonus = float(_main.human_tech.range_bonus(def))
	if kind in ["melee", "wall", "burst", "explode"]:
		return _attack_reach() + bonus
	if kind == "fly":
		return float(def["range"]) + bonus
	return _attack_reach() + _ranged_standoff() + Config.RANGED_COMBAT_BONUS + bonus

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
	if _assist_timer > 0.0:
		lock_range = maxf(lock_range, Config.ASSIST_MAX_FROM_HOME)
	if kind in ["melee", "wall", "burst", "explode"]:
		lock_range = maxf(lock_range, _aggro_range() + chase + 20.0)
	if _locked != null and is_instance_valid(_locked) and _locked.is_inside_tree():
		if not _can_target_enemy(_locked):
			_locked = null
		else:
			var dist_locked: float = position.distance_to(_locked.position)
			if dist_locked <= lock_range:
				if _can_hit(_locked.position):
					return _locked
				if _is_ranged_kind() and dist_locked <= maxf(_aggro_range(), lock_range if _assist_timer > 0.0 else _aggro_range()):
					return _locked
				if kind in ["melee", "wall", "burst", "explode"] and dist_locked <= lock_range:
					return _locked
				if race == "fungus" and _main != null and _main.is_on_carpet(_locked.position):
					return _locked
				if _assist_timer > 0.0:
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
	if dist > Config.MELEE_AGGRO_RANGE and _assist_timer <= 0.0:
		return false
	if home.distance_to(position) >= Config.MELEE_INTERCEPT_LEASH and _assist_timer <= 0.0:
		return false
	if _assist_timer > 0.0:
		return _should_assist_march(t)
	if Config.dist_to_path(t.position) <= Config.PATH_HALF_WIDTH + 8.0:
		return true
	return dist <= 22.0 + Config.MELEE_CHASE + 5.0

func _should_assist_march(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	# 玩家攻击指令：允许追击，不受原拦截绳限制
	if not _order.is_empty() and _order != "move":
		return true
	if home.distance_to(t.position) > Config.ASSIST_MAX_FROM_HOME:
		return false
	if home.distance_to(position) > Config.ASSIST_MAX_FROM_HOME:
		return false
	return true

func _can_issue_assist_call() -> bool:
	if dead or not _combat:
		return false
	var kind: String = str(def.get("kind", ""))
	if kind in ["farmer", "depot", "healer", "aura"]:
		return false
	return true

func _can_receive_assist_call() -> bool:
	return _can_issue_assist_call()

## CO-041：接敌呼唤——呼唤身边友军锁定同一目标（可再扩散形成连锁）
func _try_call_allies(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or _units == null:
		return
	if not _can_issue_assist_call():
		return
	if _assist_call_cd > 0.0:
		return
	_assist_call_cd = Config.ASSIST_CALL_INTERVAL
	for u in _units.get_children():
		if u == null or u == self or not is_instance_valid(u):
			continue
		if not u.has_method("receive_assist_call"):
			continue
		if position.distance_to(u.position) > Config.ASSIST_CALL_RADIUS:
			continue
		u.receive_assist_call(enemy)

func receive_assist_call(enemy: Node) -> void:
	if not _can_receive_assist_call():
		return
	if not _can_target_enemy(enemy):
		return
	if _is_stationary():
		# 固定建筑：仅在射程内才接应
		if not _can_hit(enemy.position):
			return
		_locked = enemy
		_assist_timer = Config.ASSIST_HOLD_SEC
		return
	_locked = enemy
	_assist_timer = Config.ASSIST_HOLD_SEC

func _scan_target() -> Node:
	var best: Node = null
	var best_score := -INF
	var aggro: float = _aggro_range()
	if _assist_timer > 0.0:
		aggro = maxf(aggro, Config.ASSIST_MAX_FROM_HOME)
	for e in _enemies.get_children():
		if not _can_target_enemy(e):
			continue
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

func _can_target_enemy(e: Node) -> bool:
	if e == null or not is_instance_valid(e) or not e.is_inside_tree():
		return false
	# 注意：勿写 bool(e.get("alive"))==false —— get 失败返回 null，bool(null) 为 false，会过滤掉全部敌人
	var alive_v = e.get("alive")
	if alive_v != null and alive_v == false:
		return false
	# CO-039：飞行敌仅远程可打
	if Config.is_flying_enemy(e.def) and not Config.unit_can_hit_air(def):
		return false
	return true

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
		"spell":
			# 法师群体：优先扎堆 + 铁皮
			var sp: float = _splash_score(e, d) + on_carpet
			if Config.is_flying_enemy(e.def):
				sp += 70000.0
			if int(e.def.get("id", -1)) == 3:
				sp += 50000.0
			return sp
		"aa", "spike":
			var s: float = 100000.0 - d
			if Config.is_flying_enemy(e.def):
				s += 120000.0  # CO-039：对空优先
			if int(e.def.get("id", -1)) == 1:
				s += 80000.0
			return s
		"single":
			var s2: float = 100000.0 - d + on_carpet
			if Config.is_flying_enemy(e.def):
				s2 += 90000.0
			if _ally_melee_near(e.position, 90.0):
				s2 += 35000.0
			if int(e.def.get("id", -1)) == 3:
				s2 += 55000.0  # 弓手优先点铁皮
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
	if race == "human" and _main != null and _main.get("human_tech") != null:
		splash_r += float(_main.human_tech.splash_bonus(def))
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
		"splash", "spell":
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

func _fire(target: Node, dmg_override: float = -1.0, skip_shoot_anim: bool = false) -> void:
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
	if not skip_shoot_anim and _sprite_view != null and _sprite_view.has_method("start_shoot"):
		_sprite_view.start_shoot()
	_spawn_muzzle_at(muzzle, dir)
	var p: Node = load("res://scripts/projectile.gd").new()
	_projectiles.add_child(p)
	p.global_position = muzzle
	var pk: String = "spore" if race == "fungus" else String(def["kind"])
	var splash_r: float = float(def.get("splash_radius", 0.0))
	if race == "human" and _main != null and _main.get("human_tech") != null:
		splash_r += float(_main.human_tech.splash_bonus(def))
	# 法师有溅射半径时按群体伤害结算（仍走 spell→splash 护甲表）
	if pk == "spell":
		pk = "splash" if splash_r > 0.0 else "single"
	p.setup(self, _enemies, target, dmg, _projectile_speed(),
		splash_r, 1.0, 0.0, Color(def["color"]), pk)
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
		var rr: float = float(def["radius"])
		var max_rt: float = maxf(0.1, float(def.get("regen_time", 10.0)))
		var prog: float = 1.0 - clampf(_regen_timer / max_rt, 0.0, 1.0)
		draw_circle(Vector2.ZERO, rr, Color(def["color"], 0.22))
		draw_arc(Vector2.ZERO, rr + 4.0, 0.0, TAU, 28, Color(0.35, 0.7, 0.95, 0.35), 2.0, true)
		draw_arc(Vector2.ZERO, rr + 6.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(0.55, 0.95, 1.0, 0.9), 3.0, true)
		var font: Font = ThemeDB.fallback_font
		var sec_txt := "%ds" % int(ceil(_regen_timer))
		draw_string(font, Vector2(-10, -rr - 14), sec_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.95, 1.0, 0.95))
		return
	var r: float = float(def["radius"])
	var kind: String = def.get("kind", "")
	# CO-016：晶脉连线
	if race == "silicon" and not _chain_links.is_empty():
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)
		for link_to in _chain_links:
			draw_line(Vector2.ZERO, link_to, Color(0.35, 0.9, 1.0, 0.35 * pulse), 2.0, true)
			draw_line(Vector2.ZERO, link_to, Color(0.75, 1.0, 1.0, 0.55 * pulse), 1.0, true)
			draw_circle(link_to * 0.5, 3.0, Color(0.6, 1.0, 1.0, 0.65 * pulse))
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
	if _dream_ally_flash > 0.0:
		var da: float = _dream_ally_flash / 0.15
		draw_arc(Vector2.ZERO, r + 7.0, 0.0, TAU, 32, Color(0.55, 0.82, 1.0, 0.85 * da), 2.8, true)
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
		# 像素精灵：仅极淡脚底影；梦龙禁色块底（色块跟着位移 = 假「平移怪」）
		var uid: int = int(def.get("id", -1))
		if not (race == "dragon" and uid in [14, 15, 16, 17]):
			draw_circle(Vector2(0, 2), r * 0.55, Color(0, 0, 0, 0.28))
			draw_circle(Vector2.ZERO, r * 0.35, Color(def["color"].r, def["color"].g, def["color"].b, 0.35))
		else:
			draw_circle(Vector2(0, 3), r * 0.4, Color(0, 0, 0, 0.18))
	if _is_stationary():
		draw_arc(Vector2.ZERO, r + 2.0, 0.0, TAU, 20, Color(0.35, 0.65, 0.2, 0.45), 1.2, true)
	if race == "fungus" and split_tier > 0:
		# CO-014：同心环标代数，选中时更亮
		var ring_a: float = 0.85 if selected else 0.55
		for i in range(split_tier):
			var rr: float = r + 4.0 + float(i) * 3.5
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 28, Color(0.95, 0.98, 0.45, ring_a), 1.8, true)
			var ang := PI * 0.25 + float(i) * TAU / float(max(split_tier, 1))
			draw_circle(Vector2(cos(ang) * r * 0.65, sin(ang) * r * 0.65), 2.6, Color(0.95, 0.98, 0.55))
	if _split_flash > 0.0:
		var sa: float = _split_flash / 0.6
		draw_circle(Vector2.ZERO, r + 18.0 * sa, Color(0.7, 1.0, 0.35, 0.35 * sa))
		draw_arc(Vector2.ZERO, r + 20.0 * sa, 0.0, TAU, 32, Color(0.95, 1.0, 0.55, 0.9 * sa), 3.5, true)
		for i in range(6):
			var ang2 := float(i) / 6.0 * TAU
			draw_circle(Vector2(cos(ang2), sin(ang2)) * (r + 12.0 * sa), 3.0 * sa, Color(0.85, 1.0, 0.4, 0.8 * sa))
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
		draw_arc(Vector2.ZERO, r + 7.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.35, 0.95), 2.0, true)
	# CO-042：下令落点 / 攻击目标标记
	if (_order_marker_timer > 0.0 or selected) and not _order.is_empty():
		var mark: Vector2 = _order_pos - position
		if _order == "attack_target" and _order_target != null and is_instance_valid(_order_target):
			mark = _order_target.position - position
		var a: float = 0.9 if _order_marker_timer > 0.0 else 0.5
		var col := Color(0.35, 0.85, 1.0, a) if _order == "move" else Color(1.0, 0.4, 0.22, a)
		draw_circle(mark, 5.0, col)
		draw_arc(mark, 14.0, 0.0, TAU, 22, col, 1.6, true)
		draw_line(mark + Vector2(-9, 0), mark + Vector2(9, 0), col, 1.6)
		draw_line(mark + Vector2(0, -9), mark + Vector2(0, 9), col, 1.6)

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
			var stock_cap: float = float(def.get("stock_max", Config.DEPOT_STOCK_MAX))
			var ratio: float = clampf(float(depot_stock) / maxf(1.0, stock_cap), 0.0, 1.0)
			var bar_w: float = r * 1.6
			draw_rect(Rect2(-bar_w * 0.5, r + 4.0, bar_w, 4.0), Color(0.1, 0.1, 0.1, 0.7), true)
			draw_rect(Rect2(-bar_w * 0.5, r + 4.0, bar_w * ratio, 4.0), Color(0.55, 0.9, 0.35, 0.95), true)
		"charge":
			draw_circle(fwd * 0.8, 4.0, Color(0.3, 0.9, 1.0))
