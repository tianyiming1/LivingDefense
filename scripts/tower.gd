# 防御塔：自动索敌（优先打走得最远的敌人）、发射子弹、支持升级/出售
extends Node2D

var def: Dictionary = {}
var level := 1
var invested := 0
var cooldown := 0.0
var selected := false
var damage_val := 0.0
var range_val := 150.0
var rate_val := 1.0
var _enemies: Node2D = null
var _projectiles: Node2D = null

func setup(t_def: Dictionary, enemies: Node2D, projectiles: Node2D) -> void:
	def = t_def
	_enemies = enemies
	_projectiles = projectiles
	invested = int(def["cost"])
	_recalc()

# 升级成长：伤害 x1.5/级，射程 +15%/级
func _recalc() -> void:
	var l := float(level)
	range_val = float(def["range"]) * (1.0 + 0.15 * (l - 1.0))
	damage_val = float(def["damage"]) * pow(1.5, l - 1.0)
	rate_val = float(def["rate"])

func upgrade() -> bool:
	if level >= Config.MAX_TOWER_LEVEL:
		return false
	level += 1
	_recalc()
	queue_redraw()
	return true

func upgrade_cost() -> int:
	return Config.upgrade_cost(int(def["cost"]), level)

func sell_value() -> int:
	return int(round(float(invested) * Config.SELL_REFUND_RATIO))

func _physics_process(delta: float) -> void:
	cooldown -= delta
	var target := _acquire_target()
	if target != null:
		rotation = lerp_angle(rotation, position.angle_to_point(target.position), minf(1.0, 14.0 * delta))
		if cooldown <= 0.0:
			_fire(target)
			cooldown = 1.0 / rate_val
	queue_redraw()

# 目标优先级：走得越远（越接近终点）的敌人越危险，优先打
func _acquire_target() -> Node:
	var best: Node = null
	var best_prog := -INF
	var pts: Array[Vector2] = Config.PATH_POINTS
	for e in _enemies.get_children():
		if e.position.distance_to(position) > range_val + 10.0:
			continue
		var prog: float = float(e.waypoint_index) * 10000.0 - float(e.position.distance_to(pts[min(e.waypoint_index, pts.size() - 1)]))
		if prog > best_prog:
			best_prog = prog
			best = e
	return best

func _fire(target: Node) -> void:
	if _projectiles == null:
		return
	var p: Node = load("res://scripts/projectile.gd").new()
	_projectiles.add_child(p)
	p.setup(self, _enemies, target, damage_val, 430.0,
		float(def.get("splash_radius", 0.0)),
		float(def.get("slow_factor", 1.0)),
		float(def.get("slow_time", 0.0)))
	p.modulate = Color(def["color"])

func _draw() -> void:
	if def.is_empty():
		return
	# 底座
	draw_circle(Vector2.ZERO, Config.TOWER_RADIUS, Color(def["color"]))
	draw_circle(Vector2.ZERO, Config.TOWER_RADIUS, Color(0, 0, 0, 0.35), false, 2.0, true)
	# 炮管（朝 +X，转向由 rotation 控制）
	draw_line(Vector2.ZERO, Vector2(22.0, 0.0), Color(0.12, 0.12, 0.14), 6.0)
	if level > 1:
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 0.8))
	# 选中时显示射程圈
	if selected:
		draw_arc(Vector2.ZERO, range_val, 0.0, TAU, 96, Color(1, 1, 1, 0.85), 1.5, true)
