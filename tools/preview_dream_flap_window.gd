# Self-flap preview: 16f complete cycle; sheet shows ALL frames (2×8)
extends Node2D

var _view: Node2D
var _idx_label: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 1))
	var label := Label.new()
	label.text = "SELF flap (042) — 16f complete @ ~125ms — NO WorkBuddy\nEsc quit"
	label.position = Vector2(16, 12)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)

	_idx_label = Label.new()
	_idx_label.position = Vector2(16, 64)
	_idx_label.add_theme_font_size_override("font_size", 22)
	add_child(_idx_label)

	var script: Script = load("res://scripts/unit_sprite_view.gd") as Script
	_view = Node2D.new()
	_view.set_script(script)
	_view.position = Vector2(640, 360)
	_view.scale = Vector2(3.0, 3.0)
	add_child(_view)
	var tex: Texture2D = UnitSprites.load_texture("dragon", 17)
	_view.setup(tex, "spell", 17.0, "dragon", false, 17, true)
	_view.set_moving(true, true)

	# 2×8 grid so all 16 atlas cells fit on screen
	var sheet_path := "res://assets/pixels/dragon/unit_17_anim/fly_sheet.png"
	var sheet: Texture2D = UnitSprites.load_disk_tex(sheet_path, true)
	if sheet != null:
		var cap := Label.new()
		cap.text = "all 16 frames (2 rows × 8)"
		cap.position = Vector2(40, 520)
		add_child(cap)
		var cell_w := 96
		var cell_h := 108
		var scale := 0.85
		for i in range(16):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(float(i * cell_w), 0.0, float(cell_w), float(cell_h))
			var cell := Sprite2D.new()
			cell.texture = at
			cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cell.centered = false
			var col := i % 8
			var row := int(i / 8)
			cell.position = Vector2(40 + col * cell_w * scale, 545 + row * (cell_h * scale + 4))
			cell.scale = Vector2(scale, scale)
			add_child(cell)
			var n := Label.new()
			n.text = str(i)
			n.position = cell.position + Vector2(2, -14)
			n.add_theme_font_size_override("font_size", 12)
			add_child(n)


func _process(_delta: float) -> void:
	if _view == null or _idx_label == null:
		return
	var idx: int = int(_view.get("_flap_idx"))
	var n: int = int(_view.get("_flap_n"))
	_idx_label.text = "flap_idx %d / %d" % [idx, maxi(n - 1, 0)]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
