# ============================================================
# The Living Rampart ? ?????single source of truth?
# ????? F5 ????????? HUMAN_UNITS
# S1 ???CO-001????/??/???/?/??
# ============================================================
class_name Config

# ---- 地图 PATH（CO-022/025：独立 map 资源可切换；默认 Map A = 原 S 形）----
const DEFAULT_MAP_ID := "map_a"
const MAP_RESOURCE_PATHS := {
	"map_a": "res://resources/maps/map_a.tres",
	"map_b": "res://resources/maps/map_b.tres",
	"map_c": "res://resources/maps/map_c.tres",
}
# 与 map_a.tres 冻结一致；无 meta / 加载失败时仍走此路径
const PATH_POINTS_MAP_A: Array[Vector2] = [
	Vector2(-90, 540), Vector2(480, 540), Vector2(480, 180),
	Vector2(1080, 180), Vector2(1080, 900), Vector2(1560, 900),
	Vector2(1560, 420), Vector2(1860, 420),
]
static var active_map_id: String = DEFAULT_MAP_ID
static var PATH_POINTS: Array[Vector2] = PATH_POINTS_MAP_A.duplicate()
const PATH_HALF_WIDTH := 36.0   # 走廊半宽（大地图略加宽可读）
const UNIT_RADIUS := 12.0       # 单位半径（放置互斥）
const TOWER_RADIUS := 14.0      # 塔视觉半径
const TOWER_MIN_DIST := 50.0    # 单位最小间距
const VIEW_SIZE := Vector2(1280, 720)  # 窗口 / 战场 16:9（须与 project.godot 窗口基准同一律）
const MAP_SIZE := Vector2(1920, 1080)  # 世界地图（CO-ART W3：大于视口）
## 顶栏+状态净空（CO-037 安全带上沿）
const HUD_TOP_SAFE_PX := 70.0
## 底栏常驻高度；须 ≤120（CO-037：底栏带 y∈[600,720]）；镜头 offset 同步
const HUD_BOTTOM_PX := 120.0

static func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, MAP_SIZE)

## CO-022：按 map_id 切换 PATH；未知 id 回退 Map A。不改波次公式。
static func apply_map(map_id: String) -> void:
	var id := map_id if MAP_RESOURCE_PATHS.has(map_id) else DEFAULT_MAP_ID
	var res_path: String = MAP_RESOURCE_PATHS[id]
	if ResourceLoader.exists(res_path):
		var data: Resource = load(res_path)
		if data != null and data.has_method("to_path_array"):
			var pts: Array[Vector2] = data.to_path_array()
			if pts.size() >= 2:
				active_map_id = str(data.get("id")) if str(data.get("id")) != "" else id
				PATH_POINTS = pts
				return
	# 资源缺失时硬编码回退，保证默认图可玩
	active_map_id = DEFAULT_MAP_ID
	PATH_POINTS = PATH_POINTS_MAP_A.duplicate()

static func list_map_ids() -> Array[String]:
	var out: Array[String] = []
	for k in MAP_RESOURCE_PATHS.keys():
		out.append(str(k))
	out.sort()
	return out

# CO-001-S1-BUG1：走廊距离按当前 PATH_POINTS
static func dist_to_path(pos: Vector2) -> float:
	var best := INF
	var pts := PATH_POINTS
	for i in range(pts.size() - 1):
		var d: float = Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1]).distance_to(pos)
		if d < best:
			best = d
	return best

# ---- 经济 / 生命（CO-011：人族补给为第二建造闸门）----
const START_MONEY := 450
const START_LIVES := 100  # CO-032：大本营 HP（旧抽象命 32 过松）
const HQ_MAX_HP := 100.0
const START_SUPPLY := 32  # CO-020：略逼早建站（旧 36）
const MAX_SUPPLY := 48
const SELL_REFUND_RATIO := 0.6    # 出售返还 60%
const WAVE_CLEAR_BONUS_BASE := 55  # CO-030：旧 70 → 收经济过松
const WAVE_CLEAR_BONUS_PER_WAVE := 8  # CO-030：旧 10
# 人族农民 / 补给站（CO-011）：农民进站才产；站有库存上限，清波补满
# CO-020：产速/站库存收紧——满产仍要抉择；不建站会卡
const FARMER_MAX := 4
const FARMER_SUPPLY_INTERVAL := 3.0
const FARMER_SUPPLY_AMOUNT := 2  # CO-020：旧 3 → 拉长补给抉择窗口
const FARMER_SPEED := 58.0
const DEPOT_MAX := 3
const DEPOT_SLOTS := 2
const DEPOT_ENTER_DIST := 20.0
const DEPOT_STOCK_MAX := 24  # CO-020：旧 30 → 清波补满后仍要管农

# ---- 波次 / 敌 ----
const TOTAL_WAVES := 18  # CO-038：12→18，拉长战役
const WAVE_ENEMY_ATTACK_RANGE := 100.0  # CO-040：远程贴廊也会被咬到
const ENEMY_AGGRO_RANGE := 140.0         # CO-040：怪会短暂冲向附近远程
const ENEMY_RADIUS := 10.0
const ENEMY_MIN_SEP := 14.0
# CO-038：场上「英雄」军衔上限（仅 id19）
const HUMAN_HERO_UNIT_ID := 19
const HUMAN_HERO_MAX := 2

