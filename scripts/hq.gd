# CO-032：大本营（路径终点）——承伤漏怪 + 人族科研交互点
extends Node2D

signal clicked
signal destroyed

var max_hp := 100.0
var hp := 100.0
var selected := false
var _hit_flash := 0.0
var _main: Node = null

func setup(main: Node, max_hit: float) -> void:
	_main = main
	max_hp = max_hit
	hp = max_hit
	_place_at_goal()
	queue_redraw()

func _place_at_goal() -> void:
	var pts: Array = Config.PATH_POINTS
	if pts.size() < 2:
		position = Vector2(Config.MAP_SIZE.x - 64.0, Config.MAP_SIZE.y * 0.5)
		return
	var end: Vector2 = pts[pts.size() - 1]
	var prev: Vector2 = pts[pts.size() - 2]
	var dir: Vector2 = (end - prev).normalized()
	# W3：大地图 + 镜头——HQ 贴路径终点，只钳在地图内（不再按视口右缘）
	var cand: Vector2 = end + dir * 36.0
	cand.x = clampf(cand.x, 64.0, Config.MAP_SIZE.x - 48.0)
	cand.y = clampf(cand.y, 64.0, Config.MAP_SIZE.y - 64.0)
	position = cand

func apply_leak_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.35
	queue_redraw()
	if hp <= 0.0:
		destroyed.emit()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		queue_redraw()

func _draw() -> void:
	# 堡垒剪影
	var col := Color(0.55, 0.48, 0.38)
	if selected:
		col = Color(0.75, 0.68, 0.45)
	if _hit_flash > 0.0:
		col = col.lerp(Color(1.0, 0.25, 0.2), _hit_flash / 0.35)
	draw_rect(Rect2(-22, -18, 44, 36), col)
	draw_rect(Rect2(-22, -18, 44, 36), Color(0.15, 0.12, 0.1), false, 2.0)
	# 塔楼
	draw_rect(Rect2(-26, -28, 14, 16), col.darkened(0.1))
	draw_rect(Rect2(12, -28, 14, 16), col.darkened(0.1))
	draw_rect(Rect2(-8, -34, 16, 20), col.lightened(0.05))
	# 门
	draw_rect(Rect2(-8, 2, 16, 16), Color(0.25, 0.18, 0.12))
	# 血条
	var bar_w := 48.0
	var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5, -44, bar_w, 5), Color(0.1, 0.1, 0.1, 0.85))
	var hc := Color(0.25, 0.85, 0.35) if ratio > 0.45 else (Color(0.95, 0.75, 0.2) if ratio > 0.2 else Color(0.95, 0.25, 0.2))
	draw_rect(Rect2(-bar_w * 0.5, -44, bar_w * ratio, 5), hc)
	if selected:
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.4, 0.85), 2.0, true)

func contains_point(world: Vector2) -> bool:
	return Rect2(position - Vector2(28, 36), Vector2(56, 64)).has_point(world)
