# CO-041：人族「科技分支」≠「单兵军衔」
# - 军衔：点选单个单位进化（步兵 / 弓手长链）
# - 科技：大本营分支升级；升一级 → 该分支所有相关兵种立刻变强
# - 已移除火枪手；远程从弓箭手起家
extends Node

## 分支表：levels[i] = 升到 i+1 级的费用与波次门槛；buff 按级累乘叠到相关兵
## unlocks：升到 1 级时解锁可购买的单位 id
const TECH_BRANCHES := {
	"infantry": {
		"name_key": "tech_infantry",
		"hint": "tech_hint_infantry",
		"kinds": ["melee"],
		"unlocks": [],
		"levels": [
			{"cost": 70, "min_wave": 2, "dmg": 1.12, "hp": 1.10, "range": 0.0},
			{"cost": 120, "min_wave": 5, "dmg": 1.24, "hp": 1.20, "range": 4.0},
			{"cost": 200, "min_wave": 9, "dmg": 1.38, "hp": 1.32, "range": 8.0},
		],
	},
	"archery": {
		"name_key": "tech_archery",
		"hint": "tech_hint_archery",
		"kinds": ["single"],
		"unlocks": [],
		"levels": [
			{"cost": 75, "min_wave": 2, "dmg": 1.14, "hp": 1.08, "range": 12.0},
			{"cost": 130, "min_wave": 5, "dmg": 1.28, "hp": 1.16, "range": 24.0},
			{"cost": 210, "min_wave": 9, "dmg": 1.45, "hp": 1.25, "range": 36.0},
		],
	},
	"logistics": {
		"name_key": "tech_logistics",
		"hint": "tech_hint_logistics",
		"kinds": ["farmer", "depot"],
		"unlocks": [],
		"levels": [
			{"cost": 60, "min_wave": 2, "hp": 1.15, "supply": 1, "stock": 6},
			{"cost": 110, "min_wave": 6, "hp": 1.30, "supply": 2, "stock": 12},
			{"cost": 180, "min_wave": 10, "hp": 1.45, "supply": 3, "stock": 18},
		],
	},
	"siege": {
		"name_key": "tech_siege",
		"hint": "tech_hint_siege",
		"kinds": ["splash", "spell"],
		"unlocks": [],
		"levels": [
			{"cost": 130, "min_wave": 4, "dmg": 1.12, "hp": 1.08, "range": 8.0, "splash": 10.0},
			{"cost": 190, "min_wave": 8, "dmg": 1.26, "hp": 1.18, "range": 16.0, "splash": 18.0},
			{"cost": 280, "min_wave": 12, "dmg": 1.42, "hp": 1.28, "range": 24.0, "splash": 28.0},
		],
	},
	"arcane": {
		"name_key": "tech_arcane",
		"hint": "tech_hint_arcane",
		"kinds": ["spell"],
		"unlocks": [8],
		"levels": [
			{"cost": 110, "min_wave": 3, "dmg": 1.16, "hp": 1.08, "range": 12.0, "burn": 1.2, "splash": 8.0},
			{"cost": 170, "min_wave": 7, "dmg": 1.34, "hp": 1.18, "range": 22.0, "burn": 1.45, "splash": 14.0},
			{"cost": 260, "min_wave": 11, "dmg": 1.55, "hp": 1.28, "range": 32.0, "burn": 1.7, "splash": 22.0},
		],
	},
	"chapel": {
		"name_key": "tech_chapel",
		"hint": "tech_hint_chapel",
		"kinds": ["healer"],
		"unlocks": [4],
		"levels": [
			{"cost": 100, "min_wave": 3, "heal": 1.18, "hp": 1.12, "mana": 1.15},
			{"cost": 160, "min_wave": 7, "heal": 1.36, "hp": 1.24, "mana": 1.30},
			{"cost": 240, "min_wave": 11, "heal": 1.55, "hp": 1.36, "mana": 1.45},
		],
	},
	"arbalest": {
		"name_key": "tech_arbalest",
		"hint": "tech_hint_arbalest",
		"kinds": ["aa"],
		"unlocks": [3],
		"levels": [
			{"cost": 95, "min_wave": 4, "dmg": 1.18, "hp": 1.10, "range": 15.0},
			{"cost": 150, "min_wave": 8, "dmg": 1.35, "hp": 1.20, "range": 28.0},
			{"cost": 230, "min_wave": 12, "dmg": 1.55, "hp": 1.32, "range": 40.0},
		],
	},
}

# 兼容旧 TECH_DEFS 键查询（HUD 等）
var TECH_DEFS: Dictionary = {}

var _main: Node = null
var tech_level: Dictionary = {}  # branch_id -> int 0..3
var unlocked_units: Dictionary = {}

func setup(main: Node) -> void:
	_main = main
	tech_level.clear()
	unlocked_units.clear()
	TECH_DEFS.clear()
	for bid in TECH_BRANCHES.keys():
		tech_level[bid] = 0
		TECH_DEFS[bid] = TECH_BRANCHES[bid]
	# 开局编制
	unlocked_units[0] = true
	unlocked_units[1] = true
	unlocked_units[5] = true
	unlocked_units[6] = true
	# 军衔链可进化
	for oid in range(10, 20):
		unlocked_units[oid] = true
	for oid in [20, 21, 22, 23, 50, 51, 60, 61, 70, 71]:
		unlocked_units[oid] = true

