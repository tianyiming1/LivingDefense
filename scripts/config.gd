# ============================================================
# The Living Rampart ? ?????single source of truth?
# ????? F5 ????????? HUMAN_UNITS
# S1 ???CO-001????/??/???/?/??
# ============================================================
class_name Config

# ---- ?? ----
# ?????1280x720 ??????????????
const PATH_POINTS: Array[Vector2] = [
	Vector2(-60, 360), Vector2(320, 360), Vector2(320, 120),
	Vector2(720, 120), Vector2(720, 600), Vector2(1040, 600),
	Vector2(1040, 280), Vector2(1340, 280),
]
const PATH_HALF_WIDTH := 34.0   # ????
const UNIT_RADIUS := 12.0       # ????????
const TOWER_RADIUS := 14.0      # ??????????
const TOWER_MIN_DIST := 50.0    # ??????
const VIEW_SIZE := Vector2(1280, 720)  # ????

# ?????????????????????????
# ? CO-001-S1-BUG1???? PATH_POINTS ?????
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
const START_LIVES := 32
const START_SUPPLY := 36
const MAX_SUPPLY := 48
const SELL_REFUND_RATIO := 0.6    # 出售返还 60%
const WAVE_CLEAR_BONUS_BASE := 70
const WAVE_CLEAR_BONUS_PER_WAVE := 10
# 人族农民 / 补给站（CO-011）：农民进站才产；站有库存上限，清波补满
const FARMER_MAX := 4
const FARMER_SUPPLY_INTERVAL := 3.0
const FARMER_SUPPLY_AMOUNT := 3
const FARMER_SPEED := 58.0
const DEPOT_MAX := 3
const DEPOT_SLOTS := 2
const DEPOT_ENTER_DIST := 20.0
const DEPOT_STOCK_MAX := 30

# ---- 波次 / 敌 ----
const TOTAL_WAVES := 12
const WAVE_ENEMY_ATTACK_RANGE := 55.0   # ???????????CO-006 ? 130 ?? 55?
const ENEMY_AGGRO_RANGE := 80.0         # 敌人追击距离（降低，避免步兵被拖进怪群）
const ENEMY_RADIUS := 10.0
const ENEMY_MIN_SEP := 14.0             # ??????????

