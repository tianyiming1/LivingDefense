# 主菜单（CO-003）：标题 / 开始游戏 / 语言切换 / 控制说明 / 退出。
# 脚本构建 UI（与现有 demo/hud 模式一致），无外部资源依赖。
# 语言选择作用于全局 TranslationServer，进入游戏后保持。
extends Control

var title_label: Label
var subtitle_label: Label
var start_button: Button
var lang_button: Button
var quit_button: Button
var controls_label: Label
var race_buttons: Array = []
var _selected_race := "human"

func _ready() -> void:
	# 默认中文（与 CO-002 验收标准 1 一致；后续加语言记忆设置）
	TranslationServer.set_locale("zh_CN")
	_build_ui()
	refresh_texts()
	start_button.pressed.connect(_start_game)
	lang_button.pressed.connect(_toggle_language)
	quit_button.pressed.connect(func() -> void: get_tree().quit())

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.colors = PackedColorArray([Color(0.11, 0.13, 0.22), Color(0.05, 0.06, 0.10)])
	grad.gradient.offsets = PackedFloat32Array([0.0, 1.0])
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	var grad_rect := TextureRect.new()
	grad_rect.texture = grad
	grad_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(grad_rect)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	title_label = _mk_label(54, Color(0.96, 0.96, 1.0))
	title_label.custom_minimum_size = Vector2(720, 60)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	subtitle_label = _mk_label(17, Color(0.76, 0.79, 0.86))
	subtitle_label.custom_minimum_size = Vector2(720, 24)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle_label)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)
	var race_row := HBoxContainer.new()
	race_row.add_theme_constant_override("separation", 8)
	race_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(race_row)
	for race_id in ["human", "fungus", "dragon", "silicon"]:
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(120, 36)
		rb.add_theme_font_size_override("font_size", 14)
		rb.toggle_mode = true
		rb.button_pressed = (race_id == _selected_race)
		rb.pressed.connect(func() -> void: _select_race(race_id))
		race_row.add_child(rb)
		race_buttons.append({"id": race_id, "btn": rb})
	var spacer0 := Control.new()
	spacer0.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer0)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(260, 58)
	start_button.add_theme_font_size_override("font_size", 22)
	vbox.add_child(start_button)
	lang_button = Button.new()
	lang_button.custom_minimum_size = Vector2(260, 42)
	lang_button.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lang_button)
	quit_button = Button.new()
	quit_button.custom_minimum_size = Vector2(260, 42)
	quit_button.add_theme_font_size_override("font_size", 16)
	vbox.add_child(quit_button)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer2)
	controls_label = _mk_label(14, Color(0.6, 0.63, 0.7))
	controls_label.custom_minimum_size = Vector2(720, 20)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls_label)

func _toggle_language() -> void:
	var cur: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en" if cur == "zh_CN" else "zh_CN")
	refresh_texts()

func _lang_name() -> String:
	if TranslationServer.get_locale() == "zh_CN":
		return tr("lang_zh")
	return tr("lang_en")

func refresh_texts() -> void:
	title_label.text = tr("menu_title")
	subtitle_label.text = tr("menu_subtitle")
	for entry in race_buttons:
		entry["btn"].text = tr("race_" + entry["id"])
	start_button.text = tr("menu_start")
	lang_button.text = tr("menu_language") % _lang_name()
	quit_button.text = tr("menu_quit")
	controls_label.text = tr("menu_controls")

func _select_race(race_id: String) -> void:
	_selected_race = race_id
	for entry in race_buttons:
		entry["btn"].button_pressed = (entry["id"] == race_id)

func _start_game() -> void:
	get_tree().set_meta("selected_race", _selected_race)
	get_tree().change_scene_to_file("res://main.tscn")