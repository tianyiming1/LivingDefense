# HUD — CO-034 Dota2 式底栏：左下商店 / 底中单位+技能 / 右下波次操作；顶栏居中资源
# 右侧 x≥1100 留给大本营世界点击。只发信号，不做游戏逻辑。
# CO-002 i18n：可见文本走 tr()。
# CO-ART-PROD-001 W2：统一钢蓝 Theme。
extends CanvasLayer

const LivingRampartUi = preload("res://scripts/living_rampart_ui.gd")

signal buy_requested(unit_id: int)
signal start_wave_requested
signal speed_toggled
signal evolve_requested
signal sell_requested
signal split_requested
signal skill_requested
signal restart_requested
signal menu_requested
signal tech_requested(tech_id: String)

const COL_GOLD := LivingRampartUi.GOLD
const COL_HQ := LivingRampartUi.DANGER
const COL_SUPPLY := LivingRampartUi.SUPPLY
const COL_WOOD := Color(0.35, 0.42, 0.55)
const COL_WOOD_BG := LivingRampartUi.STEEL_DARK
const COL_MUTED := LivingRampartUi.MUTED
const COL_WHITE := LivingRampartUi.WHITE

var money_label: Label
var supply_label: Label
var lives_label: Label
var losses_label: Label
var wave_label: Label
var crystal_label: Label
var nest_label: Label
var egg_label: Label
var items_label: Label
var status_label: Label
var start_button: Button
var speed_button: Button
var skill_button: Button
var menu_button: Button
var unit_buttons: Array = []
var tech_buttons: Array = []
var tech_panel: Control = null
var _tech_box: Control = null
var _human_tech: Node = null
var _hq_selected := false
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

var _shop_panel: Control = null
var _shop_grid: GridContainer = null
var _hero_panel: PanelContainer = null
var _top_panel: PanelContainer = null
var _right_panel: PanelContainer = null
var _right_body: VBoxContainer = null
var _roster_popup: PanelContainer = null
var _roster_body: VBoxContainer = null
var _roster_open := false
var _btn_roster_close: Button = null
var _minimap: Control = null
var _tab_build: Button = null
var _tab_tech: Button = null
var _right_mode := "build"  # build | tech
var _ui_theme: Theme = null
var _main_ref: Node = null

var _money := Config.START_MONEY
var _supply := Config.START_SUPPLY
var _lives := Config.START_LIVES
var _losses := 0
var _wave := 0
var _race := "human"
var _crystal := 0
var _nest_used := 0
var _nest_max := 4
var _egg_count := 0
var _egg_sec := 0
var _placing := false
var _during_wave := false
var _skill_ready := true
var _speed_is_2x := false
var _last_ev_cost := 0
var _last_can_evolve := false
var _last_next_rank := ""
var _last_can_split := false
var _last_sell_val := 0

func _ready() -> void:
	_ui_theme = LivingRampartUi.build()
	_build_top_bar()
	_build_minimap()
	_build_right_panel()
	_build_unit_panel()
	_build_tech_panel()
	_build_hero_and_actions()
	_build_overlay()
	LivingRampartUi.apply_to_tree(self)
	_apply_right_mode()
	refresh_texts()
	_refresh_select_idle()

func bind_world(main: Node) -> void:
	_main_ref = main
	if _minimap != null and _minimap.has_method("setup"):
		_minimap.setup(main)
	if _minimap != null and _minimap.has_signal("jump_requested"):
		if not _minimap.jump_requested.is_connected(_on_minimap_jump):
			_minimap.jump_requested.connect(_on_minimap_jump)

func _on_minimap_jump(world_pos: Vector2) -> void:
	if _main_ref == null:
		return
	var cam: Camera2D = _main_ref.get("battle_cam") as Camera2D
	if cam != null and cam.has_method("focus_world"):
		cam.focus_world(world_pos)
		return
	if _main_ref.get("world_root") != null:
		for c in _main_ref.world_root.get_children():
			if c is Camera2D and c.has_method("focus_world"):
				c.focus_world(world_pos)
				return
func bind_human_tech(tech: Node) -> void:
	_human_tech = tech
	if tech_panel != null and not _hq_selected:
		tech_panel.visible = false
	refresh_tech_and_shop()