# ---- 人族单位（CO-042：科技分支 ≠ 军衔）----
# 军衔：单兵进化（步兵 10–19；弓手 20–23；牧师 50–51）
# 科技：大本营分支等级 → 全族相关 kind 强化；专精解锁箭塔/法师/牧师
# 编制：步兵/弓箭手/箭塔/法师(AOE)/牧师；无火枪；迫击不直购
const HUMAN_UNITS := [
	{"id": 0, "name_key": "unit_0", "name": "Infantry", "cost": 60, "hp": 380.0, "speed": 50.0, "range": 60.0, "damage": 22.0, "rate": 1.1, "kind": "melee", "radius": 11.0, "evolves_to": 10, "segment": 1, "supply_cost": 0, "buyable": true, "color": Color(0.42, 0.55, 0.85)},
	{"id": 1, "name_key": "unit_1", "name": "Archer", "cost": 70, "hp": 185.0, "speed": 58.0, "range": 175.0, "damage": 28.0, "rate": 1.25, "kind": "single", "radius": 11.0, "evolves_to": 20, "segment": 1, "supply_cost": 4, "buyable": true, "color": Color(0.45, 0.62, 0.40)},
	# CO-042：编制=步兵/弓/箭塔/法师(群体AOE)/牧师(+军衔)；迫击下架不直购
	{"id": 2, "name_key": "unit_2", "name": "Mortar", "cost": 150, "hp": 240.0, "speed": 48.0, "range": 190.0, "damage": 32.0, "rate": 1.05, "kind": "splash", "radius": 12.0, "evolves_to": -1, "segment": 3, "supply_cost": 18, "buyable": false, "tech": "siege", "color": Color(0.45, 0.35, 0.25), "splash_radius": 82.0},
	{"id": 3, "name_key": "unit_3", "name": "Arrow Tower", "cost": 110, "hp": 360.0, "speed": 0.0, "range": 220.0, "damage": 30.0, "rate": 1.15, "kind": "aa", "radius": 14.0, "evolves_to": -1, "segment": 1, "supply_cost": 8, "buyable": true, "tech": "arbalest", "stationary": true, "color": Color(0.55, 0.55, 0.62)},
	{"id": 4, "name_key": "unit_4", "name": "Cleric", "cost": 90, "hp": 160.0, "speed": 62.0, "range": 155.0, "damage": 0.0, "rate": 0.85, "kind": "healer", "radius": 11.0, "evolves_to": 50, "segment": 1, "supply_cost": 12, "buyable": true, "tech": "chapel", "color": Color(0.85, 0.85, 0.95), "mana_max": 100.0, "mana_cost": 20.0, "heal_amount": 52.0, "mana_regen": 7.0},
	{"id": 5, "name_key": "unit_5", "name": "Farmer", "cost": 55, "hp": 95.0, "speed": 58.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "farmer", "radius": 12.0, "evolves_to": 60, "segment": 1, "supply_cost": 0, "buyable": true, "color": Color(0.55, 0.48, 0.22)},
	{"id": 6, "name_key": "unit_6", "name": "Supply Depot", "cost": 80, "hp": 220.0, "speed": 0.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "depot", "radius": 18.0, "evolves_to": 70, "segment": 1, "supply_cost": 0, "buyable": true, "stationary": true, "color": Color(0.40, 0.55, 0.28)},
	{"id": 8, "name_key": "unit_8", "name": "Mage", "cost": 95, "hp": 145.0, "speed": 52.0, "range": 200.0, "damage": 42.0, "rate": 0.85, "kind": "spell", "radius": 11.0, "evolves_to": -1, "segment": 1, "supply_cost": 10, "buyable": true, "tech": "arcane", "color": Color(0.55, 0.35, 0.90), "burn_dps": 10.0, "burn_duration": 3.5, "splash_radius": 85.0},
	# 步兵军衔（单兵）
	{"id": 10, "name_key": "unit_10", "name": "Captain", "cost": 80, "hp": 400.0, "speed": 51.0, "range": 62.0, "damage": 24.0, "rate": 1.12, "kind": "melee", "radius": 11.0, "evolves_to": 11, "segment": 2, "supply_cost": 0, "buyable": false, "evolve_min_wave": 2, "color": Color(0.45, 0.58, 0.88)},
	{"id": 11, "name_key": "unit_11", "name": "Sergeant Major", "cost": 100, "hp": 470.0, "speed": 52.0, "range": 64.0, "damage": 28.0, "rate": 1.14, "kind": "melee", "radius": 11.5, "evolves_to": 12, "segment": 2, "supply_cost": 0, "buyable": false, "evolve_min_wave": 4, "color": Color(0.48, 0.60, 0.90)},
	{"id": 12, "name_key": "unit_12", "name": "Regiment CO", "cost": 120, "hp": 550.0, "speed": 52.0, "range": 66.0, "damage": 33.0, "rate": 1.15, "kind": "melee", "radius": 12.0, "evolves_to": 13, "segment": 3, "supply_cost": 0, "buyable": false, "evolve_min_wave": 6, "color": Color(0.52, 0.62, 0.92)},
	{"id": 13, "name_key": "unit_13", "name": "Division CO", "cost": 145, "hp": 640.0, "speed": 53.0, "range": 68.0, "damage": 38.0, "rate": 1.16, "kind": "melee", "radius": 12.0, "evolves_to": 14, "segment": 3, "supply_cost": 0, "buyable": false, "evolve_min_wave": 8, "color": Color(0.55, 0.55, 0.88)},
	{"id": 14, "name_key": "unit_14", "name": "Corps CO", "cost": 175, "hp": 740.0, "speed": 53.0, "range": 70.0, "damage": 44.0, "rate": 1.18, "kind": "melee", "radius": 12.5, "evolves_to": 15, "segment": 3, "supply_cost": 0, "buyable": false, "evolve_min_wave": 10, "color": Color(0.60, 0.50, 0.82)},
	{"id": 15, "name_key": "unit_15", "name": "Commander", "cost": 210, "hp": 860.0, "speed": 54.0, "range": 72.0, "damage": 50.0, "rate": 1.20, "kind": "melee", "radius": 13.0, "evolves_to": 16, "segment": 4, "supply_cost": 0, "buyable": false, "evolve_min_wave": 12, "color": Color(0.70, 0.48, 0.55)},
	{"id": 16, "name_key": "unit_16", "name": "Grand Commander", "cost": 255, "hp": 1000.0, "speed": 54.0, "range": 74.0, "damage": 58.0, "rate": 1.22, "kind": "melee", "radius": 13.0, "evolves_to": 17, "segment": 4, "supply_cost": 0, "buyable": false, "evolve_min_wave": 13, "color": Color(0.80, 0.45, 0.40)},
	{"id": 17, "name_key": "unit_17", "name": "Marshal", "cost": 310, "hp": 1160.0, "speed": 55.0, "range": 76.0, "damage": 66.0, "rate": 1.24, "kind": "melee", "radius": 13.5, "evolves_to": 18, "segment": 4, "supply_cost": 0, "buyable": false, "evolve_min_wave": 14, "color": Color(0.88, 0.50, 0.28)},
	{"id": 18, "name_key": "unit_18", "name": "Commission CO", "cost": 380, "hp": 1340.0, "speed": 55.0, "range": 78.0, "damage": 76.0, "rate": 1.26, "kind": "melee", "radius": 14.0, "evolves_to": 19, "segment": 5, "supply_cost": 0, "buyable": false, "evolve_min_wave": 16, "color": Color(0.95, 0.62, 0.22)},
	{"id": 19, "name_key": "unit_19", "name": "Hero", "cost": 480, "hp": 1600.0, "speed": 56.0, "range": 82.0, "damage": 90.0, "rate": 1.30, "kind": "melee", "radius": 15.0, "evolves_to": -1, "segment": 5, "supply_cost": 0, "buyable": false, "evolve_min_wave": 17, "color": Color(1.0, 0.78, 0.25), "is_hero": true},
	# 弓手军衔（单兵，不进火器）
	{"id": 20, "name_key": "unit_20", "name": "Longbow", "cost": 85, "hp": 190.0, "speed": 57.0, "range": 185.0, "damage": 30.0, "rate": 1.28, "kind": "single", "radius": 11.0, "evolves_to": 21, "segment": 2, "supply_cost": 4, "buyable": false, "evolve_min_wave": 3, "color": Color(0.42, 0.68, 0.38)},
	{"id": 21, "name_key": "unit_21", "name": "Sharpshooter", "cost": 100, "hp": 210.0, "speed": 56.0, "range": 195.0, "damage": 36.0, "rate": 1.30, "kind": "single", "radius": 11.0, "evolves_to": 22, "segment": 2, "supply_cost": 6, "buyable": false, "evolve_min_wave": 5, "color": Color(0.38, 0.58, 0.42)},
	{"id": 22, "name_key": "unit_22", "name": "Veteran Archer", "cost": 130, "hp": 245.0, "speed": 55.0, "range": 205.0, "damage": 44.0, "rate": 1.32, "kind": "single", "radius": 11.5, "evolves_to": 23, "segment": 3, "supply_cost": 8, "buyable": false, "evolve_min_wave": 8, "color": Color(0.35, 0.55, 0.40)},
	{"id": 23, "name_key": "unit_23", "name": "Eagle Eye", "cost": 180, "hp": 290.0, "speed": 54.0, "range": 220.0, "damage": 56.0, "rate": 1.35, "kind": "single", "radius": 12.0, "evolves_to": -1, "segment": 4, "supply_cost": 10, "buyable": false, "evolve_min_wave": 12, "color": Color(0.32, 0.52, 0.38)},
	# 牧师军衔（单兵）
	{"id": 50, "name_key": "unit_50", "name": "Priest", "cost": 120, "hp": 190.0, "speed": 60.0, "range": 165.0, "damage": 0.0, "rate": 0.90, "kind": "healer", "radius": 11.0, "evolves_to": 51, "segment": 2, "supply_cost": 12, "buyable": false, "evolve_min_wave": 6, "color": Color(0.88, 0.88, 0.98), "mana_max": 120.0, "mana_cost": 18.0, "heal_amount": 68.0, "mana_regen": 8.5},
	{"id": 51, "name_key": "unit_51", "name": "Bishop", "cost": 170, "hp": 230.0, "speed": 58.0, "range": 175.0, "damage": 0.0, "rate": 0.95, "kind": "healer", "radius": 11.5, "evolves_to": -1, "segment": 3, "supply_cost": 14, "buyable": false, "evolve_min_wave": 11, "color": Color(0.92, 0.90, 1.0), "mana_max": 150.0, "mana_cost": 16.0, "heal_amount": 88.0, "mana_regen": 10.0},
	# 后勤军衔（短）
	{"id": 60, "name_key": "unit_60", "name": "Overseer", "cost": 75, "hp": 120.0, "speed": 60.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "farmer", "radius": 12.0, "evolves_to": 61, "segment": 2, "supply_cost": 0, "buyable": false, "evolve_min_wave": 5, "color": Color(0.58, 0.50, 0.25), "supply_amount": 3},
	{"id": 61, "name_key": "unit_61", "name": "Steward", "cost": 100, "hp": 145.0, "speed": 62.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "farmer", "radius": 12.0, "evolves_to": -1, "segment": 3, "supply_cost": 0, "buyable": false, "evolve_min_wave": 10, "color": Color(0.62, 0.52, 0.28), "supply_amount": 4},
	{"id": 70, "name_key": "unit_70", "name": "Fortified Depot", "cost": 110, "hp": 320.0, "speed": 0.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "depot", "radius": 18.0, "evolves_to": 71, "segment": 2, "supply_cost": 0, "buyable": false, "stationary": true, "evolve_min_wave": 6, "color": Color(0.38, 0.52, 0.26), "stock_max": 32},
	{"id": 71, "name_key": "unit_71", "name": "Grand Depot", "cost": 160, "hp": 420.0, "speed": 0.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "depot", "radius": 19.0, "evolves_to": -1, "segment": 3, "supply_cost": 0, "buyable": false, "stationary": true, "evolve_min_wave": 11, "color": Color(0.35, 0.50, 0.24), "stock_max": 40},
]