# ---- 人族单位（S1 + CO-011 农民/补给站）----
# kind: melee / single / splash / aa / aura / farmer / depot
# supply_cost: 建造或进化为目标时消耗的补给（步兵/农民/站=0）
# evolves_to: 下一段 id；-1 = 满级；进化费 = cost * 0.5 * 当前段
const HUMAN_UNITS := [
	{"id": 0, "name_key": "unit_0", "name": "Infantry",   "cost": 60,  "hp": 340.0, "speed": 50.0, "range": 60.0,  "damage": 20.0, "rate": 1.1,  "kind": "melee",  "radius": 11.0, "evolves_to": 1, "segment": 1, "supply_cost": 0,  "color": Color(0.42, 0.55, 0.85)},
	{"id": 1, "name_key": "unit_1", "name": "Musketeer",  "cost": 100, "hp": 240.0, "speed": 60.0, "range": 195.0, "damage": 42.0, "rate": 1.4,  "kind": "single", "radius": 11.0, "evolves_to": 2, "segment": 2, "supply_cost": 8,  "color": Color(0.30, 0.42, 0.70)},
	{"id": 2, "name_key": "unit_2", "name": "Mortar",     "cost": 150, "hp": 240.0, "speed": 48.0, "range": 190.0, "damage": 32.0, "rate": 1.05, "kind": "splash", "radius": 12.0, "evolves_to": -1, "segment": 3, "supply_cost": 18, "color": Color(0.45, 0.35, 0.25), "splash_radius": 82.0},
	{"id": 3, "name_key": "unit_3", "name": "Arbalest",   "cost": 110, "hp": 140.0, "speed": 46.0, "range": 210.0, "damage": 22.0, "rate": 1.0,  "kind": "aa",     "radius": 11.0, "evolves_to": -1, "segment": 1, "supply_cost": 8,  "color": Color(0.55, 0.55, 0.62)},
	{"id": 4, "name_key": "unit_4", "name": "Cleric",     "cost": 90,  "hp": 160.0, "speed": 62.0, "range": 155.0, "damage": 0.0,  "rate": 0.85, "kind": "healer", "radius": 11.0, "evolves_to": -1, "segment": 1, "supply_cost": 12, "color": Color(0.85, 0.85, 0.95), "mana_max": 100.0, "mana_cost": 20.0, "heal_amount": 52.0, "mana_regen": 7.0},
	{"id": 5, "name_key": "unit_5", "name": "Farmer",     "cost": 55,  "hp": 95.0,  "speed": 58.0, "range": 0.0,   "damage": 0.0,  "rate": 0.0,  "kind": "farmer", "radius": 12.0, "evolves_to": -1, "segment": 1, "supply_cost": 0,  "color": Color(0.55, 0.48, 0.22)},
	{"id": 6, "name_key": "unit_6", "name": "Supply Depot", "cost": 80, "hp": 220.0, "speed": 0.0, "range": 0.0, "damage": 0.0, "rate": 0.0, "kind": "depot", "radius": 18.0, "evolves_to": -1, "segment": 1, "supply_cost": 0, "stationary": true, "color": Color(0.40, 0.55, 0.28)},
]
# ????/???CO-004??aggro 300?leash 130????????
const MELEE_CHASE := 40.0
const MELEE_AGGRO_RANGE := 340.0
const MELEE_INTERCEPT_LEASH := 180.0
# ????????????????? + ?????CO-004 ? 80 ?? 15?
const RANGED_CHASE := 15.0
const RANGED_COMBAT_BONUS := 85.0   # 离走廊越远射程补偿；略提高便于早期接敌
const RANGED_AGGRO_EXTRA := 120.0   # 超出命中距离仍可锁定，便于转向/等待开火
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
	{"id": 0, "name_key": "enemy_0", "name": "Grunt",   "hp": 44.0,  "speed": 68.0,  "reward": 10, "attack": 10.0, "attack_interval": 1.0,  "color": Color(0.75, 0.20, 0.20)},
	{"id": 1, "name_key": "enemy_1", "name": "Runner",  "hp": 26.0,  "speed": 112.0, "reward": 14, "attack": 5.0,  "attack_interval": 0.7, "color": Color(0.20, 0.55, 0.85)},
	{"id": 2, "name_key": "enemy_2", "name": "Tank",    "hp": 230.0, "speed": 42.0,  "reward": 25, "attack": 38.0, "attack_interval": 0.8, "color": Color(0.45, 0.40, 0.50)},
	{"id": 3, "name_key": "enemy_3", "name": "Armored", "hp": 90.0,  "speed": 55.0,  "reward": 16, "attack": 14.0, "attack_interval": 1.0,  "armored": true, "armor_melee": 0.32, "armor_ranged": 1.0, "armor_splash": 1.2, "color": Color(0.62, 0.64, 0.70)},
]

# HP 随波线性成长
static func enemy_hp(id: int, wave: int) -> float:
	return float(ENEMIES[id]["hp"]) * (1.0 + float(wave - 1) * 0.12)

static func enemy_attack_mult(wave: int) -> float:
	return clampf(0.52 + float(wave - 1) * 0.035, 0.52, 0.85)

# CO-012：护甲怪按伤害类型承伤倍率
static func armor_damage_mult(e_def: Dictionary, dmg_kind: String) -> float:
	if not bool(e_def.get("armored", false)):
		return 1.0
	match dmg_kind:
		"melee":
			return float(e_def.get("armor_melee", 0.32))
		"splash":
			return float(e_def.get("armor_splash", 1.2))
		"single", "aa", "ranged":
			return float(e_def.get("armor_ranged", 1.0))
		_:
			return float(e_def.get("armor_generic", 1.0))

# 波次构成：坦克提前、小兵主力、跑者压轴、铁皮从波4起教学
# CO-008-B2：runner 斜率；CO-012：armored = clamp(wave-3, 0, 5)
static func wave_composition(wave: int) -> Array:
	var out: Array = []
	var tanks: int = int(float(wave - 1) / 4.0)
	var runners: int = int(max(0.0, float(wave - 5) * 1.0))
	var grunts: int = 2 + mini(wave, 8)
	var armored: int = mini(maxi(0, wave - 3), 5)
	for i in range(tanks):
		out.append(2)
	for i in range(grunts):
		out.append(0)
	for i in range(armored):
		out.append(3)
	for i in range(runners):
		out.append(1)
	return out

# ??????????????????
static func spawn_interval(wave: int) -> float:
	return max(0.5, 0.95 - float(wave) * 0.035)

# ????????? * 0.5 * ??????1->?2 ? 1??2->?3 ? 2?
static func evolve_cost(u_def: Dictionary, segment: int) -> int:
	# CO-007?0.8?0.5 ???????????? 80?50??? 1-4 ???????? Runner
	# ?CO-008-B1 ?? 0.35 ????S1Autoplay 48/48 ??? 0.5 ????????
	return int(ceil(float(u_def["cost"]) * 0.5 * float(segment)))

