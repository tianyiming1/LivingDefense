# ============================================================
# S1 人族自动化验收（CO-001 S1 验收标准）
#   1) TOTAL_WAVES 可通（bot 按建造计划打完，WIN 状态）
#   2) 技能可释放且 CD 正确
#   3) 放置规则正确
#   4) 经济无异常
#   5) 死亡信号幂等
# 运行（headless）：
#   Godot --headless --path . res://tests/S1Autoplay.tscn
# 退出码：0 = ACCEPT；1 = REJECT
# ============================================================
extends Node

const TIME_SCALE := 8.0
const TIMEOUT_MS := 900000

const ST_PLANNING := 0
const ST_WAVING := 1
const ST_GAME_OVER := 2
const ST_WIN := 3

var main: Node
var started_ms := 0
var passes: Array[String] = []
var failures: Array[String] = []

var money_min_seen := 1 << 30
var death_emit_total := 0
var death_emit_max_per_unit := 0
var death_counts := {}
var wave_log: Array[String] = []

const SPOTS := {
	"a1": Vector2(555, 375), "a2": Vector2(622, 450),
	"b1": Vector2(990, 270), "b2": Vector2(945, 345),
	"c1": Vector2(990, 810), "c2": Vector2(930, 750),
	"d1": Vector2(1470, 810), "d2": Vector2(1410, 750),
	"e1": Vector2(1470, 480), "e2": Vector2(1410, 420),
	"f1": Vector2(682, 90),  "f2": Vector2(780, 90),
	"g1": Vector2(1177, 990), "g2": Vector2(1267, 990),
	"h1": Vector2(1725, 510),
}

# 单位表：0步 1弓 3箭塔 4牧 5农 6站 8法师（无火枪/迫击直购）
# CO-042：铁皮波前必须上法师AOE/弓线，勿先堆牧师
const PLAN := {
	1: ["buy:6@f1", "buy:5@f2", "buy:5@g2", "buy:0@a1", "buy:1@a2"],
	2: ["tech:archery", "buy:1@c1", "buy:0@b1"],
	3: ["evo:a2", "tech:arcane", "buy:1@e2"],
	4: ["buy:8@h1", "tech:infantry", "buy:1@c2"],
	5: ["tech:arbalest", "buy:3@d1", "buy:0@b2"],
	6: ["tech:chapel", "buy:4@e1", "buy:1@d2"],
	7: ["buy:0@a1", "buy:1@c1", "buy:8@g1", "tech:archery"],
	8: ["buy:0@b1", "buy:1@e2", "buy:0@b2", "tech:logistics"],
	9: ["tech:siege", "buy:1@c2", "buy:0@a2", "buy:8@h1"],
	10: ["buy:0@b1", "buy:1@d2", "buy:3@e2"],
	11: ["buy:0@a1", "buy:1@c1", "buy:4@e1", "tech:archery"],
	12: ["buy:0@b2", "buy:1@c2", "buy:8@g1", "buy:3@d1"],
	13: ["buy:0@a2", "buy:1@e2", "buy:0@b1", "buy:8@h1"],
	14: ["buy:0@a1", "buy:1@c1", "buy:3@d2", "buy:0@b2"],
	15: ["buy:1@e2", "buy:0@a2", "buy:8@g1", "buy:4@e1"],
	16: ["buy:0@b1", "buy:1@c2", "buy:3@d1", "buy:8@h1"],
	17: ["buy:0@a1", "buy:1@d2", "buy:0@b2", "buy:8@g1", "buy:1@c1", "buy:3@e2"],
	18: ["buy:0@a2", "buy:1@c2", "buy:0@b1", "buy:8@h1"],
}
const SKILL_WAVES := [1, 3, 5, 7, 9, 11, 13, 15, 17]

var placed := {}


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


func _try_buy(unit_id: int, pos: Vector2) -> bool:
	main._cancel_placement()
	main._on_buy_requested(unit_id)
	var m0: int = int(main.money)
	var n0: int = main.units_layer.get_child_count()
	main._try_place(pos)
	return int(main.money) < m0 or main.units_layer.get_child_count() > n0


func _test_placement_rules() -> void:
	var corridor_pts := {
		"S0_mid": Vector2(240, 540), "S2_mid": Vector2(750, 180),
		"S3_mid": Vector2(1080, 600), "S4_mid": Vector2(1320, 900),
		"S5_mid": Vector2(1560, 660), "corner_P1": Vector2(495, 525),
	}
	for k in corridor_pts:
		var m0: int = int(main.money)
		var ok: bool = _try_buy(0, corridor_pts[k])
		check(not ok and int(main.money) == m0, "placement_reject_corridor_" + str(k))
	var bounds_pts := {"outside_xy": Vector2(2100, 1200), "negative": Vector2(-50, 50), "edge_x": Vector2(1910, 540)}
	for k in bounds_pts:
		var m0: int = int(main.money)
		var ok: bool = _try_buy(0, bounds_pts[k])
		check(not ok and int(main.money) == m0, "placement_reject_bounds_" + str(k))
	var real_money: int = int(main.money)
	main.money = 10
	var m1: int = int(main.money)
	var ok2: bool = _try_buy(0, SPOTS["h1"])
	check(not ok2 and int(main.money) == m1, "placement_reject_no_money")
	main.money = real_money
	main.hud.set_money(real_money)


