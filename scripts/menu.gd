# 主菜单（CO-003）：标题 / 开始游戏 / 语言切换 / 控制说明 / 退出。
# CO-022：地图选择。CO-ART-PROD-001：BGM + Theme。
# CO-044修订：龙族仅局内事件/剧情解锁后出现在菜单——禁止标题连点。
extends Control

const LivingRampartUi = preload("res://scripts/living_rampart_ui.gd")
const _PlayerSecrets = preload("res://scripts/player_secrets.gd")

var title_label: Label
var subtitle_label: Label
var secret_toast: Label
var start_button: Button
var lang_button: Button
var quit_button: Button
var controls_label: Label
var race_row: HBoxContainer
var race_buttons: Array = []
var map_buttons: Array = []
var _selected_race := "human"
var _selected_map := Config.DEFAULT_MAP_ID
var _toast_timer: float = 0.0

func _ready() -> void:
	TranslationServer.set_locale("zh_CN")
	_PlayerSecrets.ensure_loaded()
	_build_ui()
	LivingRampartUi.apply_to_tree(self)
	refresh_texts()
	_show_pending_unlock_toast()
	start_button.pressed.connect(_start_game)
	lang_button.pressed.connect(_toggle_language)
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	if AudioController:
		AudioController.start_bgm("menu")

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and secret_toast != null:
			secret_toast.visible = false

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	secret_toast = _mk_label(15, Color(1.0, 0.78, 0.35))
	secret_toast.custom_minimum_size = Vector2(720, 22)
	secret_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secret_toast.visible = false
	vbox.add_child(secret_toast)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)
	race_row = HBoxContainer.new()
	race_row.add_theme_constant_override("separation", 8)
	race_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(race_row)
	_rebuild_race_buttons()
	var spacer_map := Control.new()
	spacer_map.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer_map)
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	map_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(map_row)
	for map_id in Config.list_map_ids():
		var mb := Button.new()
		mb.custom_minimum_size = Vector2(140, 34)
		mb.add_theme_font_size_override("font_size", 14)
		mb.toggle_mode = true
		mb.button_pressed = (map_id == _selected_map)
		mb.pressed.connect(func() -> void: _select_map(map_id))
		map_row.add_child(mb)
		map_buttons.append({"id": map_id, "btn": mb})
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
	for entry in map_buttons:
		entry["btn"].text = tr(entry["id"])
	start_button.text = tr("menu_start")
	lang_button.text = tr("menu_language") % _lang_name()
	quit_button.text = tr("menu_quit")
	controls_label.text = tr("menu_controls")

func _menu_race_ids() -> Array[String]:
	# CO-044 搁置：只跟 Config.public_race_ids（剧情解锁后再叠 secrets）
	return Config.public_race_ids()

func _rebuild_race_buttons() -> void:
	for child in race_row.get_children():
		race_row.remove_child(child)
		child.free()
	race_buttons.clear()
	var ids := _menu_race_ids()
	if _selected_race not in ids:
		_selected_race = "human"
	for race_id in ids:
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(120, 36)
		rb.add_theme_font_size_override("font_size", 14)
		rb.toggle_mode = true
		rb.button_pressed = (race_id == _selected_race)
		var rid := str(race_id)
		rb.pressed.connect(func() -> void: _select_race(rid))
		rb.text = tr("race_" + rid)
		if rid == "dragon":
			rb.modulate = Color(1.0, 0.85, 0.55)
		race_row.add_child(rb)
		race_buttons.append({"id": rid, "btn": rb})
	LivingRampartUi.apply_to_tree(race_row)

func _show_pending_unlock_toast() -> void:
	if not get_tree().has_meta("secret_unlock_toast"):
		return
	var key: String = str(get_tree().get_meta("secret_unlock_toast"))
	get_tree().remove_meta("secret_unlock_toast")
	if secret_toast == null or key.is_empty():
		return
	secret_toast.text = tr(key)
	secret_toast.visible = true
	_toast_timer = 4.0

func _select_race(race_id: String) -> void:
	_selected_race = race_id
	for entry in race_buttons:
		entry["btn"].button_pressed = (entry["id"] == race_id)
	if AudioController:
		AudioController.play("ui")

func _select_map(map_id: String) -> void:
	_selected_map = map_id
	for entry in map_buttons:
		entry["btn"].button_pressed = (entry["id"] == map_id)
	if AudioController:
		AudioController.play("ui")

func _start_game() -> void:
	if AudioController:
		AudioController.play("ui")
		AudioController.stop_bgm()
	get_tree().set_meta("selected_race", _selected_race)
	get_tree().set_meta("selected_map", _selected_map)
	get_tree().change_scene_to_file("res://main.tscn")