# 出售返还 60% 已投入金币
static func sell_value(invested: int) -> int:
	return int(round(float(invested) * SELL_REFUND_RATIO))

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
	{"id": 3, "name_key": "d_unit_3", "name": "Dragonkin", "cost": 85, "hp": 260.0, "speed": 52.0, "range": 55.0, "damage": 18.0, "rate": 1.15, "kind": "melee", "radius": 12.0, "evolves_to": 10, "segment": 1, "buyable": true, "color": Color(0.55, 0.20, 0.25), "can_fly": false},
	# —— 亚龙（仅进化） ——
	{"id": 4, "name_key": "d_unit_4", "name": "Flame Drake", "cost": 140, "hp": 200.0, "speed": 108.0, "range": 115.0, "damage": 20.0, "rate": 2.3, "kind": "fly", "radius": 15.0, "evolves_to": 7, "segment": 2, "buyable": false, "color": Color(0.95, 0.30, 0.12), "can_fly": true, "burn_dps": 18.0, "burn_tick_interval": 0.45, "burn_duration": 5.5},
	{"id": 5, "name_key": "d_unit_5", "name": "Ironscale Drake", "cost": 150, "hp": 300.0, "speed": 62.0, "range": 75.0, "damage": 26.0, "rate": 1.15, "kind": "burst", "radius": 15.0, "evolves_to": 8, "segment": 2, "buyable": false, "color": Color(0.85, 0.40, 0.12), "can_fly": false, "burn_dps": 16.0, "burn_tick_interval": 0.9, "burn_duration": 7.0, "shield_hp_ratio": 0.50, "shield_duration": 4.5},
	{"id": 6, "name_key": "d_unit_6", "name": "Blast Drake", "cost": 160, "hp": 240.0, "speed": 42.0, "range": 62.0, "damage": 22.0, "rate": 0.85, "kind": "explode", "radius": 18.0, "evolves_to": 9, "segment": 2, "buyable": false, "color": Color(0.65, 0.12, 0.06), "can_fly": false, "explode_damage": 100.0, "explode_radius": 70.0},
	# —— 成龙（仅进化） ——
	{"id": 7, "name_key": "d_unit_7", "name": "Flame Dragon", "cost": 200, "hp": 280.0, "speed": 115.0, "range": 130.0, "damage": 28.0, "rate": 2.4, "kind": "fly", "radius": 17.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(1.0, 0.35, 0.10), "can_fly": true, "burn_dps": 24.0, "burn_tick_interval": 0.4, "burn_duration": 6.5},
	{"id": 8, "name_key": "d_unit_8", "name": "Ironscale Dragon", "cost": 210, "hp": 420.0, "speed": 68.0, "range": 80.0, "damage": 34.0, "rate": 1.2, "kind": "burst", "radius": 17.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(0.90, 0.45, 0.10), "can_fly": false, "burn_dps": 22.0, "burn_tick_interval": 0.8, "burn_duration": 8.0, "shield_hp_ratio": 0.55, "shield_duration": 5.0},
	{"id": 9, "name_key": "d_unit_9", "name": "Blast Dragon", "cost": 220, "hp": 360.0, "speed": 40.0, "range": 68.0, "damage": 28.0, "rate": 0.9, "kind": "explode", "radius": 22.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(0.55, 0.08, 0.05), "can_fly": false, "explode_damage": 140.0, "explode_radius": 85.0},
	# —— 龙人进化 ——
	{"id": 10, "name_key": "d_unit_10", "name": "Dragonkin Guard", "cost": 130, "hp": 380.0, "speed": 54.0, "range": 58.0, "damage": 26.0, "rate": 1.2, "kind": "melee", "radius": 13.0, "evolves_to": 11, "segment": 2, "buyable": false, "color": Color(0.60, 0.22, 0.28), "can_fly": false},
	{"id": 11, "name_key": "d_unit_11", "name": "Dragonkin Lord", "cost": 180, "hp": 520.0, "speed": 56.0, "range": 62.0, "damage": 34.0, "rate": 1.25, "kind": "melee", "radius": 14.0, "evolves_to": -1, "segment": 3, "buyable": false, "color": Color(0.70, 0.25, 0.30), "can_fly": false},
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
		"core_decision": "hatch_timing_vs_hunt_route"
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

static func race_units(race_name: String) -> Array:
	if RACES.has(race_name):
		return RACES[race_name]["units"]
	return HUMAN_UNITS

static func shop_units(race_name: String) -> Array:
	var out: Array = []
	for u in race_units(race_name):
		if bool(u.get("buyable", true)):
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
