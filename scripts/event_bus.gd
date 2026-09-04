# CO-019：局内随时随机事件总线（可扩展池）
# 数据表驱动；同屏最多 1 个进行中；冷却与同名上限。
extends Node

const _PlayerSecrets = preload("res://scripts/player_secrets.gd")

signal event_started(id: String)
signal event_ended(id: String)

const POOL: Array[Dictionary] = [
	{"id": "storm_lightning", "cat": "weather", "weight": 12, "max_per_run": 2, "min_wave": 2, "need_wave": true},
	{"id": "rain_slow", "cat": "weather", "weight": 13, "max_per_run": 2, "min_wave": 2, "need_wave": false},
	{"id": "unit_epiphany", "cat": "fortune", "weight": 14, "max_per_run": 3, "min_wave": 1, "need_wave": false},
	{"id": "dig_treasure", "cat": "explore", "weight": 14, "max_per_run": 3, "min_wave": 1, "need_wave": false},
	{"id": "runner_surge", "cat": "crisis", "weight": 10, "max_per_run": 2, "min_wave": 5, "need_wave": true},
	{"id": "supply_theft", "cat": "crisis", "weight": 10, "max_per_run": 2, "min_wave": 2, "need_wave": false, "race": "human"},
	{"id": "wind_haste", "cat": "field", "weight": 11, "max_per_run": 2, "min_wave": 3, "need_wave": true},
	{"id": "race_surge", "cat": "field", "weight": 10, "max_per_run": 2, "min_wave": 3, "need_wave": false},
	{"id": "blood_gold", "cat": "choice", "weight": 8, "max_per_run": 2, "min_wave": 2, "need_wave": false},
	{"id": "merchant_deal", "cat": "choice", "weight": 8, "max_per_run": 2, "min_wave": 1, "need_wave": false},
	{"id": "end_rumble", "cat": "crisis", "weight": 14, "max_per_run": 2, "min_wave": 3, "need_wave": true, "need_near_end": true},
	{"id": "evolve_tide", "cat": "fortune", "weight": 9, "max_per_run": 2, "min_wave": 2, "need_wave": false},
	# CO-027：三包补齐 — 廊道改道 / 祭品契约
	{"id": "path_detour", "cat": "field", "weight": 7, "max_per_run": 1, "min_wave": 5, "need_wave": true},
	{"id": "sacrifice_pact", "cat": "choice", "weight": 6, "max_per_run": 1, "min_wave": 6, "need_wave": false, "need_combat_units": 2, "min_lives": 25},
	# CO-044 搁置：dragon_shadow_omen / scale_vault 等剧情接入后再启用
]

var _main: Node = null
var _rng := RandomNumberGenerator.new()
var _cd := 18.0
var _active_id := ""
var _active_left := 0.0
var _counts: Dictionary = {}
var _weather: Node = null
var _treasure: Node2D = null
var _pending_choice := ""
var _strike_cd := 0.0
var _evolve_discount := 1.0
var _wind_tick := 0.0
var pending_spawns: Array = []  # 波间惊怪，下波注入
var _rumble_wave := -1
var _warn_cd := 0.0
var _path_backup: Array[Vector2] = []
var _detour_active := false

func setup(main: Node) -> void:
	_main = main
	_rng.randomize()
	_cd = _rng.randf_range(12.0, 22.0)
	_weather = load("res://scripts/weather_controller.gd").new()
	_main.add_child(_weather)

func tick(delta: float) -> void:
	if _main == null:
		return
	var st: int = _main.state
	if st == _main.GameState.GAME_OVER or st == _main.GameState.WIN:
		if _detour_active:
			_restore_path_detour()
		return
	if st == _main.GameState.WAVING:
		_tick_near_end_warn(delta)
	if _active_id != "":
		_tick_active(delta)
		return
	if _pending_choice != "":
		return
	_cd -= delta
	if _cd > 0.0:
		return
	_try_roll_event()

