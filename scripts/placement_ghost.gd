# 建造预览幽灵：跟随鼠标，绿色=可放，红色=不可放，显示射程
extends Node2D

var unit_id := -1
var valid := false
var race := "human"
var _sprite: Sprite2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible = false
	add_child(_sprite)

func _ghost_range(def: Dictionary) -> float:
	var kind: String = def["kind"]
	if kind == "melee":
		return 55.0
	if kind == "aura":
		return float(def.get("aura_range", 170.0))
	if kind == "healer":
		return float(def.get("range", 155.0))
	var base_r: float = float(def["range"])
	var standoff: float = maxf(0.0, Config.dist_to_path(global_position) - Config.PATH_HALF_WIDTH - float(def["radius"]))
	return base_r + standoff + Config.RANGED_COMBAT_BONUS

func _draw() -> void:
	if unit_id < 0:
		return
	var def: Dictionary = Config.unit_at(race, unit_id)
	if def.is_empty():
		return
	var kind: String = def["kind"]
	var r: float = float(def["radius"])
	var tex: Texture2D = UnitSprites.load_texture(race, unit_id)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = UnitSprites.foot_offset(tex)
		_sprite.scale = Vector2.ONE * UnitSprites.scale_for_radius(r)
		_sprite.modulate = Color(1, 1, 1, 0.92) if valid else Color(1.0, 0.45, 0.45, 0.75)
		_sprite.visible = true
	else:
		_sprite.visible = false
		var color := Color(def["color"], 0.55) if valid else Color(1.0, 0.25, 0.25, 0.55)
		draw_circle(Vector2.ZERO, r, color)
		draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.35), false, 2.0, true)
	if not valid:
		return
	match kind:
		"melee":
			draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 96, Color(0.75, 0.85, 1.0, 0.45), 1.2, true)
		"aura":
			var ar: float = float(def.get("aura_range", 170.0))
			draw_arc(Vector2.ZERO, ar, 0.0, TAU, 96, Color(0.95, 0.95, 1.0, 0.35), 1.2, true)
		_:
			var eff: float = _ghost_range(def)
			draw_arc(Vector2.ZERO, eff, 0.0, TAU, 96, Color(def["color"].r, def["color"].g, def["color"].b, 0.22), 1.2, true)
			draw_arc(Vector2.ZERO, float(def["range"]), 0.0, TAU, 96, Color(1, 1, 1, 0.35), 1.0, true)