func set_hq_selected(on: bool) -> void:
	_hq_selected = on
	if on and _race == "human" and _human_tech != null:
		_open_roster("tech")
	_refresh_tech_buttons()

func refresh_tech_and_shop() -> void:
	_refresh_tech_buttons()
	refresh_unit_buttons()
	refresh_texts()

func _mk_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _wood_stylebox() -> StyleBoxFlat:
	return LivingRampartUi._panel()

func _apply_panel_style(p: PanelContainer) -> void:
	if _ui_theme != null:
		p.theme = _ui_theme
	p.add_theme_stylebox_override("panel", LivingRampartUi._panel())

func _style_shop_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 11)
	b.custom_minimum_size = Vector2(86, 30)
	if _ui_theme != null:
		b.theme = _ui_theme
	var n := LivingRampartUi.shop_slot()
	b.add_theme_stylebox_override("normal", n)
	var h := LivingRampartUi.shop_slot()
	h.border_color = LivingRampartUi.GOLD
	b.add_theme_stylebox_override("hover", h)
	var d := LivingRampartUi.shop_slot()
	d.bg_color = Color(0.12, 0.12, 0.14, 0.7)
	d.border_color = Color(0.35, 0.35, 0.4, 0.5)
	b.add_theme_stylebox_override("disabled", d)

func _style_primary_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 14)
	if _ui_theme != null:
		b.theme = _ui_theme

func _dock_top_y() -> float:
	# 底栏叠在 16:9 视口底部（单视口，不再用加高壳）
	return Config.VIEW_SIZE.y - Config.HUD_BOTTOM_PX

# ---------- 顶栏（扁比分条，不挡战场）----------
func _build_top_bar() -> void:
	# CO-040 / Dota 底栏托：高度 = Config.HUD_BOTTOM_PX，镜头安全区同步避开
	var dock := ColorRect.new()
	dock.color = Color(0.04, 0.035, 0.03, 0.55)
	dock.position = Vector2(0, _dock_top_y())
	dock.size = Vector2(Config.VIEW_SIZE.x, Config.HUD_BOTTOM_PX)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock)
	_top_panel = PanelContainer.new()
	_top_panel.position = Vector2(200, 4)
	_top_panel.custom_minimum_size = Vector2(880, 40)
	_apply_panel_style(_top_panel)
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_panel.add_child(bar)
	money_label = _mk_label(17, COL_GOLD)
	supply_label = _mk_label(17, COL_SUPPLY)
	lives_label = _mk_label(17, COL_HQ)
	losses_label = _mk_label(15, COL_MUTED)
	wave_label = _mk_label(17, COL_WHITE)
	crystal_label = _mk_label(15, Color(0.45, 0.85, 1.0))
	crystal_label.visible = false
	nest_label = _mk_label(15, Color(1.0, 0.55, 0.28))
	nest_label.visible = false
	egg_label = _mk_label(14, Color(1.0, 0.72, 0.35))
	egg_label.visible = false
	items_label = _mk_label(13, COL_GOLD)
	items_label.text = ""
	for c in [money_label, supply_label, lives_label, losses_label, wave_label, crystal_label, nest_label, egg_label, items_label]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(c)
	status_label = _mk_label(13, COL_MUTED)
	status_label.position = Vector2(220, 46)
	status_label.custom_minimum_size = Vector2(840, 20)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

# ---------- 左下：小地图（Dota 位）----------
func _build_minimap() -> void:
	var wrap := PanelContainer.new()
	wrap.position = Vector2(6, _dock_top_y() + 4.0)
	wrap.custom_minimum_size = Vector2(168, Config.HUD_BOTTOM_PX - 8.0)
	_apply_panel_style(wrap)
	add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	wrap.add_child(box)
	var title := _mk_label(10, COL_GOLD)
	title.text = tr("hud_minimap")
	title.name = "MinimapTitle"
	box.add_child(title)
	_minimap = Control.new()
	_minimap.set_script(load("res://scripts/minimap_view.gd"))
	_minimap.custom_minimum_size = Vector2(156, Config.HUD_BOTTOM_PX - 28.0)
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_minimap)