func evolve_cost_mult() -> float:
	if _active_id == "merchant_deal" or _active_id == "evolve_tide":
		return clampf(_evolve_discount, 0.4, 1.0)
	return 1.0

func take_pending_spawns() -> Array:
	var out: Array = pending_spawns.duplicate()
	pending_spawns.clear()
	return out

func _try_roll_event() -> void:
	var wave: int = int(_main.wave_index)
	var candidates: Array[Dictionary] = []
	var total_w := 0
	for e in POOL:
		if wave < int(e.get("min_wave", 0)):
			continue
		if bool(e.get("need_wave", false)) and _main.state != _main.GameState.WAVING:
			continue
		var race_need: String = str(e.get("race", ""))
		if race_need != "" and str(_main.current_race) != race_need:
			continue
		var forbid_race: String = str(e.get("forbid_race", ""))
		if forbid_race != "" and str(_main.current_race) == forbid_race:
			continue
		var need_secret: String = str(e.get("need_secret", ""))
		if need_secret == "dragon_locked" and _PlayerSecrets.is_dragon_unlocked():
			continue
		if need_secret == "easter_locked":
			if not _PlayerSecrets.is_dragon_unlocked():
				continue
			if _PlayerSecrets.is_easter_units_unlocked():
				continue
		if bool(e.get("need_near_end", false)) and not _any_enemy_near_end(0.72):
			continue
		if str(e["id"]) == "end_rumble" and _rumble_wave == wave:
			continue
		var need_units: int = int(e.get("need_combat_units", 0))
		if need_units > 0 and _combat_unit_count() < need_units:
			continue
		var min_lives: int = int(e.get("min_lives", 0))
		if min_lives > 0 and int(_main.lives) < min_lives:
			continue
		var id: String = str(e["id"])
		var used: int = int(_counts.get(id, 0))
		if used >= int(e.get("max_per_run", 99)):
			continue
		candidates.append(e)
		total_w += int(e.get("weight", 1))
	if candidates.is_empty() or total_w <= 0:
		_cd = _rng.randf_range(10.0, 16.0)
		return
	var roll := _rng.randi_range(1, total_w)
	var acc := 0
	var picked: Dictionary = candidates[0]
	for e in candidates:
		acc += int(e.get("weight", 1))
		if roll <= acc:
			picked = e
			break
	_start_event(str(picked["id"]))

func _start_event(id: String) -> void:
	_active_id = id
	_counts[id] = int(_counts.get(id, 0)) + 1
	_cd = _rng.randf_range(22.0, 36.0)
	event_started.emit(id)
	match id:
		"storm_lightning":
			_active_left = 14.0
			_strike_cd = 2.5
			if _weather != null and _weather.has_method("set_weather"):
				_weather.set_weather(_weather.WeatherType.STORM)
			_status(tr("evt_storm"))
			if AudioController:
				AudioController.play("lightning_crack", Vector2.ZERO)
		"rain_slow":
			_active_left = 22.0
			if _weather != null and _weather.has_method("set_weather"):
				_weather.set_weather(_weather.WeatherType.RAIN)
			_status(tr("evt_rain"))
		"unit_epiphany":
			_active_left = 10.0
			_do_epiphany()
		"dig_treasure":
			_active_left = 25.0
			_spawn_treasure()
			_status(tr("evt_dig"))
		"runner_surge":
			_active_left = 1.0
			_do_runner_surge()
		"supply_theft":
			_active_left = 1.0
			_do_supply_theft()
		"wind_haste":
			_active_left = 12.0
			_wind_tick = 0.0
			if _weather != null and _weather.has_method("set_weather"):
				_weather.set_weather(_weather.WeatherType.WIND)
			_status(tr("evt_wind"))
		"race_surge":
			_active_left = 1.0
			_do_race_surge()
		"blood_gold":
			_pending_choice = "blood_gold"
			_active_id = ""
			_status(tr("evt_blood_gold_ask"))
		"merchant_deal":
			_pending_choice = "merchant_deal"
			_active_id = ""
			_status(tr("evt_merchant_ask"))
		"end_rumble":
			_active_left = 6.0
			_rumble_wave = int(_main.wave_index)
			_status(tr("evt_rumble"))
			if AudioController:
				AudioController.play("impact_heavy", Vector2.ZERO)
		"evolve_tide":
			_active_id = "evolve_tide"
			_active_left = 35.0
			_evolve_discount = 0.70
			_status(tr("evt_evolve_tide"))
		"path_detour":
			_active_left = 14.0
			_do_path_detour()
		"sacrifice_pact":
			_pending_choice = "sacrifice_pact"
			_active_id = ""
			_status(tr("evt_pact_ask"))
		"dragon_shadow_omen":
			_pending_choice = "dragon_shadow_omen"
			_active_id = ""
			_status(tr("evt_dragon_omen_ask"))
		"scale_vault":
			_pending_choice = "scale_vault"
			_active_id = ""
			_status(tr("evt_scale_vault_ask"))
		_:
			_active_id = ""
			_cd = 8.0