## 军衔进化费用（键=目标 id）；专精强化走科技分支，不在此
const HUMAN_OFFICER_EVOLVE_COST := {
	10: 55, 11: 75, 12: 100, 13: 130, 14: 165,
	15: 210, 16: 270, 17: 340, 18: 430, 19: 560,
	20: 55, 21: 75, 22: 110, 23: 160,
	50: 70, 51: 110,
	60: 50, 61: 80, 70: 70, 71: 120,
}

## 敌人技能文案键（点选面板用）
static func enemy_skill_keys(e_def: Dictionary) -> Array[String]:
	var keys: Array[String] = ["enemy_skill_basic"]
	if is_flying_enemy(e_def):
		keys.append("enemy_skill_flying")
	if bool(e_def.get("armored", false)):
		keys.append("enemy_skill_armored")
	if float(e_def.get("aura_haste", 0.0)) > 0.0:
		keys.append("enemy_skill_haste_aura")
	if float(e_def.get("shield_hp", 0.0)) > 0.0:
		keys.append("enemy_skill_shield")
	if bool(e_def.get("phase_armor", false)):
		keys.append("enemy_skill_phase_armor")
	if bool(e_def.get("boss", false)):
		keys.append("enemy_skill_boss")
	elif bool(e_def.get("elite", false)):
		keys.append("enemy_skill_elite")
	return keys

