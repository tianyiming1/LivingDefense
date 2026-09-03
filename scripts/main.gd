# 主控：游戏状态机（PLANNING / WAVING / GAME_OVER / WIN）、
# 经济、波次、部署/进化/出售、双向战斗、技能、胜负。
# CO-011：经营+塔防 → PLANNING/WAVING 全程可部署；人族补给+农民。
# CO-002 i18n：可见文本 tr()；T 键切换中/英。
extends Node2D

enum GameState { PLANNING, WAVING, GAME_OVER, WIN }

var state := GameState.PLANNING
var current_race := "human"
var money := Config.START_MONEY
var supply := Config.START_SUPPLY
var lives := Config.START_LIVES
var wave_index := 0
var enemies_alive := 0
var units_lost := 0
var spawn_queue: Array = []
var spawn_timer := 0.0
var placing_unit_id := -1
var selected_unit: Node = null
var skill1_last_wave := -99    # 火力齐射上次释放波次（CD 按波次差）

var map_layer: Node2D = null
var enemies_layer: Node2D = null
var units_layer: Node2D = null
var projectiles_layer: Node2D = null
var ghost: Node = null
var carpet_layer: Node = null
var hud: Node = null
var spore_burst_active := false
var spore_burst_timer := 0.0
var carpet_fever_timer := 0.0
var resonate_timer := 0.0
var crystal_energy := 0
var skill2_last_wave := -99
var dragon_eggs: Array = []  # {time, def, pos}

func _ready() -> void:
	if get_tree().has_meta("selected_race"):
		current_race = str(get_tree().get_meta("selected_race"))
	if TranslationServer.get_locale() != "en":
		TranslationServer.set_locale("zh_CN")
	map_layer = Node2D.new()
	map_layer.set_script(load("res://scripts/map.gd"))
	map_layer.z_index = -10
	add_child(map_layer)
	enemies_layer = Node2D.new()
	enemies_layer.z_index = 8
	add_child(enemies_layer)
	units_layer = Node2D.new()
	units_layer.z_index = 10
	add_child(units_layer)
	projectiles_layer = Node2D.new()
	projectiles_layer.z_index = 20
	add_child(projectiles_layer)
	carpet_layer = Node2D.new()
	carpet_layer.set_script(load("res://scripts/carpet.gd"))
	carpet_layer.z_index = 1
	add_child(carpet_layer)
	ghost = Node2D.new()
	ghost.set_script(load("res://scripts/placement_ghost.gd"))
	ghost.visible = false
	add_child(ghost)
	hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.buy_requested.connect(_on_buy_requested)
	hud.start_wave_requested.connect(_on_start_wave)
	hud.speed_toggled.connect(_on_speed_toggled)
	hud.evolve_requested.connect(_on_evolve)
	hud.sell_requested.connect(_on_sell)
	hud.split_requested.connect(_on_split)
	hud.skill_requested.connect(_on_skill)
	hud.restart_requested.connect(_on_restart)
	hud.menu_requested.connect(_on_menu)
	hud.set_money(money)
	hud.set_supply(supply)
	hud.set_lives(lives)
	hud.set_losses(0)
	hud.set_wave(0)
	hud.set_skill_ready(true)
	hud.set_race(current_race)
	if current_race == "silicon":
		crystal_energy = 1
		hud.set_crystal(crystal_energy)
	hud.set_status(_intro_text())

func register_fungus_source(pos: Vector2, u_def: Dictionary) -> void:
	if carpet_layer == null or current_race != "fungus":
		return
	var mult: float = float(u_def.get("carpet_grow_mult", 1.0))
	carpet_layer.seed_from_unit(pos, mult)

func find_fungus_bud_spot(origin: Vector2, radius: float) -> Vector2:
	var dist: float = Config.TOWER_MIN_DIST + radius + 6.0
	for ring in [dist, dist * 0.8, dist * 1.2]:
		for i in range(12):
			var angle: float = float(i) / 12.0 * TAU
			var pos: Vector2 = origin + Vector2(cos(angle), sin(angle)) * ring
			if _can_place(pos):
				return pos
	return Vector2.ZERO

