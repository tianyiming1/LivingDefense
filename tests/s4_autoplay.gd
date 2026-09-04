# S4 硅族 12 波自动化验收
extends Node

const TIME_SCALE := 8.0
const TIMEOUT_MS := 600000
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
	"a1": Vector2(370, 250), "a2": Vector2(415, 300),
	"b1": Vector2(660, 180), "b2": Vector2(630, 230),
	"c1": Vector2(660, 540), "c2": Vector2(620, 500),
	"d1": Vector2(980, 540), "d2": Vector2(940, 500),
	"e1": Vector2(980, 320), "e2": Vector2(940, 280),
	"f1": Vector2(455, 60),  "f2": Vector2(520, 60),
	"g1": Vector2(785, 660), "g2": Vector2(845, 660),
	"h1": Vector2(1150, 340),
}

const PLAN := {
	1: ["buy:2@a1", "buy:0@a2"],
	2: ["buy:1@b1"],
	3: ["buy:0@c1"],
	4: ["buy:2@d2"],
	5: ["buy:1@e1"],
	6: ["buy:0@f1"],
	7: ["buy:2@g1"],
	8: ["buy:1@e2"],
	9: ["buy:0@h1"],
	10: ["buy:2@f2"],
	11: ["buy:1@g2"],
	12: ["buy:0@c2"],
}
const SKILL_WAVES := [3, 6, 9, 12]

var placed := {}

func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	started_ms = Time.get_ticks_msec()
	get_tree().set_meta("selected_race", "silicon")
	main = load("res://main.tscn").instantiate()
	add_child(main)
	main.current_race = "silicon"
	main.hud.set_race("silicon")
	await get_tree().physics_frame
	await _run()
	_finish()

func _finish() -> void:
	print("\n===== S4 硅族自动化验收报告 =====")
	for p in passes:
		print("[PASS] ", p)
	for f in failures:
		print("[FAIL] ", f)
	for l in wave_log:
		print("  ", l)
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
	main.current_race = "silicon"
	main._on_buy_requested(unit_id)
	var m0: int = int(main.money)
	var n0: int = main.units_layer.get_child_count()
	main._try_place(pos)
	return int(main.money) < m0 or main.units_layer.get_child_count() > n0

func _play_wave(wave: int) -> bool:
	if PLAN.has(wave):
		for act in PLAN[wave]:
			if act.begins_with("buy:"):
				var parts: PackedStringArray = act.substr(4).split("@")
				var uid := int(parts[0])
				var spot: String = parts[1]
				var ok: bool = _try_buy(uid, SPOTS[spot])
				if ok:
					placed[spot] = main.units_layer.get_children().back()
					_watch_unit(placed[spot])
				else:
					failures.append("buy_" + spot + "_w" + str(wave) + "_failed")
					return false
	main._on_start_wave()
	check(main.state == ST_WAVING and int(main.wave_index) == wave, "wave" + str(wave) + "_started")
	var casted := false
	while main.state == ST_WAVING:
		if SKILL_WAVES.has(wave) and not casted and int(main.crystal_energy) >= 2:
			casted = true
			main._on_skill()
		if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
			failures.append("timeout_w" + str(wave))
			return false
		await get_tree().physics_frame
	if main.state == ST_GAME_OVER:
		failures.append("game_over_at_wave" + str(wave))
		return false
	if main.state == ST_WIN:
		return true
	check(int(main.wave_index) == wave, "wave" + str(wave) + "_cleared")
	wave_log.append("wave %2d | $%5d | crystal %d | lives %2d | units %d" % [
		wave, int(main.money), int(main.crystal_energy), int(main.lives), main.units_layer.get_child_count()])
	return true

func _watch_unit(u: Node) -> void:
	var uid: int = u.get_instance_id()
	u.died.connect(func() -> void:
		death_emit_total += 1
		death_counts[uid] = int(death_counts.get(uid, 0)) + 1
		death_emit_max_per_unit = maxi(death_emit_max_per_unit, int(death_counts[uid]))
	)

func _run() -> void:
	for wave in range(1, Config.TOTAL_WAVES + 1):
		if not await _play_wave(wave):
			return
	check(main.state == ST_WIN, "win_state_reached_total_waves")
	check(int(main.lives) > 0, "lives_positive_at_win")
