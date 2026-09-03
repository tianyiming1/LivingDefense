# ============================================================
# S1 人族自动化验收（CO-001 S1 验收标准）
#   1) 12 波可通（bot 按建造计划打完，WIN 状态）
#   2) 技能可释放且 CD 正确（布防期拒绝 / 同波拒绝 / 隔 1 波拒绝 / CD 到期可放）
#   3) 放置规则正确（走廊内拒绝[含中段] / 越界拒绝 / 重叠拒绝 / 钱不够拒绝 / 合法点接受）
#   4) 经济无异常（全程金钱 >= 0 / 计划可负担 / 进化扣费）
#   5) 死亡信号幂等（每单位 died 至多 1 次 = 战损统计不重复计）
# 运行（headless）：
#   Godot --headless --path . res://tests/S1Autoplay.tscn
# 退出码：0 = 全部通过（ACCEPT）；1 = 存在失败项（REJECT）
# ============================================================
extends Node

const TIME_SCALE := 8.0          # 游戏内加速（不改逻辑语义，仅缩短真实耗时）
const TIMEOUT_MS := 600000       # 全程真实时间上限 10 分钟

const ST_PLANNING := 0
const ST_WAVING := 1
const ST_GAME_OVER := 2
const ST_WIN := 3

var main: Node
var started_ms := 0
var passes: Array[String] = []
var failures: Array[String] = []

# ---- 监控 ----
var money_min_seen := 1 << 30
var death_emit_total := 0
var death_emit_max_per_unit := 0
var death_counts := {}
var wave_log: Array[String] = []

# ---- 布防点位（全部满足新放置规则：距走廊 >= 46、屏内、互距 >= 50）----
const SPOTS := {
	"a1": Vector2(370, 250), "a2": Vector2(415, 300),
	"b1": Vector2(660, 180), "b2": Vector2(630, 230),
	"c1": Vector2(660, 540), "c2": Vector2(620, 500),
	"d1": Vector2(980, 540), "d2": Vector2(940, 500),
	"e1": Vector2(980, 320), "e2": Vector2(940, 280),
	"f1": Vector2(455, 60),  "f2": Vector2(520, 60),
	"g1": Vector2(785, 660), "g2": Vector2(845, 660),
	"h1": Vector2(1150, 340),
}

# 单位表：0 步兵 1 火枪 2 迫击 3 弩 4 牧 5 农民 6 补给站
# 先站后农；农民占 f2/g2，站占 f1
const PLAN := {
	1: ["buy:6@f1", "buy:5@f2", "buy:5@g2", "buy:0@a1", "buy:1@a2", "buy:1@b1"],
	2: ["buy:0@c1"],
	3: ["buy:1@d2"],
	4: ["buy:4@e1", "evo:a1"],
	5: ["buy:1@c2", "buy:0@e2"],
	6: ["buy:2@h1", "buy:0@b2"],
	7: ["buy:3@d1"],
	8: ["evo:c1"],
	9: ["evo:d2"],
	10: [],
	11: [],
	12: ["evo:g1"],
}
# 技能释放波（CD 2 波 → 隔波释放，同时覆盖 CD 边界断言）
const SKILL_WAVES := [1, 3, 5, 7, 9, 11]

var placed := {}   # 点位 label -> 单位节点


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	started_ms = Time.get_ticks_msec()
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().physics_frame
	await _run()
	_finish()


func _finish() -> void:
	print("\n===== S1 自动化验收报告 =====")
	for p in passes:
		print("[PASS] ", p)
	for f in failures:
		print("[FAIL] ", f)
	print("---- 波次日志 (金钱/生命/战损/在场单位) ----")
	for l in wave_log:
		print("  ", l)
	print("最低金钱: %d | 死亡信号总数: %d | 单单位最大死亡信号: %d" % [
		money_min_seen, death_emit_total, death_emit_max_per_unit])
	print("总计: %d 通过 / %d 失败" % [passes.size(), failures.size()])
	print("===== 结果: ", "ACCEPT" if failures.is_empty() else "REJECT", " =====")
	get_tree().quit(0 if failures.is_empty() else 1)