# ---------- 右下：波次操作 + 打开「部署/科研」弹层（列表不挤在底栏里）----------
func _build_right_panel() -> void:
	_right_panel = PanelContainer.new()
	_right_panel.position = Vector2(1008, _dock_top_y() + 4.0)
	_right_panel.custom_minimum_size = Vector2(264, Config.HUD_BOTTOM_PX - 8.0)
	_apply_panel_style(_right_panel)
	add_child(_right_panel)
	_right_body = VBoxContainer.new()
	_right_body.add_theme_constant_override("separation", 4)
	_right_panel.add_child(_right_body)

	var open_row := HBoxContainer.new()
	open_row.add_theme_constant_override("separation", 4)
	_right_body.add_child(open_row)
	_tab_build = Button.new()
	_tab_build.custom_minimum_size = Vector2(124, 30)
	_tab_build.add_theme_font_size_override("font_size", 12)
	_style_primary_button(_tab_build)
	_tab_build.pressed.connect(func() -> void: _toggle_roster("build"))
	open_row.add_child(_tab_build)
	_tab_tech = Button.new()
	_tab_tech.custom_minimum_size = Vector2(124, 30)
	_tab_tech.add_theme_font_size_override("font_size", 12)
	_style_primary_button(_tab_tech)
	_tab_tech.pressed.connect(func() -> void: _toggle_roster("tech"))
	open_row.add_child(_tab_tech)

	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(248, 28)
	start_button.add_theme_font_size_override("font_size", 12)
	_style_primary_button(start_button)
	start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	_right_body.add_child(start_button)

	var ctrl := HBoxContainer.new()
	ctrl.add_theme_constant_override("separation", 4)
	_right_body.add_child(ctrl)
	speed_button = Button.new()
	speed_button.custom_minimum_size = Vector2(120, 24)
	speed_button.add_theme_font_size_override("font_size", 11)
	speed_button.pressed.connect(func() -> void: speed_toggled.emit())
	ctrl.add_child(speed_button)
	menu_button = Button.new()
	menu_button.custom_minimum_size = Vector2(120, 24)
	menu_button.add_theme_font_size_override("font_size", 11)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	ctrl.add_child(menu_button)

	_build_roster_popup()