static func is_human_hero(u_def: Dictionary) -> bool:
	return bool(u_def.get("is_hero", false)) or int(u_def.get("id", -1)) == HUMAN_HERO_UNIT_ID
# ????/???CO-004??aggro 300?leash 130????????
const MELEE_CHASE := 48.0
const MELEE_AGGRO_RANGE := 380.0
const MELEE_INTERCEPT_LEASH := 260.0  # CO-039：拉长拦截，出兵后主动顶走廊
# CO-041：接敌呼唤——一兵开战，呼唤身边友军跟进（可连锁扩散）
const ASSIST_CALL_RADIUS := 240.0
const ASSIST_CALL_INTERVAL := 0.55
const ASSIST_HOLD_SEC := 3.8
const ASSIST_MAX_FROM_HOME := 440.0
## CO-042：点选士兵右键下令——派往落点 / 攻击区域或单体
const ORDER_AREA_RADIUS := 150.0
const ORDER_ARRIVE_DIST := 8.0
# ????????????????? + ?????CO-004 ? 80 ?? 15?
const RANGED_CHASE := 15.0
const RANGED_COMBAT_BONUS := 95.0   # 离走廊越远射程补偿
const RANGED_AGGRO_EXTRA := 140.0   # 超出命中距离仍可锁定，便于自动开火
const PROJECTILE_SPEED_SINGLE := 540.0
const PROJECTILE_SPEED_SPLASH := 300.0
const PROJECTILE_SPEED_AA := 500.0

# ---- ????S1 ???----
const MAX_TOWER_LEVEL := 3    # ?? 3 ???? x1.5 ? / +15% ?
# ??????????? x0.7 x ??????????????????
static func upgrade_cost(base_cost: int, level: int) -> int:
	return int(ceil(float(base_cost) * 0.7 * float(level)))

# ---- ????????????Rally Fire?----
const SKILL_RALLY := {"as_mult": 1.65, "duration": 9.0, "cd_waves": 2}

# ---- 敌兵（S1 三怪 + CO-012 铁皮护甲）----
# attack = 对单位伤害；attack_interval = 攻击间隔
const ENEMIES := [
	# CO-038：基础面板抬高
	{"id": 0, "name_key": "enemy_0", "name": "Grunt",   "hp": 52.0,  "speed": 70.0,  "reward": 11, "attack": 12.0, "attack_interval": 1.0,  "color": Color(0.75, 0.20, 0.20)},
	{"id": 1, "name_key": "enemy_1", "name": "Runner",  "hp": 32.0,  "speed": 118.0, "reward": 15, "attack": 6.0,  "attack_interval": 0.65, "color": Color(0.20, 0.55, 0.85)},
	{"id": 2, "name_key": "enemy_2", "name": "Tank",    "hp": 280.0, "speed": 40.0,  "reward": 28, "attack": 44.0, "attack_interval": 0.78, "color": Color(0.45, 0.40, 0.50)},
	{"id": 3, "name_key": "enemy_3", "name": "Armored", "hp": 115.0, "speed": 54.0,  "reward": 18, "attack": 16.0, "attack_interval": 0.95,  "armored": true, "armor_melee": 0.28, "armor_ranged": 0.95, "armor_splash": 1.15, "color": Color(0.62, 0.64, 0.70)},
	{"id": 4, "name_key": "enemy_4", "name": "Siege Herald", "hp": 360.0, "speed": 36.0, "reward": 65, "attack": 48.0, "attack_interval": 0.82, "elite": true, "shield_hp": 130.0, "color": Color(0.90, 0.40, 0.15)},
	{"id": 5, "name_key": "enemy_5", "name": "Night Courier", "hp": 130.0, "speed": 95.0, "reward": 50, "attack": 16.0, "attack_interval": 0.60, "elite": true, "aura_haste": 1.28, "aura_range": 78.0, "color": Color(0.58, 0.22, 0.78)},
	{"id": 6, "name_key": "enemy_6", "name": "Rampart Maw", "hp": 520.0, "speed": 34.0, "reward": 120, "attack": 46.0, "attack_interval": 0.85, "elite": true, "boss": true, "shield_hp": 150.0, "phase_armor": true, "color": Color(0.82, 0.12, 0.32)},
	# CO-039：飞行单位——近战打不到，仅远程（弓/枪/迫击/弩/法师等）可击
	{"id": 7, "name_key": "enemy_7", "name": "Sky Raider", "hp": 48.0, "speed": 88.0, "reward": 18, "attack": 10.0, "attack_interval": 0.85, "flying": true, "color": Color(0.55, 0.75, 0.95)},
]

# HP 随波成长（CO-042：去火枪后略缓，给弓/法师/箭塔节奏）
static func enemy_hp(id: int, wave: int) -> float:
	return float(ENEMIES[id]["hp"]) * (1.0 + float(wave - 1) * 0.12)

static func enemy_attack_mult(wave: int) -> float:
	# CO-042：编制改远程/AOE后，略降怪攻成长，避免前排被瞬删
	return clampf(0.55 + float(wave - 1) * 0.030, 0.55, 0.95)

## CO-039：飞行敌
static func is_flying_enemy(e_def: Dictionary) -> bool:
	return bool(e_def.get("flying", false)) or bool(e_def.get("can_fly", false))