func is_unit_unlocked(unit_id: int) -> bool:
	return bool(unlocked_units.get(unit_id, false))

func is_researched(tech_id: String) -> bool:
	return tech_level_of(tech_id) > 0

func tech_level_of(tech_id: String) -> int:
	return int(tech_level.get(tech_id, 0))

func tech_max_level(tech_id: String) -> int:
	if not TECH_BRANCHES.has(tech_id):
		return 0
	return (TECH_BRANCHES[tech_id]["levels"] as Array).size()

func can_evolve_to(next_unit_id: int) -> bool:
	if next_unit_id < 0:
		return false
	return is_unit_unlocked(next_unit_id)

func tech_ids() -> Array[String]:
	return ["infantry", "archery", "logistics", "siege", "arcane", "chapel", "arbalest"]

func branch_of_unit(u_def: Dictionary) -> String:
	var k: String = str(u_def.get("kind", ""))
	# 法师：奥术为主；攻城溅射加成另由 splash_bonus 叠（见下方）
	for bid in ["infantry", "archery", "logistics", "arcane", "chapel", "arbalest", "siege"]:
		if not TECH_BRANCHES.has(bid):
			continue
		var kinds: Array = TECH_BRANCHES[bid].get("kinds", [])
		if k in kinds:
			return str(bid)
	return ""

func _buff_at(tech_id: String) -> Dictionary:
	var lv: int = tech_level_of(tech_id)
	if lv <= 0 or not TECH_BRANCHES.has(tech_id):
		return {}
	var levels: Array = TECH_BRANCHES[tech_id]["levels"]
	return levels[lv - 1]

func damage_mult(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	var m: float = float(b.get("dmg", 1.0))
	# 法师额外吃攻城分支的 dmg 半额（群体压线）
	if str(u_def.get("kind", "")) == "spell":
		var sb: Dictionary = _buff_at("siege")
		if not sb.is_empty():
			m *= 1.0 + (float(sb.get("dmg", 1.0)) - 1.0) * 0.35
	return m

func hp_mult(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return float(b.get("hp", 1.0))

func range_bonus(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return float(b.get("range", 0.0))

func splash_bonus(u_def: Dictionary) -> float:
	var k: String = str(u_def.get("kind", ""))
	var bonus: float = 0.0
	if k in ["splash", "spell"]:
		bonus += float(_buff_at("siege").get("splash", 0.0))
	if k == "spell":
		bonus += float(_buff_at("arcane").get("splash", 0.0))
	return bonus

func heal_mult(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return float(b.get("heal", 1.0))

func mana_mult(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return float(b.get("mana", 1.0))

func burn_mult(u_def: Dictionary) -> float:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return float(b.get("burn", 1.0))

func supply_bonus(u_def: Dictionary) -> int:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return int(b.get("supply", 0))

func stock_bonus(u_def: Dictionary) -> int:
	var b: Dictionary = _buff_at(branch_of_unit(u_def))
	return int(b.get("stock", 0))

func next_level_def(tech_id: String) -> Dictionary:
	if not TECH_BRANCHES.has(tech_id):
		return {}
	var lv: int = tech_level_of(tech_id)
	var levels: Array = TECH_BRANCHES[tech_id]["levels"]
	if lv >= levels.size():
		return {}
	return levels[lv]

func can_research(tech_id: String) -> bool:
	var nd: Dictionary = next_level_def(tech_id)
	if nd.is_empty():
		return false
	if _main == null:
		return false
	if int(_main.wave_index) + 1 < int(nd.get("min_wave", 0)):
		return false
	if int(_main.money) < int(nd.get("cost", 0)):
		return false
	return true

func research(tech_id: String) -> bool:
	if not can_research(tech_id):
		return false
	var nd: Dictionary = next_level_def(tech_id)
	var cost: int = int(nd["cost"])
	_main.money -= cost
	_main.hud.set_money(_main.money)
	var new_lv: int = tech_level_of(tech_id) + 1
	tech_level[tech_id] = new_lv
	# 首次解锁单位
	if new_lv == 1:
		for uid in TECH_BRANCHES[tech_id].get("unlocks", []):
			unlocked_units[int(uid)] = true
	var name_s: String = tr(str(TECH_BRANCHES[tech_id]["name_key"]))
	_main.hud.set_status(tr("tech_level_up") % [name_s, new_lv])
	_refresh_all_human_units()
	if _main.hud.has_method("refresh_tech_and_shop"):
		_main.hud.refresh_tech_and_shop()
	if AudioController:
		AudioController.play("upgrade", Vector2.ZERO)
	return true

func _refresh_all_human_units() -> void:
	if _main == null or _main.units_layer == null:
		return
	for u in _main.units_layer.get_children():
		if u == null or not is_instance_valid(u):
			continue
		if str(u.get("race")) != "human":
			continue
		if u.has_method("refresh_tech_stats"):
			u.refresh_tech_stats()

func research_block_reason(tech_id: String) -> String:
	if not TECH_BRANCHES.has(tech_id):
		return "tech_unknown"
	if next_level_def(tech_id).is_empty():
		return "tech_done"
	var nd: Dictionary = next_level_def(tech_id)
	if _main != null and int(_main.wave_index) + 1 < int(nd.get("min_wave", 0)):
		return "tech_need_wave"
	if _main != null and int(_main.money) < int(nd.get("cost", 0)):
		return "tech_need_money"
	return ""
