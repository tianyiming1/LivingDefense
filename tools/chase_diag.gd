extends SceneTree

func _init() -> void:
	print("U0 def = ", Config.HUMAN_UNITS[0])
	var enemies := Node2D.new()
	var projectiles := Node2D.new()
	var units := Node2D.new()
	root.add_child(enemies)
	root.add_child(projectiles)
	root.add_child(units)
	var u: Node = load("res://scripts/unit.gd").new()
	units.add_child(u)
	u.setup(Config.HUMAN_UNITS[0], enemies, projectiles, units)
	u.position = Vector2(400, 200)
	print("home = ", u.home, "  range = ", u.def["range"], " kind = ", u.def["kind"])
	u.set_combat(true)
	var e: Node = load("res://scripts/enemy.gd").new()
	enemies.add_child(e)
	e.setup(Config.ENEMIES[0], 1, units)
	e.position = Vector2(470, 200)
	print("enemy pos init = ", e.position, "  enemy def range/speed = ", Config.ENEMIES[0].get("range"), " / ", Config.ENEMIES[0].get("speed"))
	for i in range(90):
		u._process(0.016)
		e.position += Vector2(0, 75) * 0.016
		if i % 15 == 0:
			print("t", i, " u=", snappedf(u.position.x, 0.1), ",", snappedf(u.position.y, 0.1), " e=", snappedf(e.position.x, 0.1), ",", snappedf(e.position.y, 0.1), " dist=", snappedf(u.position.distance_to(e.position), 0.1), " locked=", (u._locked != null))
	quit(0)