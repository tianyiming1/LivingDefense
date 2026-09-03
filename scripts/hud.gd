# HUD（S1 人族）：顶栏（金钱/生命/战损/波次）、右侧单位面板、底栏（开始/变速/技能）、
# 单位信息面板（进化/出售）、结局遮罩。只发信号，不做游戏逻辑。
# CO-002 i18n：全部可见文本走 tr()，refresh_texts() 支持运行时语言切换。
extends CanvasLayer

signal buy_requested(unit_id: int)
signal start_wave_requested
signal speed_toggled
signal evolve_requested
signal sell_requested
signal split_requested
signal skill_requested
signal restart_requested
signal menu_requested

var money_label: Label
var supply_label: Label
var lives_label: Label
var losses_label: Label
var wave_label: Label
var crystal_label: Label
var status_label: Label
var start_button: Button
var speed_button: Button
var skill_button: Button
var menu_button: Button
var unit_buttons: Array = []
var info_panel: PanelContainer
var info_title: Label
var info_stats: Label
var evolve_button: Button
var sell_button: Button
var split_button: Button
var overlay: ColorRect
var overlay_title: Label
var overlay_sub: Label
var overlay_button: Button

var _money := Config.START_MONEY
var _supply := Config.START_SUPPLY
var _lives := Config.START_LIVES
var _losses := 0
var _wave := 0
var _race := "human"
var _crystal := 0
var _placing := false
var _during_wave := false
var _skill_ready := true
var _speed_is_2x := false

func _ready() -> void:
	_build_top_bar()
	_build_unit_panel()
	_build_bottom_bar()
	_build_info_panel()
	_build_overlay()
	refresh_texts()

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(14, 10)
	bar.add_theme_constant_override("separation", 26)
	add_child(bar)
	money_label = _mk_label(22, Color(1.0, 0.88, 0.35))
	supply_label = _mk_label(22, Color(0.55, 0.85, 0.45))
	lives_label = _mk_label(22, Color(0.95, 0.40, 0.40))
	losses_label = _mk_label(22, Color(0.75, 0.75, 0.78))
	wave_label = _mk_label(22, Color(1, 1, 1))
	crystal_label = _mk_label(18, Color(0.45, 0.85, 1.0))
	crystal_label.visible = false
	bar.add_child(money_label)
	bar.add_child(supply_label)
	bar.add_child(lives_label)
	bar.add_child(losses_label)
	bar.add_child(wave_label)
	bar.add_child(crystal_label)
	status_label = _mk_label(17, Color(0.88, 0.88, 0.88))
	status_label.position = Vector2(14, 48)
	add_child(status_label)

func _build_unit_panel() -> void:
	_rebuild_unit_panel()

func _rebuild_unit_panel() -> void:
	for b in unit_buttons:
		if is_instance_valid(b):
			b.queue_free()
	unit_buttons.clear()
	for child in get_children():
		if child is VBoxContainer and child.position.x > 1000:
			child.queue_free()
	var panel := VBoxContainer.new()
	panel.position = Vector2(1280 - 124, 84)
	panel.add_theme_constant_override("separation", 8)
	add_child(panel)
	for u in Config.shop_units(_race):
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 52)
		b.add_theme_font_size_override("font_size", 15)
		b.text = "%s\n$%d" % [tr(u["name_key"]), int(u["cost"])]
		var uid := int(u["id"])
		b.pressed.connect(func() -> void: buy_requested.emit(uid))
		panel.add_child(b)
		unit_buttons.append(b)

func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(14, 720 - 62)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	start_button = Button.new()
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	bar.add_child(start_button)
	speed_button = Button.new()
	speed_button.add_theme_font_size_override("font_size", 16)
	speed_button.text = tr("hud_speed_1x")
	speed_button.pressed.connect(func() -> void: speed_toggled.emit())
	bar.add_child(speed_button)
	skill_button = Button.new()
	skill_button.add_theme_font_size_override("font_size", 16)
	skill_button.pressed.connect(func() -> void: skill_requested.emit())
	bar.add_child(skill_button)
	menu_button = Button.new()
	menu_button.add_theme_font_size_override("font_size", 16)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	bar.add_child(menu_button)