## 单位能否攻击飞行敌（近战/农民/站/治疗不可）
static func unit_can_hit_air(u_def: Dictionary) -> bool:
	var k: String = str(u_def.get("kind", ""))
	return k in ["single", "splash", "aa", "spell", "charge", "spike", "fly"]

# CO-012：护甲怪按伤害类型承伤倍率
static func armor_damage_mult(e_def: Dictionary, dmg_kind: String) -> float:
	if not bool(e_def.get("armored", false)):
		return 1.0
	match dmg_kind:
		"melee":
			return float(e_def.get("armor_melee", 0.32))
		"splash":
			return float(e_def.get("armor_splash", 1.2))
		"single", "aa", "ranged", "spell":
			return float(e_def.get("armor_ranged", 1.0))
		_:
			return float(e_def.get("armor_generic", 1.0))

# CO-030/038：每波显式主题表——构成不同 + 总压递进（禁止纯线性同构）
static func wave_composition(wave: int) -> Array:
	match wave:
		1:
			return [0, 0, 0, 0, 0]
		2:
			return [0, 0, 0, 0, 0, 0, 2]
		3:
			return [0, 0, 0, 0, 0, 0, 0, 2, 2]
		4:
			return [0, 0, 0, 0, 0, 0, 3, 3, 2]
		5:
			# 首跑者 + 首飞翼（教弓/箭塔对空）
			return [0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 1, 7]
		6:
			return [0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 7]
		7:
			# CO-042：中盘减同时威胁，给编制重建窗口
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 1, 7]
		8:
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 1]
		9:
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 1, 7]
		10:
			return [0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 1, 7]
		11:
			return [0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 1, 1, 7]
		12:
			# 双精英课：夜驿使 + 攻城传令
			return [0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 1, 5, 4, 7]
		13:
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 2, 2, 1, 1, 1, 7, 7]
		14:
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 3, 2, 1, 1, 1, 5, 7]
		15:
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 4]
		16:
			return [0, 0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 1, 5]
		17:
			# 终局前喘息，Boss 在波18
			return [0, 0, 0, 0, 0, 0, 0, 3, 3, 2, 2, 1, 1, 7]
		18:
			return [0, 0, 0, 0, 0, 0, 3, 3, 2, 1, 1, 5, 4, 6, 7]
		_:
			return [0, 0, 0, 0]

## 精英/主题波状态句键（空=走通用或词缀句）
static func wave_banner_key(wave: int) -> String:
	match wave:
		2:
			return "wave_banner_2"
		4:
			return "wave_banner_4"
		5:
			return "wave_banner_5"
		6:
			return "wave_banner_6"
		7:
			return "wave_banner_7"
		8:
			return "wave_banner_8"
		9:
			return "wave_banner_9"
		10:
			return "wave_banner_10"
		11:
			return "wave_banner_11"
		12:
			return "wave_banner_12"
		15:
			return "wave_banner_15"
		18:
			return "wave_banner_18"
		_:
			return ""

# ---- CO-026/028：开波轻词缀（确定性；收档后仍可读）----
static var wave_enemy_speed_mult: float = 1.0
static var wave_enemy_reward_mult: float = 1.0
static var active_wave_affix: String = ""

## 本波词缀 id；空=无。不改随机种子，保证 Autoplay 可复现。
static func wave_affix_id(wave: int) -> String:
	match wave:
		3:
			return "fat_purse"
		5, 10, 15:
			return "iron_tide"
		7, 11, 16:
			return "swift_curse"
		8, 14:
			return "glass_swarm"
		_:
			return ""

static func wave_affix_banner_key(affix_id: String) -> String:
	if affix_id == "":
		return ""
	return "affix_" + affix_id

## 应用词缀到本波倍率，并改写构成表（原地）。
static func apply_wave_affix(wave: int, composition: Array) -> String:
	wave_enemy_speed_mult = 1.0
	wave_enemy_reward_mult = 1.0
	active_wave_affix = ""
	var aid: String = wave_affix_id(wave)
	if aid == "":
		return ""
	active_wave_affix = aid
	match aid:
		"fat_purse":
			wave_enemy_reward_mult = 1.25  # CO-028：旧 1.35 → 收经济过松
		"swift_curse":
			wave_enemy_speed_mult = 1.10  # CO-028：旧 1.14
		"iron_tide":
			composition.append(3)  # CO-028：旧 +2 → +1
		"glass_swarm":
			composition.append(0)
			composition.append(0)
			composition.append(1)  # CO-028：旧 +4/+1 → +2/+1
	return aid

static func clear_wave_affix() -> void:
	wave_enemy_speed_mult = 1.0
	wave_enemy_reward_mult = 1.0
	active_wave_affix = ""

# ??????????????????
static func spawn_interval(wave: int) -> float:
	# CO-030：后期出怪更快，压迫感递进
	return max(0.42, 0.92 - float(wave) * 0.040)

# CO-031/038：人族进化价；其它族保持原系数
static func evolve_cost(u_def: Dictionary, segment: int) -> int:
	var next_id: int = int(u_def.get("evolves_to", -1))
	if HUMAN_OFFICER_EVOLVE_COST.has(next_id):
		return int(HUMAN_OFFICER_EVOLVE_COST[next_id])
	var mult: float = 0.5
	return int(ceil(float(u_def["cost"]) * mult * float(segment)))

## 进化目标是否达到波次门槛（CO-036 军衔）
static func evolve_wave_ok(next_def: Dictionary, wave_index: int) -> bool:
	var need: int = int(next_def.get("evolve_min_wave", 0))
	if need <= 0:
		return true
	# wave_index 为已清波数；当前可开战波 = wave_index+1
	return wave_index + 1 >= need

# 出售返还 60% 已投入金币
static func sell_value(invested: int) -> int:
	return int(round(float(invested) * SELL_REFUND_RATIO))

## CO-032：漏怪对大本营伤害（机制课：怪种不同伤不同）
static func hq_leak_damage(e_def: Dictionary) -> int:
	if bool(e_def.get("boss", false)):
		return 18
	if bool(e_def.get("elite", false)):
		return 12
	if is_flying_enemy(e_def):
		return 8  # 飞翼漏过：略高于小兵
	match int(e_def.get("id", 0)):
		1:
			return 5   # 跑者
		2:
			return 12  # 坦克
		3:
			return 9   # 铁皮
		_:
			return 7   # 小兵