func _build_roster_popup() -> void:
	_roster_popup = PanelContainer.new()
	# 弹在底栏上方，盖住战场一角但不挡全屏
	_roster_popup.position = Vector2(700, Config.VIEW_SIZE.y - Config.HUD_BOTTOM_PX - 360.0)
	_roster_popup.custom_minimum_size = Vector2(560, 352)
	_apply_panel_style(_roster_popup)
	_roster_popup.visible = false
	_roster_popup.z_index = 40
	add_child(_roster_popup)
	_roster_body = VBoxContainer.new()
	_roster_body.add_theme_constant_override("separation", 6)
	_roster_popup.add_child(_roster_body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_roster_body.add_child(head)
	var title := _mk_label(14, COL_GOLD)
	title.name = "RosterTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_btn_roster_close = Button.new()
	_btn_roster_close.custom_minimum_size = Vector2(72, 28)
	_btn_roster_close.add_theme_font_size_override("font_size", 12)
	_btn_roster_close.pressed.connect(_close_roster)
	head.add_child(_btn_roster_close)

func _toggle_roster(mode: String) -> void:
	if _roster_open and _right_mode == mode:
		_close_roster()
		return
	_open_roster(mode)

func _open_roster(mode: String) -> void:
	_right_mode = mode
	_roster_open = true
	if _roster_popup != null:
		_roster_popup.visible = true
	_apply_right_mode()
	_refresh_roster_title()

func _close_roster() -> void:
	_roster_open = false
	if _roster_popup != null:
		_roster_popup.visible = false
	if _shop_panel != null:
		_shop_panel.visible = false
	if tech_panel != null:
		tech_panel.visible = false
	_apply_open_button_state()

func _refresh_roster_title() -> void:
	if _roster_body == null:
		return
	for child in _roster_body.get_children():
		if child is HBoxContainer:
			for c in child.get_children():
				if c is Label and c.name == "RosterTitle":
					if _right_mode == "tech":
						c.text = _t("hud_tech", "科研")
					else:
						c.text = _t("hud_shop", "部署")
	if _btn_roster_close != null:
		_btn_roster_close.text = _t("hud_close", "关闭")

func _apply_open_button_state() -> void:
	if _tab_build != null:
		_tab_build.disabled = _roster_open and _right_mode == "build"
	if _tab_tech != null:
		var human_ok: bool = (_race == "human" and _human_tech != null)
		_tab_tech.visible = human_ok
		_tab_tech.disabled = human_ok and _roster_open and _right_mode == "tech"

func _apply_right_mode() -> void:
	var show_tech := (_right_mode == "tech")
	if not _roster_open:
		if _shop_panel != null:
			_shop_panel.visible = false
		if tech_panel != null:
			tech_panel.visible = false
		_apply_open_button_state()
		return
	if _shop_panel != null:
		_shop_panel.visible = not show_tech
	if _shop_grid != null:
		_shop_grid.visible = not show_tech
	if tech_panel != null:
		tech_panel.visible = show_tech and _race == "human"
	_apply_open_button_state()
	_refresh_roster_title()
	if show_tech:
		_refresh_tech_buttons()

# ---------- 弹层内：建造格 ----------
func _build_unit_panel() -> void:
	_rebuild_unit_panel()

func _rebuild_unit_panel() -> void:
	for b in unit_buttons:
		if is_instance_valid(b):
			b.queue_free()
	unit_buttons.clear()
	if _shop_panel != null and is_instance_valid(_shop_panel):
		_shop_panel.queue_free()
		_shop_panel = null
	var parent: Control = _roster_body if _roster_body != null else _right_body
	if parent == null:
		return
	_shop_panel = VBoxContainer.new()
	_shop_panel.add_theme_constant_override("separation", 4)
	_shop_panel.visible = false
	parent.add_child(_shop_panel)
	var title := _mk_label(12, COL_MUTED)
	title.text = _t("hud_shop_hint", "点选单位后在地图放置")
	title.name = "ShopTitle"
	_shop_panel.add_child(title)
	_shop_grid = GridContainer.new()
	_shop_grid.columns = 2
	_shop_grid.add_theme_constant_override("h_separation", 6)
	_shop_grid.add_theme_constant_override("v_separation", 6)
	_shop_panel.add_child(_shop_grid)
	for u in Config.shop_units(_race):
		var b := Button.new()
		_style_shop_button(b)
		b.custom_minimum_size = Vector2(250, 36)
		b.add_theme_font_size_override("font_size", 13)
		b.text = "%s $%d" % [tr(u["name_key"]), int(u["cost"])]
		var uid := int(u["id"])
		b.pressed.connect(func() -> void:
			buy_requested.emit(uid)
			_close_roster()
		)
		_shop_grid.add_child(b)
		unit_buttons.append(b)
	_apply_right_mode()

# ---------- 弹层内：科研列表 ----------
func _build_tech_panel() -> void:
	tech_panel = VBoxContainer.new()
	tech_panel.add_theme_constant_override("separation", 4)
	tech_panel.visible = false
	var parent: Control = _roster_body if _roster_body != null else _right_body
	if parent != null:
		parent.add_child(tech_panel)
	else:
		add_child(tech_panel)
	_tech_box = tech_panel
	var title := _mk_label(12, COL_MUTED)
	title.name = "TechTitle"
	title.text = _t("hud_tech_hint", "点大本营也可打开科研")
	tech_panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tech_panel.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for tid in ["infantry", "archery", "logistics", "siege", "arcane", "chapel", "arbalest"]:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 12)
		_style_shop_button(b)
		b.custom_minimum_size = Vector2(500, 30)
		var id_capture: String = tid
		b.pressed.connect(func() -> void: tech_requested.emit(id_capture))
		list.add_child(b)
		tech_buttons.append({"id": tid, "btn": b})