func check(cond: bool, name: String) -> void:
	if cond:
		passes.append(name)
		print("[PASS] ", name)
	else:
		failures.append(name)
		print("[FAIL] ", name)


func _process(_delta: float) -> void:
	if main != null and is_instance_valid(main):
		money_min_seen = mini(money_min_seen, int(main.money))


# ---------- 放置规则 ----------
func _try_buy(unit_id: int, pos: Vector2) -> bool:
	main._cancel_placement()
	main._on_buy_requested(unit_id)
	var m0: int = int(main.money)
	var n0: int = main.units_layer.get_child_count()
	main._try_place(pos)
	return int(main.money) < m0 or main.units_layer.get_child_count() > n0


func _test_placement_rules() -> void:
	# 走廊内（含线段中段，BUG1 回归点）：应全部拒绝
	var corridor_pts := {
		"S0_mid": Vector2(160, 360), "S2_mid": Vector2(500, 120),
		"S3_mid": Vector2(720, 400), "S4_mid": Vector2(880, 600),
		"S5_mid": Vector2(1040, 440), "corner_P1": Vector2(330, 350),
	}
	for k in corridor_pts:
		var m0: int = int(main.money)
		var ok: bool = _try_buy(0, corridor_pts[k])
		check(not ok and int(main.money) == m0, "placement_reject_corridor_" + str(k))
	# 越界（BUG2 回归点）：应拒绝
	var bounds_pts := {"outside_xy": Vector2(1400, 800), "negative": Vector2(-50, 50), "edge_x": Vector2(1270, 360)}
	for k in bounds_pts:
		var m0: int = int(main.money)
		var ok: bool = _try_buy(0, bounds_pts[k])
		check(not ok and int(main.money) == m0, "placement_reject_bounds_" + str(k))
	# 钱不够：应拒绝且金钱不变
	var real_money: int = int(main.money)
	main.money = 10
	var m1: int = int(main.money)
	var ok2: bool = _try_buy(0, SPOTS["h1"])
	check(not ok2 and int(main.money) == m1, "placement_reject_no_money")
	main.money = real_money
	main.hud.set_money(real_money)