func _tick_active(delta: float) -> void:
	_active_left -= delta
	match _active_id:
		"storm_lightning":
			_strike_cd -= delta
			if _strike_cd <= 0.0:
				_strike_cd = _rng.randf_range(2.2, 3.8)
				_do_lightning_strike()
		"rain_slow":
			_apply_rain_slow()
		"end_rumble":
			_apply_end_rumble()
		"wind_haste":
			_wind_tick -= delta
			if _wind_tick <= 0.0:
				_wind_tick = 0.45
				_apply_wind_haste()
		"dig_treasure":
			pass
		"evolve_tide":
			pass
		"path_detour":
			pass
	if _active_left <= 0.0:
		_end_active()

func _end_active() -> void:
	var id := _active_id
	if id in ["storm_lightning", "wind_haste", "rain_slow"]:
		if _weather != null and _weather.has_method("set_weather"):
			_weather.set_weather(_weather.WeatherType.CLEAR)
	if id == "dig_treasure":
		_clear_treasure()
	if id == "merchant_deal" or id == "evolve_tide":
		_evolve_discount = 1.0
	if id == "path_detour":
		_restore_path_detour()
	_active_id = ""
	_active_left = 0.0
	event_ended.emit(id)

func handle_choice_yes() -> bool:
	if _pending_choice == "":
		return false
	var c := _pending_choice
	_pending_choice = ""
	match c:
		"blood_gold":
			# CO-032：大本营 100HP 标尺——扣 8HP 换 $80（旧 32 命扣 1）
			if int(_main.lives) <= 8:
				_status(tr("evt_blood_gold_refuse_low"))
				return true
			if _main.has_method("damage_hq"):
				_main.damage_hq(8)
			else:
				_main.lives -= 8
				_main.hud.set_lives(_main.lives)
			_main.money += 80
			_main.hud.set_money(_main.money)
			_status(tr("evt_blood_gold_yes"))
		"merchant_deal":
			if _main.money < 40:
				_status(tr("evt_merchant_no_money"))
				return true
			_main.money -= 40
			_main.hud.set_money(_main.money)
			_active_id = "merchant_deal"
			_active_left = 40.0
			_evolve_discount = 0.65
			_status(tr("evt_merchant_yes"))
			event_started.emit("merchant_deal")
		"sacrifice_pact":
			_accept_sacrifice_pact()
		"dragon_shadow_omen":
			_accept_dragon_shadow_omen()
		"scale_vault":
			_accept_scale_vault()
	return true

func handle_choice_no() -> bool:
	if _pending_choice == "":
		return false
	var c := _pending_choice
	_pending_choice = ""
	match c:
		"blood_gold":
			_status(tr("evt_blood_gold_no"))
		"merchant_deal":
			_status(tr("evt_merchant_no"))
		"sacrifice_pact":
			_status(tr("evt_pact_no"))
		"dragon_shadow_omen":
			_status(tr("evt_dragon_omen_no"))
		"scale_vault":
			_status(tr("evt_scale_vault_no"))
	return true