func _refresh_tech_buttons() -> void:
	if tech_panel == null:
		return
	var human_ok: bool = (_race == "human" and _human_tech != null)
	_apply_open_button_state()
	if not human_ok and _right_mode == "tech":
		_right_mode = "build"
		if _roster_open:
			_apply_right_mode()
	# 点大本营：打开科研弹层
	if _hq_selected and human_ok and _roster_open and _right_mode == "tech":
		pass
	elif _hq_selected and human_ok and not _roster_open:
		_open_roster("tech")
		return
	if not _roster_open or _right_mode != "tech" or not human_ok:
		if tech_panel != null:
			tech_panel.visible = false
		return
	tech_panel.visible = true
	for child in tech_panel.get_children():
		if child is Label and child.name == "TechTitle":
			child.text = _t("hud_tech_hint", "点大本营也可打开科研")
	for entry in tech_buttons:
		var tid: String = str(entry["id"])
		var b: Button = entry["btn"]
		if _human_tech == null or not _human_tech.TECH_DEFS.has(tid):
			b.visible = false
			continue
		b.visible = true
		var def: Dictionary = _human_tech.TECH_DEFS[tid]
		var name_s: String = tr(str(def["name_key"]))
		var lv: int = int(_human_tech.tech_level_of(tid)) if _human_tech.has_method("tech_level_of") else 0
		var mx: int = int(_human_tech.tech_max_level(tid)) if _human_tech.has_method("tech_max_level") else 1
		if lv >= mx:
			b.text = "✓ %s  Lv%d/%d" % [name_s, lv, mx]
			b.disabled = true
		else:
			var nd: Dictionary = {}
			if _human_tech.has_method("next_level_def"):
				nd = _human_tech.next_level_def(tid)
			var cost: int = int(nd.get("cost", 0))
			var need_w: int = int(nd.get("min_wave", 0))
			b.text = "%s  Lv%d→%d  $%d  W%d+" % [name_s, lv, lv + 1, cost, need_w]
			b.disabled = _placing