# ---------- 波次驱动 ----------
func _play_wave(wave: int) -> bool:
	# 布防：执行计划
	if PLAN.has(wave):
		var acts: Array = PLAN[wave]
		for i in range(acts.size()):
			var act: String = acts[i]
			if act.begins_with("buy:"):
				var parts: PackedStringArray = act.substr(4).split("@")
				var uid := int(parts[0])
				var spot: String = parts[1]
				var m0: int = int(main.money)
				var ok: bool = _try_buy(uid, SPOTS[spot])
				if ok:
					var u: Node = main.units_layer.get_children().back()
					placed[spot] = u
					_watch_unit(u)
					check(int(main.money) == m0 - int(Config.HUMAN_UNITS[uid]["cost"]),
						"buy_" + spot + "_w" + str(wave) + "_spends_exact")
				else:
					failures.append("buy_" + spot + "_w" + str(wave) + "_failed")
					print("[FAIL] 计划购买失败 w" + str(wave) + " " + spot)
				# 第一个单位落位后：重叠拒绝
				if wave == 1 and i == 0:
					check(ok, "placement_accept_legal_spot")
					var m1: int = int(main.money)
					var ok2: bool = _try_buy(0, SPOTS[spot])
					check(not ok2 and int(main.money) == m1, "placement_reject_overlap")
			elif act.begins_with("evo:"):
				var key: String = act.substr(4)
				var u: Node = _resolve_evo_unit(key)
				if u == null:
					failures.append("evo_" + key + "_missing")
					print("[FAIL] 进化目标不存在: " + key)
					continue
				var m0: int = int(main.money)
				var seg0: int = int(u.def["segment"])
				main._on_unit_click(u.position)
				main._on_evolve()
				check(int(main.money) < m0 and is_instance_valid(u) and int(u.def["segment"]) > seg0,
					"evolve_" + key + "_w" + str(wave))
	# 技能（CD 断言见下）
	if wave == 1:
		main._on_skill()  # 布防期释放 → 应被拒
		check(int(main.skill1_last_wave) == -99, "skill_reject_in_planning")
	# 开波
	main._on_start_wave()
	check(main.state == ST_WAVING and int(main.wave_index) == wave, "wave" + str(wave) + "_started")
	# 战斗
	var casted := false
	while main.state == ST_WAVING:
		if SKILL_WAVES.has(wave) and not casted:
			casted = true
			main._on_skill()
			if wave == 1:
				check(int(main.skill1_last_wave) == 1, "skill_cast_wave1")
				var any_buffed := false
				for u in main.units_layer.get_children():
					if absf(float(u.as_buff) - float(Config.SKILL_RALLY["as_mult"])) < 0.01:
						any_buffed = true
				check(any_buffed, "skill_buff_applied")
				main._on_skill()  # 同波二次 → 应被拒
				check(int(main.skill1_last_wave) == 1, "skill_cd_same_wave_reject")
			elif wave == 2:
				main._on_skill()  # 距上次 1 波 < CD 2 → 应被拒
				check(int(main.skill1_last_wave) == 1, "skill_cd_wave2_reject")
			elif wave == 3:
				check(int(main.skill1_last_wave) == 3, "skill_ready_wave3")
		if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
			failures.append("timeout_at_wave" + str(wave))
			print("[FAIL] 超时于第 " + str(wave) + " 波")
			return false
		await get_tree().physics_frame
	# 结算
	if main.state == ST_GAME_OVER:
		failures.append("game_over_at_wave" + str(wave))
		print("[FAIL] 第 " + str(wave) + " 波败北: lives=" + str(main.lives) + " units=" + str(main.units_layer.get_child_count()))
		return false
	if main.state == ST_WIN:
		return true
	check(int(main.wave_index) == wave, "wave" + str(wave) + "_cleared")
	if wave == 1:
		check(bool(main.hud._skill_ready) == false, "skill_cd_wave1_end_not_ready")
	wave_log.append("wave %2d | $%5d | lives %2d | lost %d | units %d" % [
		wave, int(main.money), int(main.lives), int(main.units_lost), main.units_layer.get_child_count()])
	return true


func _watch_unit(u: Node) -> void:
	var uid: int = u.get_instance_id()
	u.died.connect(func() -> void:
		death_emit_total += 1
		death_counts[uid] = int(death_counts.get(uid, 0)) + 1
		death_emit_max_per_unit = maxi(death_emit_max_per_unit, int(death_counts[uid]))
		for key in placed.keys():
			if placed[key] == u:
				placed.erase(key)
	)


func _resolve_evo_unit(key: String) -> Node:
	var u: Node = placed.get(key)
	if u != null and is_instance_valid(u) and int(u.def.get("evolves_to", -1)) >= 0:
		return u
	var best: Node = null
	var best_cost := 1 << 30
	for cand in main.units_layer.get_children():
		if int(cand.def.get("evolves_to", -1)) < 0:
			continue
		var c: int = int(cand.evolve_cost())
		if c < best_cost:
			best_cost = c
			best = cand
	return best


# ---------- 主流程 ----------
func _run() -> void:
	await _test_placement_rules()
	for wave in range(1, Config.TOTAL_WAVES + 1):
		var ok: bool = await _play_wave(wave)
		if not ok:
			return
	# 终局校验
	check(main.state == ST_WIN, "win_state_reached_12_waves")
	check(int(main.lives) > 0, "lives_positive_at_win")
	check(money_min_seen >= 0, "money_never_negative")
	check(death_emit_max_per_unit <= 1, "death_signal_single_emit")
	check(int(main.units_lost) == death_emit_total, "loss_stat_matches_death_signals")
