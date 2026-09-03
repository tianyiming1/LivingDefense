extends Node2D
# 敌方单位（程序自绘菱形 + 核心点）——敌方色由调用方设置
var color: Color = Color(0.91, 0.40, 0.29)

func _draw() -> void:
    var pts := PackedVector2Array([Vector2(0, -18), Vector2(14, 0), Vector2(0, 18), Vector2(-14, 0)])
    draw_polygon(pts, PackedColorArray([color]))
    # 内圈暗核（区分"敌方核心"）
    draw_circle(Vector2.ZERO, 5.0, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0))