extends SceneTree

func _run(unit_def: Dictionary, home: Vector2, enemy_vel: Vector2) -> Dictionary:
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var units := Node2D.new()
	root.add_child(enemies)
	root.add_child(projectiles)
	root.add_child(units)
	var u: Node = load("res://scripts/unit.gd").new()
	units.add_child(u)
	u.position = home            # 必须先定位，setup 快照 home
	u.setup(unit_def, enemies, projectiles, units)
	u.set_combat(true)
	var e: Node = load("res://scripts/enemy.gd").new()
	enemies.add_child(e)
	e.setup(Config.ENEMIES[0], 1, units)
	e.position = home + Vector2(70, 0)
	var samples: Array = []
	for i in range(240):
		u._physics_process(0.016)
		e.position += enemy_vel * 0.016
		if i % 15 == 0:
			samples.append(u.position)
	var max_d: float = 0.0
	for s in samples:
		max_d = maxf(max_d, s.distance_to(home))
	var reversals := 0
	for i in range(1, samples.size() - 1):
		var a: Vector2 = samples[i] - samples[i - 1]
		var b: Vector2 = samples[i + 1] - samples[i]
		if a.length() > 8.0 and b.length() > 8.0 and a.dot(b) < 0.0:
			reversals += 1
	return {"max_d": max_d, "rev": reversals}

func _init() -> void:
	# A：怪从 70px 外向下横穿（从不贴脸）→ 单位必须守住部署点
	var a: Dictionary = _run(Config.HUMAN_UNITS[0], Vector2(400, 200), Vector2(0, 75))
	print("A_side_pass  max_d = ", snappedf(a.max_d, 0.1), "  reversals = ", a.rev)
	# B：怪直冲单位并穿过 → 有界贴战跟随，无横跳
	var b: Dictionary = _run(Config.HUMAN_UNITS[0], Vector2(400, 200), Vector2(-75, 0))
	print("B_head_on    max_d = ", snappedf(b.max_d, 0.1), "  reversals = ", b.rev)
	var pass_a: bool = a.max_d < 25.0 and a.rev < 3
	var pass_b: bool = b.max_d < 90.0 and b.rev < 3
	if pass_a and pass_b:
		print("CHASE_TEST_PASS")
		quit(0)
	else:
		print("CHASE_TEST_FAIL  A=", pass_a, " B=", pass_b)
		quit(1)