func spawn_fungus_bud(parent: Node, spot: Vector2) -> void:
	if current_race != "fungus" or parent == null or not parent.can_split():
		return
	var def: Dictionary = parent.def
	var child_tier: int = parent.split_tier + 1
	var u: Node = load("res://scripts/unit.gd").new()
	u.position = spot
	units_layer.add_child(u)
	u.setup(def, enemies_layer, projectiles_layer, units_layer, self, "fungus", child_tier)
	u.home = spot
	register_fungus_source(spot, def)
	u.died.connect(_on_unit_died)
	if state == GameState.WAVING:
		u.set_combat(true)
	parent.after_bud_as_parent()
	hud.set_status(tr("msg_split") % tr(def["name_key"]))
	if selected_unit == parent:
		_on_unit_click(parent.position)

func _intro_text() -> String:
	match current_race:
		"fungus":
			return tr("msg_intro_fungus")
		"dragon":
			return tr("msg_intro_dragon")
		"silicon":
			return tr("msg_intro_silicon")
		_:
			return tr("msg_intro_human")

func _units_table() -> Array:
	return Config.race_units(current_race)

func carpet_effect_at(pos: Vector2) -> Dictionary:
	if carpet_layer == null:
		return {"slow": 1.0, "dps": 0.0}
	return carpet_layer.effect_at(pos)

func is_on_carpet(pos: Vector2) -> bool:
	if carpet_layer == null:
		return false
	return carpet_layer.covers(pos)

func boost_carpet_spread(mult: float) -> void:
	if carpet_layer != null:
		carpet_layer.boost_spread(mult)

func boost_carpet_at(pos: Vector2, mult: float) -> void:
	if carpet_layer != null:
		carpet_layer.boost_at(pos, mult)

func add_carpet_patch(pos: Vector2, radius: float) -> void:
	if carpet_layer != null:
		carpet_layer.add_patch(pos, radius)

func _physics_process(delta: float) -> void:
	if carpet_fever_timer > 0.0:
		carpet_fever_timer -= delta
		if carpet_fever_timer <= 0.0 and carpet_layer != null:
			carpet_layer.set_fever(0.0)
	if spore_burst_timer > 0.0:
		spore_burst_timer -= delta
		if spore_burst_timer <= 0.0:
			spore_burst_active = false
	if resonate_timer > 0.0:
		resonate_timer -= delta
		_tick_resonate(delta)
	_tick_dragon_eggs(delta)
	# 建造幽灵跟随鼠标
	if placing_unit_id >= 0:
		ghost.visible = true
		ghost.unit_id = placing_unit_id
		ghost.race = current_race
		ghost.position = get_global_mouse_position()
		var def: Dictionary = Config.unit_at(current_race, placing_unit_id)
		var sc: int = Config.supply_cost(def) if current_race == "human" else 0
		ghost.valid = (not def.is_empty()) and _can_place(ghost.position) \
			and money >= int(def.get("cost", 0)) and supply >= sc
		ghost.queue_redraw()
	else:
		ghost.visible = false
	# 波次出怪
	if state == GameState.WAVING:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and not spawn_queue.is_empty():
			_spawn_enemy(int(spawn_queue.pop_front()))
			spawn_timer = Config.spawn_interval(wave_index)