# CO-011：单位建造/进化所需补给（非人族单位默认 0）
static func supply_cost(u_def: Dictionary) -> int:
	return int(u_def.get("supply_cost", 0))

static func is_farmer(u_def: Dictionary) -> bool:
	return str(u_def.get("kind", "")) == "farmer"

static func is_depot(u_def: Dictionary) -> bool:
	return str(u_def.get("kind", "")) == "depot"

static func depot_slot_offset(slot: int) -> Vector2:
	# 工位环绕补给站，避免完全重叠
	var ang: float = -PI * 0.5 + float(slot) * (PI / float(maxi(Config.DEPOT_SLOTS, 1)))
	return Vector2(cos(ang), sin(ang)) * 16.0

# ---- ????? ----
const SKILL_FUNGUS := {"carpet_fever_slow_bonus": 0.28, "carpet_fever_duration": 4.0, "carpet_fever_cd_waves": 3, "spore_burst_cd_waves": 2, "spore_burst_duration": 8.0}
const SKILL_SILICON := {"resonate_cost": 2, "freeze_cost": 2, "cd_waves": 2, "resonate_duration": 6.0, "freeze_duration": 3.0, "freeze_targets": 3}
const SKILL_DRAGON := {"burn_mult": 2.0, "duration": 6.0, "cd_waves": 3, "max_units": 4, "reincubate_sec": 7.0}

const FUNGUS_UNITS := [
	{"id": 0, "name_key": "f_unit_0", "name": "Toxic Mushroom", "cost": 60, "hp": 150.0, "speed": 0.0, "range": 58.0, "damage": 11.0, "rate": 0.95, "kind": "melee", "radius": 10.0, "evolves_to": -1, "segment": 1, "stationary": true, "carpet_grow_mult": 1.0, "color": Color(0.25, 0.55, 0.15), "apply_poison": true, "poison_duration": 4.5, "poison_dps": 3.0},
	{"id": 1, "name_key": "f_unit_1", "name": "Spore Mushroom", "cost": 100, "hp": 120.0, "speed": 0.0, "range": 140.0, "damage": 10.0, "rate": 1.0, "kind": "splash", "radius": 10.0, "evolves_to": -1, "segment": 1, "stationary": true, "carpet_grow_mult": 1.0, "color": Color(0.35, 0.45, 0.10), "splash_radius": 78.0, "infect_radius": 95.0},
	{"id": 2, "name_key": "f_unit_2", "name": "Carpet Mushroom", "cost": 70, "hp": 110.0, "speed": 0.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "aura", "radius": 10.0, "evolves_to": -1, "segment": 1, "stationary": true, "carpet_grow_mult": 2.2, "color": Color(0.15, 0.35, 0.05), "aura_range": 70.0, "aura_slow": 0.18, "aura_tick_interval": 0.65},
	{"id": 3, "name_key": "f_unit_3", "name": "Paralyzer Mushroom", "cost": 80, "hp": 115.0, "speed": 0.0, "range": 120.0, "damage": 10.0, "rate": 0.8, "kind": "single", "radius": 10.0, "evolves_to": -1, "segment": 1, "stationary": true, "carpet_grow_mult": 1.0, "color": Color(0.45, 0.25, 0.15), "paralyze_duration": 2.5, "paralyze_cd": 3.5},
]