# ---------- 底中：选中角色栏（Dota 英雄栏位）----------
func _build_hero_and_actions() -> void:
	_hero_panel = PanelContainer.new()
	_hero_panel.position = Vector2(180, _dock_top_y() + 4.0)
	_hero_panel.custom_minimum_size = Vector2(820, Config.HUD_BOTTOM_PX - 8.0)
	_apply_panel_style(_hero_panel)
	add_child(_hero_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_hero_panel.add_child(box)
	info_panel = _hero_panel
	info_title = _mk_label(12, COL_WHITE)
	info_title.text = tr("hud_select_hint")
	box.add_child(info_title)
	info_stats = _mk_label(11, COL_MUTED)
	info_stats.text = ""
	info_stats.visible = false
	info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_stats.custom_minimum_size = Vector2(780, 22)
	box.add_child(info_stats)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	box.add_child(hb)
	evolve_button = Button.new()
	evolve_button.custom_minimum_size = Vector2(110, 26)
	evolve_button.add_theme_font_size_override("font_size", 11)
	evolve_button.pressed.connect(func() -> void: evolve_requested.emit())
	hb.add_child(evolve_button)
	sell_button = Button.new()
	sell_button.custom_minimum_size = Vector2(72, 26)
	sell_button.add_theme_font_size_override("font_size", 11)
	sell_button.pressed.connect(func() -> void: sell_requested.emit())
	hb.add_child(sell_button)
	split_button = Button.new()
	split_button.custom_minimum_size = Vector2(64, 26)
	split_button.add_theme_font_size_override("font_size", 11)
	split_button.pressed.connect(func() -> void: split_requested.emit())
	hb.add_child(split_button)
	split_button.visible = false
	skill_button = Button.new()
	skill_button.custom_minimum_size = Vector2(160, 26)
	skill_button.clip_text = false
	skill_button.add_theme_font_size_override("font_size", 11)
	_style_primary_button(skill_button)
	skill_button.pressed.connect(func() -> void: skill_requested.emit())
	hb.add_child(skill_button)
	evolve_button.disabled = true
	sell_button.disabled = true
	_hero_panel.visible = true
	evolve_button.modulate = Color(1, 1, 1, 0.45)
	sell_button.modulate = Color(1, 1, 1, 0.45)

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
	overlay_title = _mk_label(46, COL_WHITE)
	vbox.add_child(overlay_title)
	overlay_sub = _mk_label(20, COL_MUTED)
	vbox.add_child(overlay_sub)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(180, 46)
	overlay_button.add_theme_font_size_override("font_size", 17)
	_style_primary_button(overlay_button)
	overlay_button.pressed.connect(func() -> void: restart_requested.emit())
	vbox.add_child(overlay_button)

func refresh_texts() -> void:
	money_label.text = tr("hud_money") % _money
	if supply_label != null:
		supply_label.text = tr("hud_supply") % [_supply, Config.MAX_SUPPLY]
		supply_label.visible = (_race == "human")
	lives_label.text = tr("hud_lives") % _lives
	losses_label.text = tr("hud_lost") % _losses
	wave_label.text = tr("hud_wave") % [_wave, Config.TOTAL_WAVES]
	_refresh_nest_labels()
	start_button.text = tr("hud_start")
	menu_button.text = tr("hud_menu")
	if _tab_build != null:
		_tab_build.text = _t("hud_shop", "部署")
	if _tab_tech != null:
		_tab_tech.text = _t("hud_tech", "科研")
	if _btn_roster_close != null:
		_btn_roster_close.text = _t("hud_close", "关闭")
	_refresh_roster_title()
	if _minimap != null and _minimap.get_parent() != null:
		for child in _minimap.get_parent().get_children():
			if child is Label and child.name == "MinimapTitle":
				child.text = _t("hud_minimap", "小地图")
	if _shop_panel != null:
		for child in _shop_panel.get_children():
			if child is Label and child.name == "ShopTitle":
				child.text = _t("hud_shop_hint", "点选单位后在地图放置")
	for i in range(unit_buttons.size()):
		if i >= Config.shop_units(_race).size():
			break
		var u: Dictionary = Config.shop_units(_race)[i]
		var sc: int = Config.supply_cost(u) if _race == "human" else 0
		if sc > 0:
			unit_buttons[i].text = "%s $%d·%d" % [tr(u["name_key"]), int(u["cost"]), sc]
		else:
			unit_buttons[i].text = "%s $%d" % [tr(u["name_key"]), int(u["cost"])]
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
	_refresh_tech_buttons()

func _ev_text() -> String:
	if _last_can_evolve:
		if not _last_next_rank.is_empty():
			return tr("hud_evolve_to") % [_last_next_rank, _last_ev_cost]
		return tr("hud_evolve_cost") % _last_ev_cost
	return tr("hud_evolve_max")

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
	_refresh_tech_buttons()

func set_status(s: String) -> void:
	status_label.text = s

var _placing_name := ""

func _t(key: String, fallback: String = "") -> String:
	var s: String = tr(key)
	if s == key or s.is_empty():
		return fallback if not fallback.is_empty() else key
	return s

func set_placing(b: bool, unit_name: String = "") -> void:
	_placing = b
	_placing_name = unit_name if b else ""
	refresh_unit_buttons()
	_refresh_select_idle()

func _refresh_select_idle() -> void:
	# 无选中 / 放置态：不要显示「军衔已满」「出售$0」
	if info_title == null:
		return
	if _placing and not _placing_name.is_empty():
		info_title.text = _t("hud_placing_panel", "正在召唤：%s · 左键放置 · 右键/ESC 取消") % _placing_name
		if info_stats != null:
			info_stats.visible = false
		if evolve_button != null:
			evolve_button.visible = false
		if sell_button != null:
			sell_button.visible = false
		if split_button != null:
			split_button.visible = false
		return
	info_title.text = _t("hud_select_hint", "选中士兵 · 右键空地派往 · 右键怪/怪堆进攻 · 点大本营开科研")
	if info_stats != null:
		info_stats.text = _t("hud_select_empty", "未选中单位")
		info_stats.visible = true
	if evolve_button != null:
		evolve_button.visible = false
	if sell_button != null:
		sell_button.visible = false
	if split_button != null:
		split_button.visible = false

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
	if nest_label != null:
		nest_label.visible = (_race == "dragon")
	if egg_label != null and _race != "dragon":
		egg_label.visible = false
	if supply_label != null:
		supply_label.visible = (_race == "human")
	_hq_selected = false
	if tech_panel != null:
		tech_panel.visible = false
	_rebuild_unit_panel()
	refresh_texts()
	_refresh_tech_buttons()
	refresh_unit_buttons()

func set_run_items(names: Array) -> void:
	if items_label == null:
		return
	if names.is_empty():
		items_label.text = ""
		return
	items_label.text = tr("hud_items") % ", ".join(PackedStringArray(names))

func set_crystal(v: int) -> void:
	_crystal = v
	crystal_label.text = tr("hud_crystal") % v
	_refresh_skill_button()

func set_nest(used: int, max_n: int) -> void:
	_nest_used = used
	_nest_max = max_n
	_refresh_nest_labels()

func set_eggs(count: int, shortest_sec: int) -> void:
	_egg_count = count
	_egg_sec = maxi(0, shortest_sec)
	_refresh_nest_labels()

func _refresh_nest_labels() -> void:
	if nest_label == null:
		return
	var is_dragon := (_race == "dragon")
	nest_label.visible = is_dragon
	if is_dragon:
		nest_label.text = tr("hud_dragon_nest") % [_nest_used, _nest_max]
	if egg_label == null:
		return
	if is_dragon and _egg_count > 0:
		egg_label.visible = true
		egg_label.text = tr("hud_dragon_eggs") % [_egg_count, _egg_sec]
	else:
		egg_label.visible = false
		egg_label.text = ""

func _skill_cd_waves() -> int:
	var sk: Dictionary = Config.RACES[_race]["active_skill"]
	return int(sk.get("cd_waves", sk.get("carpet_fever_cd_waves", 99)))

func _refresh_skill_button() -> void:
	if skill_button == null:
		return
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
		var u: Dictionary = units[i]
		var sc: int = Config.supply_cost(u) if _race == "human" else 0
		var unlocked := true
		if _race == "human" and _human_tech != null and _human_tech.has_method("is_unit_unlocked"):
			unlocked = bool(_human_tech.is_unit_unlocked(int(u["id"])))
		var can_buy := unlocked and (not _placing) and _money >= int(u["cost"]) and _supply >= sc
		unit_buttons[i].disabled = not can_buy
		var label: String
		if sc > 0:
			label = "%s $%d·%d" % [tr(u["name_key"]), int(u["cost"]), sc]
		else:
			label = "%s $%d" % [tr(u["name_key"]), int(u["cost"])]
		if not unlocked:
			label = "🔒 " + label
		unit_buttons[i].text = label
	_refresh_tech_buttons()

func show_info(title: String, stats: String, ev_cost: int, sell_val: int, can_evolve: bool, can_split: bool = false) -> void:
	show_info_ranked(title, stats, ev_cost, sell_val, can_evolve, can_split, "")

func show_info_ranked(title: String, stats: String, ev_cost: int, sell_val: int, can_evolve: bool, can_split: bool, next_rank: String) -> void:
	info_title.text = title
	info_stats.text = stats
	info_stats.visible = not stats.is_empty()
	_last_ev_cost = ev_cost
	_last_can_evolve = can_evolve
	_last_can_split = can_split
	_last_sell_val = sell_val
	_last_next_rank = next_rank
	evolve_button.visible = true
	sell_button.visible = true
	evolve_button.text = _ev_text()
	evolve_button.disabled = not can_evolve
	evolve_button.modulate = Color.WHITE
	sell_button.text = tr("hud_sell_cost") % sell_val
	sell_button.disabled = false
	sell_button.modulate = Color.WHITE
	split_button.visible = can_split
	split_button.disabled = not can_split
	_hero_panel.visible = true

func show_enemy_info(title: String, stats: String) -> void:
	info_title.text = title
	info_stats.text = stats
	info_stats.visible = not stats.is_empty()
	_last_can_evolve = false
	_last_next_rank = ""
	evolve_button.visible = false
	sell_button.visible = false
	split_button.visible = false
	_hero_panel.visible = true

func hide_info() -> void:
	_last_can_evolve = false
	_last_next_rank = ""
	_last_sell_val = 0
	_refresh_select_idle()
	if _hero_panel != null:
		_hero_panel.visible = true

func set_speed_text(t: String) -> void:
	_speed_is_2x = (t == tr("hud_speed_2x") or t.find("2") >= 0)
	if speed_button != null:
		speed_button.text = t

func set_speed_label(is_2x: bool) -> void:
	_speed_is_2x = is_2x
	if speed_button != null:
		speed_button.text = tr("hud_speed_2x") if is_2x else tr("hud_speed_1x")

func show_overlay(title: String, sub: String) -> void:
	overlay_title.text = title
	overlay_sub.text = sub
	overlay_button.text = tr("hud_restart")
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

func hide_overlay() -> void:
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