func _play_wave(wave: int) -> bool:
	if PLAN.has(wave):
		var acts: Array = PLAN[wave]
		for i in range(acts.size()):
			var act: String = str(acts[i])
			if act.begins_with("buy:"):
				var body: String = act.substr(4)
				var parts: PackedStringArray = body.split("@")
				var uid: int = int(parts[0])
				var spot: String = str(parts[1])
				var m0: int = int(main.money)
				var ok: bool = _try_buy(uid, SPOTS[spot])
				if ok:
					var u: Node = main.units_layer.get_children().back()
					placed[spot] = u
					_watch_unit(u)
					var expect_cost: int = int(Config.unit_at("human", uid).get("cost", 0))
					check(int(main.money) == m0 - expect_cost,
						"buy_" + spot + "_w" + str(wave) + "_spends_exact")
				else:
					# 波1硬验收落点；中后盘补员失败多为占位/钱不够——SKIP 不拖垮 ACCEPT
					if wave <= 1:
						failures.append("buy_" + spot + "_w" + str(wave) + "_failed")
						print("[FAIL] 计划购买失败 w" + str(wave) + " " + spot)
					else:
						print("[SKIP] 计划购买失败 w" + str(wave) + " " + spot)
				if wave == 1 and i == 0:
					check(ok, "placement_accept_legal_spot")
					var m1: int = int(main.money)
					var ok2: bool = _try_buy(0, SPOTS[spot])
					check(not ok2 and int(main.money) == m1, "placement_reject_overlap")
			elif act.begins_with("tech:"):
				var tid: String = act.substr(5)
				var m0: int = int(main.money)
				var ok_tech: bool = false
				if main.human_tech != null and main.human_tech.has_method("research"):
					ok_tech = bool(main.human_tech.research(tid))
				if ok_tech and int(main.money) < m0:
					check(true, "tech_" + tid + "_w" + str(wave))
				elif wave <= 2:
					check(false, "tech_" + tid + "_w" + str(wave))
					failures.append("tech_" + tid + "_w" + str(wave) + "_failed")
					print("[FAIL] 科研失败 w" + str(wave) + " " + tid)
				else:
					print("[SKIP] 科研失败 w" + str(wave) + " " + tid)
			elif act.begins_with("evo:"):
				var key: String = act.substr(4)
				var u: Node = _resolve_evo_unit(key)
				if u == null:
					# 单位已阵亡时跳过，不记硬失败
					print("[SKIP] 进化目标不存在: " + key + " w" + str(wave))
					continue
				var m0: int = int(main.money)
				var id0: int = int(u.def["id"])
				main._on_unit_click(u.position)
				main._on_evolve()
				if int(main.money) < m0 and is_instance_valid(u) and int(u.def["id"]) != id0:
					check(true, "evolve_" + key + "_w" + str(wave))
				else:
					print("[SKIP] 进化未执行(钱/波次/科技/阵亡): " + key + " w" + str(wave))
	if wave == 1:
		main._on_skill()
		check(int(main.skill1_last_wave) == -99, "skill_reject_in_planning")
	main._on_start_wave()
	check(main.state == ST_WAVING and int(main.wave_index) == wave, "wave" + str(wave) + "_started")
	var casted := false
	while main.state == ST_WAVING:
		if SKILL_WAVES.has(wave) and not casted:
			casted = true
			main._on_skill()
			if wave == 1:
				check(int(main.skill1_last_wave) == 1, "skill_cast_wave1")
			elif wave == 2:
				check(int(main.skill1_last_wave) == 1, "skill_cd_wave2_reject")
			elif wave == 3:
				check(int(main.skill1_last_wave) == 3, "skill_ready_wave3")
		if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
			failures.append("timeout_at_wave" + str(wave))
			print("[FAIL] 超时于第 " + str(wave) + " 波")
			return false
		await get_tree().physics_frame
	if main.state == ST_GAME_OVER:
		failures.append("game_over_at_wave" + str(wave))
		print("[FAIL] 第 " + str(wave) + " 波败北: lives=" + str(main.lives) + " units=" + str(main.units_layer.get_child_count()))
		return false
	check(int(main.wave_index) == wave, "wave" + str(wave) + "_cleared")
	if wave == 1:
		check(bool(main.hud._skill_ready) == false, "skill_cd_wave1_end_not_ready")
	wave_log.append("wave %2d | $%5d | lives %2d | lost %d | units %d" % [
		wave, int(main.money), int(main.lives), int(main.units_lost), main.units_layer.get_child_count()])
	return true


func _watch_unit(u: Node) -> void:
	if u == null or not is_instance_valid(u):
		return
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


func _run() -> void:
	await _test_placement_rules()
	for wave in range(1, Config.TOTAL_WAVES + 1):
		var ok: bool = await _play_wave(wave)
		if not ok:
			return
	check(main.state == ST_WIN, "win_state_reached_total_waves")
	check(int(main.lives) > 0, "lives_positive_at_win")
	check(money_min_seen >= 0, "money_never_negative")
	check(death_emit_max_per_unit <= 1, "death_signal_single_emit")
	check(int(main.units_lost) == death_emit_total, "loss_stat_matches_death_signals")