const DRAGON_UNITS := [
	# —— 可购买：多种幼龙 + 龙人 ——
	{"id": 0, "name_key": "d_unit_0", "name": "Flame Whelp", "cost": 90, "hp": 140.0, "speed": 100.0, "range": 100.0, "damage": 12.0, "rate": 2.1, "kind": "fly", "radius": 14.0, "evolves_to": 4, "segment": 1, "buyable": true, "color": Color(0.85, 0.25, 0.18), "can_fly": true, "burn_dps": 12.0, "burn_tick_interval": 0.5, "burn_duration": 5.0},
	{"id": 1, "name_key": "d_unit_1", "name": "Ironscale Whelp", "cost": 100, "hp": 200.0, "speed": 58.0, "range": 70.0, "damage": 18.0, "rate": 1.05, "kind": "burst", "radius": 14.0, "evolves_to": 5, "segment": 1, "buyable": true, "color": Color(0.75, 0.35, 0.15), "can_fly": false, "burn_dps": 10.0, "burn_tick_interval": 1.0, "burn_duration": 6.0, "shield_hp_ratio": 0.40, "shield_duration": 3.5},
	{"id": 2, "name_key": "d_unit_2", "name": "Blast Whelp", "cost": 110, "hp": 160.0, "speed": 48.0, "range": 58.0, "damage": 16.0, "rate": 0.85, "kind": "explode", "radius": 16.0, "evolves_to": 6, "segment": 1, "buyable": true, "color": Color(0.70, 0.15, 0.08), "can_fly": false, "explode_damage": 70.0, "explode_radius": 60.0},
	# 龙人：可步行；待机浮空扇翅；全员施法（火亚种）；背翼独立于手臂
	{"id": 3, "name_key": "d_unit_3", "name": "Fire Longren", "cost": 85, "hp": 240.0, "speed": 52.0, "range": 125.0, "damage": 16.0, "rate": 0.95, "kind": "spell", "radius": 12.0, "evolves_to": 10, "segment": 1, "buyable": true, "color": Color(0.95, 0.35, 0.12), "can_fly": false, "hover_idle": true, "burn_dps": 10.0, "burn_tick_interval": 0.6, "burn_duration": 4.5},
	# —— 亚龙（仅进化） ——
	{"id": 4, "name_key": "d_unit_4", "name": "Flame Drake", "cost": 140, "hp": 200.0, "speed": 108.0, "range": 115.0, "damage": 20.0, "rate": 2.3, "kind": "fly", "radius": 15.0, "evolves_to": 7, "segment": 2, "buyable": false, "color": Color(0.95, 0.30, 0.12), "can_fly": true, "burn_dps": 18.0, "burn_tick_interval": 0.45, "burn_duration": 5.5},
	{"id": 5, "name_key": "d_unit_5", "name": "Ironscale Drake", "cost": 150, "hp": 300.0, "speed": 62.0, "range": 75.0, "damage": 26.0, "rate": 1.15, "kind": "burst", "radius": 15.0, "evolves_to": 8, "segment": 2, "buyable": false, "color": Color(0.85, 0.40, 0.12), "can_fly": false, "burn_dps": 16.0, "burn_tick_interval": 0.9, "burn_duration": 7.0, "shield_hp_ratio": 0.50, "shield_duration": 4.5},
	{"id": 6, "name_key": "d_unit_6", "name": "Blast Drake", "cost": 160, "hp": 240.0, "speed": 42.0, "range": 62.0, "damage": 22.0, "rate": 0.85, "kind": "explode", "radius": 18.0, "evolves_to": 9, "segment": 2, "buyable": false, "color": Color(0.65, 0.12, 0.06), "can_fly": false, "explode_damage": 100.0, "explode_radius": 70.0},
	# —— 成龙（仅进化） ——
	{"id": 7, "name_key": "d_unit_7", "name": "Flame Dragon", "cost": 200, "hp": 280.0, "speed": 115.0, "range": 130.0, "damage": 28.0, "rate": 2.4, "kind": "fly", "radius": 17.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(1.0, 0.35, 0.10), "can_fly": true, "burn_dps": 24.0, "burn_tick_interval": 0.4, "burn_duration": 6.5},
	{"id": 8, "name_key": "d_unit_8", "name": "Ironscale Dragon", "cost": 210, "hp": 420.0, "speed": 68.0, "range": 80.0, "damage": 34.0, "rate": 1.2, "kind": "burst", "radius": 17.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(0.90, 0.45, 0.10), "can_fly": false, "burn_dps": 22.0, "burn_tick_interval": 0.8, "burn_duration": 8.0, "shield_hp_ratio": 0.55, "shield_duration": 5.0},
	{"id": 9, "name_key": "d_unit_9", "name": "Blast Dragon", "cost": 220, "hp": 360.0, "speed": 40.0, "range": 68.0, "damage": 28.0, "rate": 0.9, "kind": "explode", "radius": 22.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(0.55, 0.08, 0.05), "can_fly": false, "explode_damage": 140.0, "explode_radius": 85.0},
	# —— 龙人进化 ——
	{"id": 10, "name_key": "d_unit_10", "name": "Fire Longren Adept", "cost": 130, "hp": 340.0, "speed": 54.0, "range": 140.0, "damage": 24.0, "rate": 1.05, "kind": "spell", "radius": 13.0, "evolves_to": 11, "segment": 2, "buyable": false, "color": Color(1.0, 0.40, 0.12), "can_fly": false, "hover_idle": true, "burn_dps": 16.0, "burn_tick_interval": 0.55, "burn_duration": 5.5},
	{"id": 11, "name_key": "d_unit_11", "name": "Fire Longren Lord", "cost": 180, "hp": 460.0, "speed": 56.0, "range": 155.0, "damage": 32.0, "rate": 1.15, "kind": "spell", "radius": 14.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(1.0, 0.45, 0.15), "can_fly": false, "hover_idle": true, "burn_dps": 22.0, "burn_tick_interval": 0.5, "burn_duration": 6.5},
	# —— CO-044/045：彩蛋线（搁置闸门；梦龙三阶 CO-045）——
	{"id": 12, "name_key": "d_unit_12", "name": "Frost Longren", "cost": 95, "hp": 230.0, "speed": 50.0, "range": 130.0, "damage": 15.0, "rate": 0.9, "kind": "spell", "radius": 12.0, "evolves_to": -1, "segment": 1, "buyable": true, "easter_egg": true, "color": Color(0.55, 0.82, 1.0), "can_fly": false, "hover_idle": true, "burn_dps": 8.0, "burn_tick_interval": 0.7, "burn_duration": 5.0},
	{"id": 13, "name_key": "d_unit_13", "name": "Mirror Whelp", "cost": 100, "hp": 130.0, "speed": 105.0, "range": 105.0, "damage": 13.0, "rate": 2.0, "kind": "fly", "radius": 14.0, "evolves_to": -1, "segment": 1, "buyable": true, "easter_egg": true, "color": Color(0.72, 0.35, 0.95), "can_fly": true, "burn_dps": 11.0, "burn_tick_interval": 0.5, "burn_duration": 4.5},
	{"id": 14, "name_key": "d_unit_14", "name": "Dream Whelp", "cost": 115, "hp": 160.0, "speed": 70.0, "range": 130.0, "damage": 10.0, "rate": 0.9, "kind": "spell", "radius": 11.0, "evolves_to": 15, "segment": 1, "buyable": true, "easter_egg": true, "color": Color(0.55, 0.75, 1.0), "can_fly": false, "can_fly_move": true, "hover_idle": true, "sleep_duration": 2.5, "sleep_cd": 5.5},
	# 亚龙：强化单体睡眠
	{"id": 15, "name_key": "d_unit_15", "name": "Dream Drake", "cost": 160, "hp": 240.0, "speed": 78.0, "range": 145.0, "damage": 14.0, "rate": 1.05, "kind": "spell", "radius": 13.0, "evolves_to": 16, "segment": 2, "buyable": false, "easter_egg": true, "color": Color(0.50, 0.70, 1.0), "can_fly": false, "can_fly_move": true, "hover_idle": true, "sleep_duration": 3.4, "sleep_cd": 4.8},
	# 青年龙：更长单体睡眠（群体留给成龙）
	{"id": 16, "name_key": "d_unit_16", "name": "Dream Youth", "cost": 190, "hp": 280.0, "speed": 82.0, "range": 152.0, "damage": 16.0, "rate": 1.08, "kind": "spell", "radius": 15.0, "evolves_to": 17, "segment": 3, "buyable": false, "easter_egg": true, "color": Color(0.48, 0.68, 0.99), "can_fly": false, "can_fly_move": true, "hover_idle": true, "sleep_duration": 3.8, "sleep_cd": 5.2},
	# 成龙：招牌群体睡眠 R=78 N≤5 短窗 + 梦雾
	{"id": 17, "name_key": "d_unit_17", "name": "Dream Adult", "cost": 230, "hp": 340.0, "speed": 88.0, "range": 165.0, "damage": 20.0, "rate": 1.12, "kind": "spell", "radius": 17.0, "evolves_to": -1, "segment": 4, "buyable": false, "easter_egg": true, "color": Color(0.42, 0.62, 0.98), "can_fly": false, "can_fly_move": true, "hover_idle": true, "sleep_duration": 2.2, "sleep_cd": 7.5, "sleep_aoe_radius": 78.0, "sleep_aoe_max": 5, "dream_mist_radius": 78.0, "dream_mist_slow": 0.12},
]