func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.visible = false
	info_panel.position = Vector2(1280 - 330, 720 - 158)
	add_child(info_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	info_panel.add_child(box)
	info_title = _mk_label(17, Color(1, 1, 1))
	box.add_child(info_title)
	info_stats = _mk_label(14, Color(0.85, 0.85, 0.85))
	box.add_child(info_stats)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	box.add_child(hb)
	evolve_button = Button.new()
	evolve_button.pressed.connect(func() -> void: evolve_requested.emit())
	hb.add_child(evolve_button)
	sell_button = Button.new()
	sell_button.pressed.connect(func() -> void: sell_requested.emit())
	hb.add_child(sell_button)
	split_button = Button.new()
	split_button.pressed.connect(func() -> void: split_requested.emit())
	hb.add_child(split_button)
	split_button.visible = false

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.08, 0.82)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	add_child(overlay)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cc)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	cc.add_child(vbox)
	overlay_title = _mk_label(46, Color(1, 1, 1))
	vbox.add_child(overlay_title)
	overlay_sub = _mk_label(20, Color(0.9, 0.9, 0.9))
	vbox.add_child(overlay_sub)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(180, 46)
	overlay_button.add_theme_font_size_override("font_size", 17)
	overlay_button.pressed.connect(func() -> void: restart_requested.emit())
	vbox.add_child(overlay_button)

# ---------- 语言切换：整体重刷可见文本（main 按键调用） ----------
func refresh_texts() -> void:
	money_label.text = tr("hud_money") % _money
	if supply_label != null:
		supply_label.text = tr("hud_supply") % [_supply, Config.MAX_SUPPLY]
		supply_label.visible = (_race == "human")
	lives_label.text = tr("hud_lives") % _lives
	losses_label.text = tr("hud_lost") % _losses
	wave_label.text = tr("hud_wave") % [_wave, Config.TOTAL_WAVES]
	start_button.text = tr("hud_start")
	menu_button.text = tr("hud_menu")
	for i in range(unit_buttons.size()):
		var u: Dictionary = Config.shop_units(_race)[i]
		var sc: int = Config.supply_cost(u) if _race == "human" else 0
		if sc > 0:
			unit_buttons[i].text = "%s\n$%d · %d" % [tr(u["name_key"]), int(u["cost"]), sc]
		else:
			unit_buttons[i].text = "%s\n$%d" % [tr(u["name_key"]), int(u["cost"])]
	_refresh_skill_button()
	if speed_button != null:
		speed_button.text = tr("hud_speed_2x") if _speed_is_2x else tr("hud_speed_1x")
	if evolve_button != null:
		evolve_button.text = _ev_text()
	if sell_button != null:
		sell_button.text = tr("hud_sell_cost") % _last_sell_val
	if split_button != null:
		split_button.text = tr("hud_split")
	overlay_button.text = tr("hud_restart")

# 信息面板显示的进化/出售文本需要记住最近的值才能刷新
var _last_ev_cost := 0
var _last_can_evolve := false
var _last_can_split := false
var _last_sell_val := 0

func _ev_text() -> String:
	if _last_can_evolve:
		return tr("hud_evolve_cost") % _last_ev_cost
	return tr("hud_evolve_max")

# ---------- 公共接口（由 main.gd 调用） ----------
func set_money(v: int) -> void:
	_money = v
	money_label.text = tr("hud_money") % v
	refresh_unit_buttons()

func set_supply(v: int) -> void:
	_supply = v
	if supply_label != null:
		supply_label.text = tr("hud_supply") % [_supply, Config.MAX_SUPPLY]
		supply_label.visible = (_race == "human")
	refresh_unit_buttons()