func _status(s: String) -> void:
	if _main != null and _main.hud != null:
		_main.hud.set_status(s)

func _do_epiphany() -> void:
	var units: Array = []
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u):
			continue
		if bool(u.get("dead")):
			continue
		if Config.is_farmer(u.def) or Config.is_depot(u.def):
			continue
		units.append(u)
	if units.is_empty():
		_status(tr("evt_epiphany_none"))
		_active_id = ""
		return
	var u: Node = units[_rng.randi_range(0, units.size() - 1)]
	if u.has_method("apply_attack_speed_buff"):
		u.apply_attack_speed_buff(1.75, 10.0)
	_status(tr("evt_epiphany") % tr(str(u.def.get("name_key", "unit_0"))))
	if AudioController:
		AudioController.play("heal_chime", u.global_position)

func _do_runner_surge() -> void:
	var n := 3 + mini(2, int(_main.wave_index) / 4)
	for i in n:
		_main.spawn_queue.append(1)
	_main.enemies_alive += n
	_status(tr("evt_runner_surge") % n)
	if AudioController:
		AudioController.play("impact_med", Vector2.ZERO)

func _do_supply_theft() -> void:
	var lost: int = mini(8, int(_main.supply))
	if lost <= 0:
		_status(tr("evt_theft_empty"))
		_active_id = ""
		return
	_main.supply -= lost
	_main.hud.set_supply(_main.supply)
	_status(tr("evt_theft") % lost)
	if AudioController:
		AudioController.play("impact_heavy", Vector2.ZERO)

func _do_lightning_strike() -> void:
	if _weather != null and _weather.has_method("_trigger_lightning"):
		_weather._trigger_lightning()
	var foes: Array = []
	for e in _main.enemies_layer.get_children():
		if e != null and is_instance_valid(e) and e.alive:
			foes.append(e)
	var units: Array = []
	for u in _main.units_layer.get_children():
		if u != null and is_instance_valid(u) and not bool(u.get("dead")):
			if not Config.is_depot(u.def):
				units.append(u)
	# 80% 劈敌，20% 误伤己方
	if _rng.randf() < 0.8 and not foes.is_empty():
		var e: Node = foes[_rng.randi_range(0, foes.size() - 1)]
		if e.has_method("apply_damage"):
			e.apply_damage(55.0 + float(_main.wave_index) * 4.0, 1.0, 0.0, false, "splash")
		_status(tr("evt_storm_hit_enemy"))
	elif not units.is_empty():
		var u: Node = units[_rng.randi_range(0, units.size() - 1)]
		if u.has_method("apply_enemy_damage"):
			u.apply_enemy_damage(28.0)
		_status(tr("evt_storm_hit_ally"))

func _apply_rain_slow() -> void:
	for e in _main.enemies_layer.get_children():
		if e != null and is_instance_valid(e) and e.alive:
			e.slow_factor = minf(float(e.slow_factor), 0.82)
			e.slow_timer = maxf(float(e.slow_timer), 0.4)

func _do_race_surge() -> void:
	match str(_main.current_race):
		"fungus":
			if _main.carpet_layer != null and _main.carpet_layer.has_method("spread"):
				_main.carpet_layer.spread(maxi(1, int(_main.wave_index)))
			_status(tr("evt_race_fungus"))
		"silicon":
			_main.crystal_energy = mini(4, int(_main.crystal_energy) + 2)
			_main.hud.set_crystal(_main.crystal_energy)
			_status(tr("evt_race_silicon"))
		"dragon":
			for u in _main.units_layer.get_children():
				if u != null and is_instance_valid(u) and u.has_method("apply_attack_speed_buff"):
					u.apply_attack_speed_buff(1.35, 8.0)
			_status(tr("evt_race_dragon"))
		_:
			_main.money += 45
			_main.hud.set_money(_main.money)
			_status(tr("evt_race_human"))

func _apply_wind_haste() -> void:
	for e in _main.enemies_layer.get_children():
		if e != null and is_instance_valid(e) and e.alive:
			e.slow_factor = maxf(float(e.slow_factor), 1.35)
			e.slow_timer = maxf(float(e.slow_timer), 0.5)

func _spawn_treasure() -> void:
	_clear_treasure()
	var pos := Vector2(_rng.randf_range(180, 1100), _rng.randf_range(120, 600))
	# 避开路径
	for _i in 12:
		if Config.dist_to_path(pos) > Config.PATH_HALF_WIDTH + 40.0:
			break
		pos = Vector2(_rng.randf_range(180, 1100), _rng.randf_range(120, 600))
	_treasure = Node2D.new()
	_treasure.set_script(load("res://scripts/event_treasure.gd"))
	_treasure.position = pos
	_main.add_child(_treasure)
	if _treasure.has_method("setup"):
		_treasure.setup(self)

func _clear_treasure() -> void:
	if _treasure != null and is_instance_valid(_treasure):
		_treasure.queue_free()
	_treasure = null

func on_treasure_clicked() -> void:
	if _active_id != "dig_treasure":
		return
	var roll := _rng.randf()
	if roll < 0.45:
		var gold := 35 + _rng.randi_range(0, 40)
		_main.money += gold
		_main.hud.set_money(_main.money)
		_status(tr("evt_dig_gold") % gold)
	elif roll < 0.62 and str(_main.current_race) == "human":
		var sup := 4 + _rng.randi_range(0, 4)
		_main.add_supply(sup)
		_status(tr("evt_dig_supply") % sup)
	elif roll < 0.78:
		if _main.run_items != null and _main.run_items.has_method("grant_random_from_pool"):
			_main.run_items.grant_random_from_pool()
		else:
			_status(tr("evt_dig_empty"))
	elif roll < 0.90:
		_status(tr("evt_dig_empty"))
	else:
		pending_spawns.append(0)
		pending_spawns.append(0)
		pending_spawns.append(1)
		_status(tr("evt_dig_ambush"))
	_clear_treasure()
	_active_left = 0.0
	_end_active()
	if AudioController:
		AudioController.play("crystal_clink", Vector2.ZERO)

func _enemy_progress(e: Node) -> float:
	var pts: Array = Config.PATH_POINTS
	if pts.size() < 2:
		return 0.0
	var wi: int = int(e.waypoint_index)
	return clampf(float(wi) / float(pts.size() - 1), 0.0, 1.0)

func _any_enemy_near_end(thresh: float) -> bool:
	for e in _main.enemies_layer.get_children():
		if e != null and is_instance_valid(e) and e.alive and _enemy_progress(e) >= thresh:
			return true
	return false

func _apply_end_rumble() -> void:
	for e in _main.enemies_layer.get_children():
		if e == null or not is_instance_valid(e) or not e.alive:
			continue
		if _enemy_progress(e) >= 0.72:
			e.slow_factor = maxf(float(e.slow_factor), 1.25)
			e.slow_timer = maxf(float(e.slow_timer), 0.4)

func _tick_near_end_warn(delta: float) -> void:
	_warn_cd -= delta
	if _warn_cd > 0.0:
		return
	if _any_enemy_near_end(0.85):
		_warn_cd = 4.5
		# 不打断进行中事件文案过频：仅空闲时提示
		if _active_id == "" and _pending_choice == "":
			_status(tr("evt_near_end_warn"))

func _combat_unit_count() -> int:
	var n := 0
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		if Config.is_farmer(u.def) or Config.is_depot(u.def):
			continue
		n += 1
	return n

func _pick_sacrifice_target() -> Node:
	# 优先：当前选中的战斗单位；否则 HP% 最低者（可归因「卖谁」）
	var sel: Node = _main.selected_unit
	if sel != null and is_instance_valid(sel) and not bool(sel.get("dead")):
		if not Config.is_farmer(sel.def) and not Config.is_depot(sel.def):
			return sel
	var best: Node = null
	var best_ratio := 2.0
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		if Config.is_farmer(u.def) or Config.is_depot(u.def):
			continue
		var ratio: float = float(u.hp) / maxf(1.0, float(u.max_hp))
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best

func _accept_sacrifice_pact() -> void:
	var victim: Node = _pick_sacrifice_target()
	if victim == null:
		_status(tr("evt_pact_no_unit"))
		return
	var vname: String = tr(str(victim.def.get("name_key", "unit_0")))
	if _main.selected_unit == victim:
		_main.selected_unit = null
	if victim.has_method("force_sacrifice"):
		victim.force_sacrifice()
	else:
		victim.queue_free()
	# 全军伤害 Buff 覆盖本波（长时；清波后自然过期也可）
	var buff_sec: float = 48.0
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		if Config.is_farmer(u.def) or Config.is_depot(u.def):
			continue
		if u.has_method("apply_damage_buff"):
			u.apply_damage_buff(1.35, buff_sec)
		if u.has_method("apply_attack_speed_buff"):
			u.apply_attack_speed_buff(1.12, buff_sec)
	_status(tr("evt_pact_yes") % vname)
	if AudioController:
		AudioController.play("impact_heavy", Vector2.ZERO)

func _accept_dragon_shadow_omen() -> void:
	# 铭记龙裔：持久解锁隐藏种族；本局给微薄余烬攻速（可读反馈，非战力爆炸）
	var first: bool = _PlayerSecrets.unlock_dragon()
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		if u.has_method("apply_attack_speed_buff"):
			u.apply_attack_speed_buff(1.08, 12.0)
	if first:
		_status(tr("evt_dragon_omen_yes"))
		if _main.get_tree() != null:
			_main.get_tree().set_meta("secret_unlock_toast", "msg_secret_dragon")
	else:
		_status(tr("evt_dragon_omen_already"))
	if AudioController:
		AudioController.play("dragon_breath", Vector2.ZERO)

func _accept_scale_vault() -> void:
	# 鳞下密藏：须已解锁龙族；持久开放彩蛋单位（霜棱/镜影/梦龙）
	if not _PlayerSecrets.is_dragon_unlocked():
		_status(tr("evt_scale_vault_need_dragon"))
		return
	var first: bool = _PlayerSecrets.unlock_easter_units()
	if first:
		_status(tr("evt_scale_vault_yes"))
		if _main.get_tree() != null:
			_main.get_tree().set_meta("secret_unlock_toast", "msg_secret_easter_units")
	else:
		_status(tr("evt_scale_vault_already"))
	if AudioController:
		AudioController.play("ui")

func _do_path_detour() -> void:
	if Config.PATH_POINTS.size() < 5:
		_status(tr("evt_detour_fail"))
		_active_id = ""
		return
	_path_backup.clear()
	_path_backup.assign(Config.PATH_POINTS)
	var idx: int = clampi(3, 1, Config.PATH_POINTS.size() - 2)
	var a: Vector2 = Config.PATH_POINTS[idx - 1]
	var b: Vector2 = Config.PATH_POINTS[idx]
	var dir: Vector2 = (b - a).normalized()
	if dir.length_squared() < 0.001:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var sign: float = 1.0 if _rng.randf() < 0.5 else -1.0
	Config.PATH_POINTS[idx] = b + perp * 48.0 * sign
	_detour_active = true
	if _main.map_layer != null:
		_main.map_layer.queue_redraw()
	_status(tr("evt_detour"))
	if AudioController:
		AudioController.play("impact_med", Vector2.ZERO)

func _restore_path_detour() -> void:
	if not _detour_active:
		return
	if _path_backup.size() >= 2:
		Config.PATH_POINTS = _path_backup.duplicate()
	_path_backup.clear()
	_detour_active = false
	if _main != null and _main.map_layer != null:
		_main.map_layer.queue_redraw()
	_status(tr("evt_detour_end"))
