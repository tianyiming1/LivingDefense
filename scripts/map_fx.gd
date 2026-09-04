# CO-037 / W3：地图氛围层——路径暖边 + 出生/终点高对比；暗角跟地图尺寸
extends Node2D

var _pixel := false

func setup(use_pixels: bool) -> void:
	_pixel = use_pixels
	queue_redraw()

func _draw() -> void:
	var ms: Vector2 = Config.MAP_SIZE
	var pts: Array = Config.PATH_POINTS
	if pts.size() >= 2:
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			draw_line(a, b, Color(0.28, 0.22, 0.12, 0.65), Config.PATH_HALF_WIDTH * 2.0 + 18.0)
			draw_line(a, b, Color(0.78, 0.66, 0.40, 0.40), Config.PATH_HALF_WIDTH * 2.0 + 6.0)
		# 出生：绿环；终点：锈红环（盲测可读）
		draw_circle(pts[0], 42.0, Color(0.25, 0.70, 0.30, 0.40))
		draw_circle(pts[0], 26.0, Color(0.45, 0.92, 0.40, 0.55))
		var end: Vector2 = pts[pts.size() - 1]
		draw_circle(end, 44.0, Color(0.75, 0.28, 0.15, 0.38))
		draw_circle(end, 26.0, Color(0.95, 0.45, 0.22, 0.50))
	# 地图边缘暗带（非视口 vignette）
	var edge := Color(0.02, 0.03, 0.04, 0.35)
	draw_rect(Rect2(0, 0, ms.x, 40), edge)
	draw_rect(Rect2(0, ms.y - 40, ms.x, 40), edge)
	draw_rect(Rect2(0, 0, 32, ms.y), edge)
	draw_rect(Rect2(ms.x - 32, 0, 32, ms.y), edge)