func set_lives(v: int) -> void:
	_lives = v
	lives_label.text = tr("hud_lives") % v

func set_losses(n: int) -> void:
	_losses = n
	losses_label.text = tr("hud_lost") % n

func set_wave(w: int) -> void:
	_wave = w
	wave_label.text = tr("hud_wave") % [w, Config.TOTAL_WAVES]

func set_status(s: String) -> void:
	status_label.text = s

func set_placing(b: bool) -> void:
	_placing = b
	refresh_unit_buttons()

func set_during_wave(b: bool) -> void:
	_during_wave = b
	start_button.disabled = b
	refresh_unit_buttons()
	_refresh_skill_button()

func set_skill_ready(b: bool) -> void:
	_skill_ready = b
	_refresh_skill_button()

func set_race(r: String) -> void:
	_race = r
	crystal_label.visible = (_race == "silicon")
	if supply_label != null:
		supply_label.visible = (_race == "human")
	_rebuild_unit_panel()
	refresh_texts()

func set_crystal(v: int) -> void:
	_crystal = v
	crystal_label.text = tr("hud_crystal") % v

func _skill_cd_waves() -> int:
	var sk: Dictionary = Config.RACES[_race]["active_skill"]
	return int(sk.get("cd_waves", sk.get("carpet_fever_cd_waves", 99)))

func _refresh_skill_button() -> void:
	if _during_wave and _skill_ready:
		match _race:
			"human":
				skill_button.text = tr("skill_ready_text")
			"fungus":
				skill_button.text = tr("skill_fungus_ready")
			"silicon":
				skill_button.text = tr("skill_silicon_ready") % _crystal
			"dragon":
				skill_button.text = tr("skill_dragon_ready")
			_:
				skill_button.text = tr("skill_ready_text")
		skill_button.disabled = (_race == "silicon" and _crystal < int(Config.SKILL_SILICON["freeze_cost"]))
	else:
		var cd := tr("hud_cd_waves") % _skill_cd_waves()
		var cd_key := "skill_cd_human"
		match _race:
			"fungus":
				cd_key = "skill_cd_fungus"
			"silicon":
				cd_key = "skill_cd_silicon"
			"dragon":
				cd_key = "skill_cd_dragon"
		skill_button.text = tr(cd_key) % (tr("hud_ready") if _skill_ready else cd)
		skill_button.disabled = true

func refresh_unit_buttons() -> void:
	var units: Array = Config.shop_units(_race)
	for i in range(unit_buttons.size()):
		if i >= units.size():
			break
		var sc: int = Config.supply_cost(units[i]) if _race == "human" else 0
		var can_buy := (not _placing) and _money >= int(units[i]["cost"]) and _supply >= sc
		if Config.is_farmer(units[i]):
			# 上限由 main 再拦一层；按钮侧只看钱
			pass
		unit_buttons[i].disabled = not can_buy

func show_info(title: String, stats: String, ev_cost: int, sell_val: int, can_evolve: bool, can_split: bool = false) -> void:
	info_title.text = title
	info_stats.text = stats
	_last_ev_cost = ev_cost
	_last_can_evolve = can_evolve
	_last_can_split = can_split
	_last_sell_val = sell_val
	evolve_button.text = _ev_text()
	evolve_button.disabled = not can_evolve
	evolve_button.visible = _race != "fungus"
	sell_button.text = tr("hud_sell_cost") % sell_val
	if split_button != null:
		split_button.visible = _race == "fungus"
		split_button.disabled = not can_split
	info_panel.visible = true

func hide_info() -> void:
	info_panel.visible = false

func set_speed_text(t: String) -> void:
	_speed_is_2x = t.find("2") >= 0
	speed_button.text = tr("hud_speed_2x") if _speed_is_2x else tr("hud_speed_1x")

func show_overlay(title: String, sub: String) -> void:
	overlay_title.text = title
	overlay_sub.text = sub
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = true