# 地图层：像素草地平铺 + 路径走廊 + 出生/终点标记
# CO-037：路径描边氛围 + 暗角，减轻「灰盒」感
# 天气叠加见 weather_controller.gd（独立层，不改本层逻辑）
extends Node2D

const TILE_SIZE := 32
const TEX_GRASS := [
	"res://assets/pixels/map/grass_a_32.png",
	"res://assets/pixels/map/grass_b_32.png",
	"res://assets/pixels/map/grass_c_32.png",
]
const TEX_PATH := "res://assets/pixels/map/path_32.png"
const TEX_SPAWN := "res://assets/pixels/map/spawn_32.png"
const TEX_GOAL := "res://assets/pixels/map/goal_32.png"

var _tilemap: TileMap
var _use_pixels := false
var _fx: Node2D = null

func _ready() -> void:
	_use_pixels = _can_use_pixel_tiles()
	if _use_pixels:
		_build_tilemap()
	else:
		queue_redraw()
	_fx = Node2D.new()
	_fx.z_index = 2
	_fx.set_script(load("res://scripts/map_fx.gd"))
	add_child(_fx)
	if _fx.has_method("setup"):
		_fx.setup(_use_pixels)

func _can_use_pixel_tiles() -> bool:
	for p in TEX_GRASS:
		if not ResourceLoader.exists(p):
			return false
	return ResourceLoader.exists(TEX_PATH)

func _build_tilemap() -> void:
	_tilemap = TileMap.new()
	_tilemap.z_index = 0
	_tilemap.tile_set = _make_tileset()
	_tilemap.rendering_quadrant_size = 32
	add_child(_tilemap)
	var cols := int(ceil(Config.MAP_SIZE.x / float(TILE_SIZE)))
	var rows := int(ceil(Config.MAP_SIZE.y / float(TILE_SIZE)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(rows):
		for x in range(cols):
			var center := Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			var dist: float = Config.dist_to_path(center)
			var tile := Vector2i(x, y)
			if dist <= Config.PATH_HALF_WIDTH:
				_tilemap.set_cell(0, tile, 0, Vector2i(3, 0))
			else:
				var g: int = rng.randi_range(0, 2)
				_tilemap.set_cell(0, tile, 0, Vector2i(g, 0))
	_stamp_markers()

func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/pixels/map/tileset_32.png")
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(12):
		atlas.create_tile(Vector2i(i, 0))
	ts.add_source(atlas, 0)
	return ts

func _stamp_markers() -> void:
	if _tilemap == null:
		return
	var pts: Array[Vector2] = Config.PATH_POINTS
	_paint_marker(pts[0], 8)
	_paint_marker(pts[pts.size() - 1], 9)

func _paint_marker(world_pos: Vector2, atlas_x: int) -> void:
	var tile := Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			_tilemap.set_cell(0, tile + Vector2i(ox, oy), 0, Vector2i(atlas_x, 0))

func _draw() -> void:
	# 像素层之下仍画实心底，避免 TileMap 失败时白屏/空屏
	draw_rect(Rect2(Vector2.ZERO, Config.MAP_SIZE), Color("386640"))
	if _use_pixels:
		return
	var pts: Array[Vector2] = Config.PATH_POINTS
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], Color(0.42, 0.36, 0.22), Config.PATH_HALF_WIDTH * 2.0 + 10.0)
		draw_line(pts[i], pts[i + 1], Color("C7B380"), Config.PATH_HALF_WIDTH * 2.0)
	draw_circle(pts[0], 34.0, Color(0.18, 0.55, 0.22, 0.85))
	draw_circle(pts[0], 22.0, Color(0.35, 0.85, 0.35))
	draw_circle(pts[pts.size() - 1], 36.0, Color(0.55, 0.18, 0.12, 0.85))
	draw_circle(pts[pts.size() - 1], 22.0, Color("BF4A2F"))