func _tick_resonate(_delta: float) -> void:
	for u in units_layer.get_children():
		if u.race != "silicon":
			continue
		var reach: float = float(u.def.get("range", 120.0)) + 40.0
		for e in enemies_layer.get_children():
			if u.position.distance_to(e.position) <= reach:
				e.apply_damage(6.0, 1.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if state == GameState.GAME_OVER or state == GameState.WIN:
		if event is InputEventKey and event.pressed and event.keycode == KEY_T:
			_toggle_language()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			_toggle_language()
			return
		if event.keycode == KEY_ESCAPE:
			_cancel_placement()
			_deselect_unit()
			return
		if event.keycode == KEY_1:
			_on_skill()
			return
		if event.keycode == KEY_2:
			_on_skill_alt()
			return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var world_pos: Vector2 = get_global_mouse_position()
				if placing_unit_id >= 0 and _can_manage():
					# 点在已有单位上：取消召唤预览并选中
					if _unit_near(world_pos) != null:
						_cancel_placement()
						_on_unit_click(world_pos)
					else:
						_try_place(world_pos)
				else:
					_on_unit_click(world_pos)
			MOUSE_BUTTON_RIGHT:
				_cancel_placement()
				_deselect_unit()

# ---------- 中/英切换（CO-002） ----------
func _toggle_language() -> void:
	var cur: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en" if cur == "zh_CN" else "zh_CN")
	hud.refresh_texts()
	# 结算遮罩的文案由键生成，需要按当前语言重建
	if state == GameState.GAME_OVER:
		hud.show_overlay(tr("overlay_game_over"), tr("overlay_defeat") % [wave_index, units_lost])
	elif state == GameState.WIN:
		hud.show_overlay(tr("overlay_victory"), tr("overlay_victory_msg") % [Config.TOTAL_WAVES, lives, units_lost])
	elif selected_unit != null:
		_on_unit_click(selected_unit.position)
	# 状态栏为瞬时提示，下次触发时自然使用新语言

# ---------- 部署（CO-011：全程可管理） ----------
func _can_manage() -> bool:
	return state == GameState.PLANNING or state == GameState.WAVING

func add_supply(amount: int) -> void:
	if amount <= 0 or current_race != "human":
		return
	var before: int = supply
	supply = mini(Config.MAX_SUPPLY, supply + amount)
	hud.set_supply(supply)
	if supply >= Config.MAX_SUPPLY and before < Config.MAX_SUPPLY:
		hud.set_status(tr("msg_supply_full"))

func refill_depots() -> void:
	if current_race != "human" or units_layer == null:
		return
	for u in units_layer.get_children():
		if u != null and is_instance_valid(u) and u.has_method("refill_depot_stock"):
			u.refill_depot_stock()

func _farmer_count() -> int:
	var n := 0
	for u in units_layer.get_children():
		if u != null and is_instance_valid(u) and Config.is_farmer(u.def):
			n += 1
	return n

func _depot_count() -> int:
	var n := 0
	for u in units_layer.get_children():
		if u != null and is_instance_valid(u) and Config.is_depot(u.def):
			n += 1
	return n

func _on_buy_requested(unit_id: int) -> void:
	if not _can_manage():
		return
	var def: Dictionary = Config.unit_at(current_race, unit_id)
	if def.is_empty() or not bool(def.get("buyable", true)):
		hud.set_status(tr("msg_no_place"))
		return
	_deselect_unit()
	if placing_unit_id == unit_id:
		_cancel_placement()
		return
	placing_unit_id = unit_id
	hud.set_placing(true)
	hud.set_status(tr("msg_summon_hint") % tr(def["name_key"]))

func _cancel_placement() -> void:
	placing_unit_id = -1
	hud.set_placing(false)

func _try_place(pos: Vector2) -> void:
	if not _can_manage() or placing_unit_id < 0:
		return
	var def: Dictionary = Config.unit_at(current_race, placing_unit_id)
	if def.is_empty() or not bool(def.get("buyable", true)):
		hud.set_status(tr("msg_no_place"))
		_cancel_placement()
		return
	var cost := int(def["cost"])
	var sc: int = Config.supply_cost(def) if current_race == "human" else 0
	if money < cost:
		hud.set_status(tr("msg_no_money"))
		return
	if supply < sc:
		hud.set_status(tr("msg_no_supply"))
		return
	if Config.is_farmer(def) and _farmer_count() >= Config.FARMER_MAX:
		hud.set_status(tr("msg_farmer_cap"))
		return
	if Config.is_depot(def) and _depot_count() >= Config.DEPOT_MAX:
		hud.set_status(tr("msg_depot_cap"))
		return
	if not _can_place(pos):
		hud.set_status(tr("msg_no_place"))
		return
	var unit_script: Script = load("res://scripts/unit.gd") as Script
	if unit_script == null:
		hud.set_status("单位脚本加载失败")
		return
	var u: Node = unit_script.new()
	if u == null:
		hud.set_status("单位创建失败")
		return
	money -= cost
	supply -= sc
	hud.set_money(money)
	hud.set_supply(supply)
	# CO-004 修复：先定位再 setup（setup 快照 home=守位点；顺序反了 home 会是 (0,0)）
	u.position = pos
	units_layer.add_child(u)
	u.setup(def, enemies_layer, projectiles_layer, units_layer, self, current_race)
	if current_race == "fungus":
		register_fungus_source(pos, def)
	# 新补给站落成：闲置农民重新寻站
	if Config.is_depot(def):
		for fu in units_layer.get_children():
			if fu != u and Config.is_farmer(fu.def) and fu.get("_depot") == null and fu.has_method("_seek_depot"):
				fu._seek_depot()
	u.died.connect(_on_unit_died)
	# CO-011：波中部署须立即进入战斗，否则新兵站桩不动
	if state == GameState.WAVING and not Config.is_farmer(def) and not Config.is_depot(def):
		u.set_combat(true)
	hud.set_status(tr("msg_summoned") % tr(def["name_key"]))
	_cancel_placement()
	if current_race == "dragon" and units_layer.get_child_count() >= int(Config.SKILL_DRAGON.get("max_units", 4)):
		hud.set_status(tr("msg_dragon_cap"))

func _can_place(pos: Vector2) -> bool:
	# BUG2 修复：越界禁止（原实现无边界检查，可在屏幕外建造）
	if pos.x < Config.UNIT_RADIUS or pos.y < Config.UNIT_RADIUS \
			or pos.x > Config.VIEW_SIZE.x - Config.UNIT_RADIUS \
			or pos.y > Config.VIEW_SIZE.y - Config.UNIT_RADIUS:
		return false
	# BUG1 修复：按点到线段距离判走廊（原实现只查顶点，走廊中段可建在路径上）
	if Config.dist_to_path(pos) < Config.PATH_HALF_WIDTH + Config.UNIT_RADIUS:
		return false
	if current_race == "dragon":
		var max_n: int = int(Config.SKILL_DRAGON.get("max_units", 4))
		if units_layer.get_child_count() >= max_n:
			return false
	if current_race == "human" and placing_unit_id >= 0:
		var pdef: Dictionary = Config.unit_at(current_race, placing_unit_id)
		if Config.is_farmer(pdef) and _farmer_count() >= Config.FARMER_MAX:
			return false
		if Config.is_depot(pdef) and _depot_count() >= Config.DEPOT_MAX:
			return false
	for u in units_layer.get_children():
		if u.position.distance_to(pos) < Config.TOWER_MIN_DIST:
			return false
	return true

func _unit_near(pos: Vector2) -> Node:
	var hit: Node = null
	var best_d := INF
	for u in units_layer.get_children():
		if u == null or not is_instance_valid(u):
			continue
		var r: float = float(u.def.get("radius", 12.0)) + 36.0
		var body: Vector2 = u.position + Vector2(0.0, -28.0)
		var d: float = mini(u.position.distance_to(pos), body.distance_to(pos))
		if d <= r and d < best_d:
			best_d = d
			hit = u
	return hit

func _on_unit_click(pos: Vector2) -> void:
	var hit: Node = _unit_near(pos)
	if hit == null:
		_deselect_unit()
		return
	selected_unit = hit
	for u in units_layer.get_children():
		u.selected = (u == hit)
	var title := tr("stat_title") % [tr(hit.def["name_key"]), tr("stat_hp"), int(hit.hp), int(hit.max_hp)]
	var stats: String
	if current_race == "fungus":
		stats = tr("stat_line_fungus") % [hit.split_tier, hit.effective_damage(), hit.effective_rate()]
	elif str(hit.def.get("kind", "")) == "healer":
		stats = tr("stat_line_healer") % [int(hit.mana), int(hit.max_mana), float(hit.def.get("heal_amount", 0.0)), float(hit.def.get("mana_cost", 0.0))]
	elif Config.is_farmer(hit.def):
		stats = tr("stat_line_farmer")
	elif Config.is_depot(hit.def):
		stats = tr("stat_line_depot") % [int(hit.depot_stock), Config.DEPOT_STOCK_MAX]
	else:
		stats = tr("stat_line") % [hit.segment, int(hit.def["speed"]), float(hit.def["damage"]), float(hit.def["rate"])]
	var ev_cost: int = hit.evolve_cost()
	var can_split: bool = current_race == "fungus" and hit.can_split()
	var can_evolve: bool = ev_cost > 0
	if can_evolve and current_race == "human":
		var next_id: int = int(hit.def.get("evolves_to", -1))
		var next_def: Dictionary = Config.evolve_next(current_race, next_id)
		if supply < Config.supply_cost(next_def):
			can_evolve = false
	hud.show_info(title, stats, ev_cost, hit.sell_value(), can_evolve, can_split)

func _deselect_unit() -> void:
	selected_unit = null
	if units_layer == null:
		return
	for u in units_layer.get_children():
		u.selected = false
	hud.hide_info()

# ---------- 进化 / 出售 ----------
func _on_evolve() -> void:
	if not _can_manage() or selected_unit == null:
		return
	var cost: int = selected_unit.evolve_cost()
	if cost <= 0:
		return
	if money < cost:
		hud.set_status(tr("msg_no_money_evolve"))
		return
	var next_id: int = int(selected_unit.def.get("evolves_to", -1))
	var next_def: Dictionary = Config.evolve_next(current_race, next_id)
	var sc: int = Config.supply_cost(next_def) if current_race == "human" else 0
	if supply < sc:
		hud.set_status(tr("msg_no_supply"))
		return
	money -= cost
	supply -= sc
	hud.set_money(money)
	hud.set_supply(supply)
	selected_unit.evolve()
	hud.set_status(tr("msg_evolved") % tr(selected_unit.def["name_key"]))
	_on_unit_click(selected_unit.position)

func _on_sell() -> void:
	if not _can_manage() or selected_unit == null:
		return
	if Config.is_depot(selected_unit.def) and selected_unit.has_method("eject_depot_workers"):
		selected_unit.eject_depot_workers()
	money += selected_unit.sell_value()
	hud.set_money(money)
	hud.set_status(tr("msg_sold") % selected_unit.sell_value())
	selected_unit.queue_free()
	_deselect_unit()

func _on_split() -> void:
	if not _can_manage() or selected_unit == null:
		return
	if not selected_unit.can_split():
		hud.set_status(tr("msg_split_max"))
		return
	var spot: Vector2 = find_fungus_bud_spot(selected_unit.position, float(selected_unit.def["radius"]))
	if spot == Vector2.ZERO:
		hud.set_status(tr("msg_split_no_place"))
		return
	spawn_fungus_bud(selected_unit, spot)

# ---------- 主动技能 ----------
func _on_skill() -> void:
	if state != GameState.WAVING:
		hud.set_status(tr("msg_skill_wave_only"))
		return
	match current_race:
		"human":
			_skill_human_rally()
		"fungus":
			_skill_fungus_fever()
		"silicon":
			_skill_silicon_freeze()
		"dragon":
			_skill_dragon_breath()
		_:
			hud.set_status(tr("msg_skill_none"))

func _on_skill_alt() -> void:
	if state != GameState.WAVING:
		hud.set_status(tr("msg_skill_wave_only"))
		return
	match current_race:
		"fungus":
			_skill_fungus_spore_burst()
		"silicon":
			_skill_silicon_resonate()
		_:
			hud.set_status(tr("msg_skill_alt_none"))

func _skill_human_rally() -> void:
	if wave_index - skill1_last_wave < int(Config.SKILL_RALLY["cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill1_last_wave + int(Config.SKILL_RALLY["cd_waves"])))
		return
	skill1_last_wave = wave_index
	hud.set_skill_ready(false)
	for u in units_layer.get_children():
		u.apply_attack_speed_buff(float(Config.SKILL_RALLY["as_mult"]), float(Config.SKILL_RALLY["duration"]))
	hud.set_status(tr("msg_rally"))

func _skill_fungus_fever() -> void:
	var sk: Dictionary = Config.SKILL_FUNGUS
	if wave_index - skill1_last_wave < int(sk["carpet_fever_cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill1_last_wave + int(sk["carpet_fever_cd_waves"])))
		return
	skill1_last_wave = wave_index
	hud.set_skill_ready(false)
	carpet_fever_timer = float(sk["carpet_fever_duration"])
	if carpet_layer != null:
		carpet_layer.set_fever(float(sk["carpet_fever_slow_bonus"]))
	# 沸腾同时短暂武装传染链
	spore_burst_active = true
	spore_burst_timer = maxf(spore_burst_timer, float(sk["carpet_fever_duration"]))
	hud.set_status(tr("msg_fungus_fever"))

func _skill_fungus_spore_burst() -> void:
	var sk: Dictionary = Config.SKILL_FUNGUS
	if wave_index - skill2_last_wave < int(sk["spore_burst_cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill2_last_wave + int(sk["spore_burst_cd_waves"])))
		return
	skill2_last_wave = wave_index
	spore_burst_active = true
	spore_burst_timer = float(sk.get("spore_burst_duration", 8.0))
	var marked := 0
	for e in enemies_layer.get_children():
		if is_on_carpet(e.position):
			e.mark_infected()
			marked += 1
	if marked == 0:
		for e in enemies_layer.get_children():
			e.mark_infected()
			marked += 1
	hud.set_status(tr("msg_fungus_spore") % marked)

func _skill_silicon_freeze() -> void:
	var sk: Dictionary = Config.SKILL_SILICON
	if crystal_energy < int(sk["freeze_cost"]):
		hud.set_status(tr("msg_no_crystal"))
		return
	if wave_index - skill1_last_wave < int(sk["cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill1_last_wave + int(sk["cd_waves"])))
		return
	var foes: Array = enemies_layer.get_children()
	if foes.is_empty():
		hud.set_status(tr("msg_no_enemy"))
		return
	skill1_last_wave = wave_index
	crystal_energy -= int(sk["freeze_cost"])
	hud.set_crystal(crystal_energy)
	hud.set_skill_ready(false)
	# 冻结最靠近终点的若干敌人
	foes.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.waypoint_index) > int(b.waypoint_index)
	)
	var n: int = mini(int(sk.get("freeze_targets", 3)), foes.size())
	var dur: float = float(sk.get("freeze_duration", 3.0))
	for i in range(n):
		foes[i].apply_freeze(dur)
	hud.set_status(tr("msg_silicon_freeze") % n)

func _skill_silicon_resonate() -> void:
	var sk: Dictionary = Config.SKILL_SILICON
	if crystal_energy < int(sk["resonate_cost"]):
		hud.set_status(tr("msg_no_crystal"))
		return
	if wave_index - skill2_last_wave < int(sk["cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill2_last_wave + int(sk["cd_waves"])))
		return
	skill2_last_wave = wave_index
	crystal_energy -= int(sk["resonate_cost"])
	hud.set_crystal(crystal_energy)
	resonate_timer = float(sk["resonate_duration"])
	hud.set_status(tr("msg_silicon_resonate"))

func _skill_dragon_breath() -> void:
	var sk: Dictionary = Config.SKILL_DRAGON
	if wave_index - skill1_last_wave < int(sk["cd_waves"]):
		hud.set_status(tr("msg_skill_cd") % (skill1_last_wave + int(sk["cd_waves"])))
		return
	skill1_last_wave = wave_index
	hud.set_skill_ready(false)
	var mult: float = float(sk.get("burn_mult", 1.5))
	var dur: float = float(sk.get("duration", 5.0))
	for e in enemies_layer.get_children():
		e.apply_burn(12.0 * mult, dur)
	hud.set_status(tr("msg_dragon_breath"))

func queue_dragon_reincubate(u_def: Dictionary, pos: Vector2) -> void:
	var sec: float = float(Config.SKILL_DRAGON.get("reincubate_sec", 7.0))
	# 回巢从同系幼龙重新成长
	var hatch_def: Dictionary = Config.unit_at("dragon", _dragon_whelp_id(int(u_def.get("id", 0))))
	if hatch_def.is_empty():
		hatch_def = u_def
	dragon_eggs.append({"time": sec, "def": hatch_def.duplicate(true), "pos": pos})
	hud.set_status(tr("msg_dragon_egg") % int(ceil(sec)))

func _dragon_whelp_id(unit_id: int) -> int:
	if unit_id in [0, 4, 7]:
		return 0
	if unit_id in [1, 5, 8]:
		return 1
	if unit_id in [2, 6, 9]:
		return 2
	if unit_id in [3, 10, 11]:
		return 3
	return 0

func _tick_dragon_eggs(delta: float) -> void:
	if dragon_eggs.is_empty():
		return
	var remain: Array = []
	for egg in dragon_eggs:
		egg["time"] = float(egg["time"]) - delta
		if float(egg["time"]) > 0.0:
			remain.append(egg)
			continue
		_hatch_dragon(egg["def"], egg["pos"])
	dragon_eggs = remain

func _hatch_dragon(u_def: Dictionary, pos: Vector2) -> void:
	var max_n: int = int(Config.SKILL_DRAGON.get("max_units", 4))
	if units_layer.get_child_count() >= max_n:
		dragon_eggs.append({"time": 2.0, "def": u_def, "pos": pos})
		return
	var u: Node = load("res://scripts/unit.gd").new()
	u.position = pos
	units_layer.add_child(u)
	u.setup(u_def, enemies_layer, projectiles_layer, units_layer, self, "dragon")
	u.died.connect(_on_unit_died)
	if state == GameState.WAVING:
		u.set_combat(true)
	hud.set_status(tr("msg_dragon_hatch") % tr(str(u_def.get("name_key", "d_unit_0"))))

func _refresh_skill_ready() -> void:
	var sk: Dictionary = Config.RACES[current_race]["active_skill"]
	var cd: int = int(sk.get("cd_waves", sk.get("carpet_fever_cd_waves", 2)))
	hud.set_skill_ready(wave_index - skill1_last_wave >= cd)

# ---------- 波次 ----------
func _on_start_wave() -> void:
	if state != GameState.PLANNING or not spawn_queue.is_empty():
		return
	_cancel_placement()
	_deselect_unit()
	state = GameState.WAVING
	wave_index += 1
	for u in units_layer.get_children():
		u.set_combat(true)
	spawn_queue = Config.wave_composition(wave_index).duplicate()
	enemies_alive = spawn_queue.size()
	spawn_timer = 0.6
	hud.set_during_wave(true)
	hud.set_wave(wave_index)
	if current_race == "human" and wave_index == 4:
		hud.set_status(tr("msg_wave_armored"))
	elif current_race == "human" and spawn_queue.has(3):
		hud.set_status(tr("msg_wave_incoming_armored") % wave_index)
	else:
		hud.set_status(tr("msg_wave_incoming") % wave_index)

func _spawn_enemy(eid: int) -> void:
	var e: Node = load("res://scripts/enemy.gd").new()
	enemies_layer.add_child(e)
	e.setup(Config.ENEMIES[eid], wave_index, units_layer, self)
	e.died.connect(_on_enemy_died)
	e.escaped.connect(_on_enemy_escaped)

func _on_enemy_died(reward: int) -> void:
	enemies_alive -= 1
	money += reward
	hud.set_money(money)
	_check_wave_clear()

func _on_enemy_escaped() -> void:
	enemies_alive -= 1
	lives -= 1
	hud.set_lives(lives)
	if lives <= 0:
		state = GameState.GAME_OVER
		hud.show_overlay(tr("overlay_game_over"), tr("overlay_defeat") % [wave_index, units_lost])
		return
	_check_wave_clear()

func _on_unit_died() -> void:
	units_lost += 1
	hud.set_losses(units_lost)

func _check_wave_clear() -> void:
	if state != GameState.WAVING:
		return
	if not spawn_queue.is_empty() or enemies_alive > 0:
		return
	var bonus := Config.WAVE_CLEAR_BONUS_BASE + wave_index * Config.WAVE_CLEAR_BONUS_PER_WAVE
	money += bonus
	hud.set_money(money)
	for u in units_layer.get_children():
		u.set_combat(false)
	if carpet_layer != null:
		carpet_layer.spread(wave_index)
	if current_race == "silicon":
		crystal_energy = mini(4, crystal_energy + maxi(1, units_layer.get_child_count()))
		hud.set_crystal(crystal_energy)
	spore_burst_active = false
	if wave_index >= Config.TOTAL_WAVES:
		state = GameState.WIN
		hud.show_overlay(tr("overlay_victory"), tr("overlay_victory_msg") % [Config.TOTAL_WAVES, lives, units_lost])
	else:
		state = GameState.PLANNING
		_cancel_placement()
		refill_depots()
		hud.set_during_wave(false)
		_refresh_skill_ready()
		hud.set_status(tr("msg_wave_cleared") % [wave_index, bonus])

# ---------- 其它 ----------
func _on_speed_toggled() -> void:
	if Engine.time_scale == 1.0:
		Engine.time_scale = 2.0
		hud.set_speed_text(tr("hud_speed_2x"))
	else:
		Engine.time_scale = 1.0
		hud.set_speed_text(tr("hud_speed_1x"))

func _on_restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

# CO-003：任意时刻返回主菜单（不保存进度，原型行为明确）
func _on_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://menu.tscn")