const SILICON_UNITS := [
	{"id": 0, "name_key": "si_unit_0", "name": "Silicon Core", "cost": 90, "hp": 180.0, "speed": 40.0, "range": 170.0, "damage": 32.0, "rate": 0.55, "kind": "charge", "radius": 11.0, "charge_time": 2.5, "evolves_to": -1, "segment": 1, "color": Color(0.2, 0.75, 0.95)},
	{"id": 1, "name_key": "si_unit_1", "name": "Silicon Spike", "cost": 110, "hp": 165.0, "speed": 44.0, "range": 200.0, "damage": 36.0, "rate": 0.6, "kind": "spike", "radius": 11.0, "charge_time": 1.8, "evolves_to": -1, "segment": 1, "color": Color(0.55, 0.85, 1.0)},
	{"id": 2, "name_key": "si_unit_2", "name": "Silicon Wall", "cost": 80, "hp": 320.0, "speed": 32.0, "range": 60.0, "damage": 12.0, "rate": 0.85, "kind": "wall", "radius": 14.0, "regen_time": 8.0, "damage_reduction": 0.5, "evolves_to": -1, "segment": 1, "color": Color(0.35, 0.55, 0.75)},
]

const RACES := {
	"human": {
		"resource_rule": "tech_tree",
		"units": HUMAN_UNITS,
		"active_skill": SKILL_RALLY,
		"core_decision": "tech_evolution_vs_production"
	},
	"fungus": {
		"resource_rule": "fungus",
		"units": FUNGUS_UNITS,
		"active_skill": SKILL_FUNGUS,
		"core_decision": "expansion_vs_upgrade"
	},
	"dragon": {
		"resource_rule": "dragon",
		"units": DRAGON_UNITS,
		"active_skill": SKILL_DRAGON,
		"core_decision": "hatch_timing_vs_hunt_route",
		# CO-044 搁置：隐藏解锁等剧情接入后再开；当前菜单公开可选
		"hidden": false,
	},

	"silicon": {
		"resource_rule": "silicon",
		"units": SILICON_UNITS,
		"active_skill": SKILL_SILICON,
		"core_decision": "topology_vs_burst_timing"
	},
}

const CARPET_SPREAD_PER_WAVE := 2
const CARPET_SPREAD_SPEED := 22.0
const CARPET_UNIT_SEED_RADIUS := 18.0
const CARPET_MAX_RADIUS := 200.0
const CARPET_SLOW := 0.22              # ???? 22%
const CARPET_ATTACK_SLOW := 0.18       # ??????? 18%
const CARPET_SPORE_VULN := 0.08        # ??????????? +8%
const CARPET_AURA_SLOW := 0.12
const CARPET_TICK_INTERVAL := 0.5
const FUNGUS_SPLIT_MAX := 3            # ???? 3 ???? 0~3?
const FUNGUS_SPLIT_ATTACK_MULT := 0.72
const FUNGUS_SPLIT_HP_MULT := 0.90
const FUNGUS_SPLIT_INTERVAL := 18.0
const FUNGUS_SPLIT_FIRST_DELAY := 8.0
const SPORE_INFECT_RADIUS := 90.0
const SILICON_LINK_RANGE := 72.0
const SILICON_CHAIN_BONUS := 0.10

## 菜单可选种族（尊重 hidden；搁置期龙族 hidden=false）
static func public_race_ids() -> Array[String]:
	var preferred: Array[String] = ["human", "fungus", "dragon", "silicon"]
	var ordered: Array[String] = []
	for p in preferred:
		if not RACES.has(p):
			continue
		if bool(RACES[p].get("hidden", false)):
			continue
		ordered.append(p)
	for id in RACES.keys():
		var sid := str(id)
		if sid in ordered:
			continue
		if bool(RACES[id].get("hidden", false)):
			continue
		ordered.append(sid)
	return ordered

static func is_race_hidden(race_name: String) -> bool:
	if not RACES.has(race_name):
		return false
	return bool(RACES[race_name].get("hidden", false))

static func race_units(race_name: String) -> Array:
	if RACES.has(race_name):
		return RACES[race_name]["units"]
	return HUMAN_UNITS

static func shop_units(race_name: String) -> Array:
	var out: Array = []
	# CO-044 搁置：剧情接入前彩蛋单位暂不闸门（仍保留 easter_egg 标记供后用）
	for u in race_units(race_name):
		if not bool(u.get("buyable", true)):
			continue
		out.append(u)
	return out

static func unit_at(race_name: String, unit_id: int) -> Dictionary:
	for u in race_units(race_name):
		if int(u["id"]) == unit_id:
			return u
	return {}

static func evolve_next(race_name: String, next_id: int) -> Dictionary:
	return unit_at(race_name, next_id)

# resource_rule ?????race_name: String -> dictionary?
# ?????????????? main.gd / ???? ??
static func resource_rule(race_name: String) -> Dictionary:
	if not RACES.has(race_name):
		return {}
	var race: Dictionary = RACES[race_name]
	return {
		"resource_rule": race["resource_rule"],
		"units": race["units"],
		"active_skill": race["active_skill"],
		"core_decision": race["core_decision"]
	}
