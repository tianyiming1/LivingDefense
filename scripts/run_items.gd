# CO-021 / CO-029：局内轻量装备（EQ-01～05）
# 每局最多 3 件；局终清空；不跨局养成；强度受难度门禁约束。
extends Node

const MAX_SLOTS := 3
const ITEM_DEFS := {
	"EQ-01": {"name_key": "item_eq01"},
	"EQ-02": {"name_key": "item_eq02"},
	"EQ-03": {"name_key": "item_eq03"},
	"EQ-04": {"name_key": "item_eq04"},
	"EQ-05": {"name_key": "item_eq05"},
}

var _main: Node = null
var items: Array[String] = []
var _tar_armed := false  # 下一波生效
var _tar_active := false
var _tar_wave_cd := 0
var _bandage_used_wave := -99
var _pending_replace_id := ""
var _eq05_skill_used := false

func setup(main: Node) -> void:
	_main = main

func clear_run() -> void:
	items.clear()
	_tar_armed = false
	_tar_active = false
	_tar_wave_cd = 0
	_bandage_used_wave = -99
	_pending_replace_id = ""
	_eq05_skill_used = false
	_refresh_hud()

func has_pending_choice() -> bool:
	return _pending_replace_id != ""

func has_item(id: String) -> bool:
	return id in items

func try_grant(id: String, silent: bool = false) -> bool:
	if not ITEM_DEFS.has(id):
		return false
	if id in items:
		if _main != null:
			_main.money += 15
			_main.hud.set_money(_main.money)
			if not silent:
				_main.hud.set_status(tr("item_dup_gold"))
		return false
	if items.size() >= MAX_SLOTS:
		_pending_replace_id = id
		if _main != null and not silent:
			var old_name := tr(str(ITEM_DEFS[items[0]]["name_key"]))
			var new_name := tr(str(ITEM_DEFS[id]["name_key"]))
			_main.hud.set_status(tr("item_replace_ask") % [old_name, new_name])
		return false
	_add_item(id, silent)
	return true

func handle_choice_yes() -> bool:
	if _pending_replace_id == "":
		return false
	var new_id := _pending_replace_id
	_pending_replace_id = ""
	var dropped: String = items.pop_front()
	_on_item_removed(dropped)
	_add_item(new_id, false)
	if _main != null:
		_main.hud.set_status(tr("item_replace_yes") % [
			tr(str(ITEM_DEFS[dropped]["name_key"])),
			tr(str(ITEM_DEFS[new_id]["name_key"]))
		])
	return true

func handle_choice_no() -> bool:
	if _pending_replace_id == "":
		return false
	_pending_replace_id = ""
	if _main != null:
		_main.money += 20
		_main.hud.set_money(_main.money)
		_main.hud.set_status(tr("item_replace_no"))
	return true

func _add_item(id: String, silent: bool) -> void:
	items.append(id)
	if id == "EQ-02":
		_tar_armed = true
	_refresh_hud()
	if not silent and _main != null:
		_main.hud.set_status(tr("item_got") % tr(str(ITEM_DEFS[id]["name_key"])))
	if AudioController:
		AudioController.play("crystal_clink", Vector2.ZERO)

func _on_item_removed(id: String) -> void:
	if id == "EQ-02":
		_tar_armed = false
		_tar_active = false
		_tar_wave_cd = 0

func on_wave_started(wave: int) -> void:
	if _tar_armed:
		_tar_active = true
		_tar_armed = false
		_tar_wave_cd = 0
		if _main != null:
			_main.hud.set_status(tr("item_tar_active"))
	elif _tar_active:
		_tar_wave_cd += 1
		if _tar_wave_cd >= 3:
			_tar_armed = true
			_tar_active = false
			_tar_wave_cd = 0
	if _main == null:
		return
	# EQ-05 硅基：每波 +1 晶能（上限仍 4）
	if has_item("EQ-05") and str(_main.current_race) == "silicon":
		_main.crystal_energy = mini(4, int(_main.crystal_energy) + 1)
		_main.hud.set_crystal(_main.crystal_energy)
		_main.hud.set_status(tr("item_shard_crystal"))
	# EQ-05 他族：整局一次提前技能 CD
	elif has_item("EQ-05") and not _eq05_skill_used and str(_main.current_race) != "silicon":
		_eq05_skill_used = true
		_main.skill1_last_wave = int(wave) - 99
		_main.hud.set_status(tr("item_shard_skill"))
		if _main.has_method("_refresh_skill_ready"):
			_main._refresh_skill_ready()

func on_wave_cleared(leaked: bool) -> void:
	if has_item("EQ-01") and not leaked:
		_main.money += 25
		_main.hud.set_money(_main.money)
		_main.hud.set_status(tr("item_bounty_proc"))

func tick_combat(_delta: float) -> void:
	if _main == null:
		return
	if _tar_active and _main.state == _main.GameState.WAVING:
		_apply_tar_slow()
	if has_item("EQ-03"):
		_try_bandage()

## EQ-04 人族：进化补给消耗减免（≥0）
func evolve_supply_discount() -> int:
	if has_item("EQ-04") and _main != null and str(_main.current_race) == "human":
		return 2
	return 0

## EQ-04 他族：击杀额外金
func on_enemy_killed_bonus() -> int:
	if has_item("EQ-04") and _main != null and str(_main.current_race) != "human":
		return 1
	return 0

func grant_random_from_pool() -> void:
	var pool: Array[String] = ["EQ-01", "EQ-02", "EQ-03", "EQ-04", "EQ-05"]
	var id: String = pool[randi() % pool.size()]
	try_grant(id)

func _apply_tar_slow() -> void:
	var pts: Array = Config.PATH_POINTS
	if pts.size() < 2:
		return
	var total := 0.0
	var seglen: Array[float] = []
	for i in range(pts.size() - 1):
		var L: float = pts[i].distance_to(pts[i + 1])
		seglen.append(L)
		total += L
	if total <= 1.0:
		return
	for e in _main.enemies_layer.get_children():
		if e == null or not is_instance_valid(e) or not e.alive:
			continue
		var prog := _enemy_path_progress(e, pts, seglen, total)
		if prog >= 0.80:
			e.slow_factor = minf(float(e.slow_factor), 0.80)
			e.slow_timer = maxf(float(e.slow_timer), 0.35)

func _enemy_path_progress(e: Node, pts: Array, seglen: Array[float], total: float) -> float:
	var wi: int = int(e.get("waypoint_index"))
	var done := 0.0
	for i in range(mini(wi, seglen.size())):
		if i < wi - 1:
			done += seglen[i]
	# 粗估：已达路点比例
	return clampf(float(wi) / float(maxi(pts.size() - 1, 1)), 0.0, 1.0)

func _try_bandage() -> void:
	var wave: int = int(_main.wave_index)
	if _bandage_used_wave == wave:
		return
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u) or bool(u.get("dead")):
			continue
		var hp: float = float(u.get("hp"))
		var max_hp: float = float(u.get("max_hp"))
		if max_hp <= 0.0:
			continue
		if hp / max_hp < 0.25 and hp > 0.0:
			if u.has_method("apply_heal"):
				u.apply_heal(max_hp * 0.40)
			_bandage_used_wave = wave
			_main.hud.set_status(tr("item_bandage_proc") % tr(str(u.def.get("name_key", "unit_0"))))
			return

func _refresh_hud() -> void:
	if _main == null or _main.hud == null:
		return
	if _main.hud.has_method("set_run_items"):
		var keys: Array[String] = []
		for id in items:
			keys.append(tr(str(ITEM_DEFS[id]["name_key"])))
		_main.hud.set_run_items(keys)
