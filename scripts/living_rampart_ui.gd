# CO-ART-PROD-001 W2：统一 Living Rampart UI Theme（程序 StyleBox，零外部 UI 包）
# 色板对齐 VISUAL_DESIGN：蓝灰钢 + 锈战场底；禁默认紫/霓虹。
extends RefCounted

const STEEL := Color("6B82B8")
const STEEL_DEEP := Color("4D6AA8")
const STEEL_DARK := Color(0.08, 0.10, 0.14, 0.92)
const STEEL_BORDER := Color(0.42, 0.52, 0.72, 0.95)
const GOLD := Color("FFDC50")
const MUTED := Color(0.78, 0.80, 0.86)
const WHITE := Color(0.94, 0.95, 0.97)
const DANGER := Color("BF4A2F")
const SUPPLY := Color(0.43, 0.72, 0.45)

static func build() -> Theme:
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", _panel())
	t.set_stylebox("normal", "Button", _btn(STEEL_DARK, STEEL_BORDER))
	t.set_stylebox("hover", "Button", _btn(Color(0.14, 0.18, 0.26, 0.96), STEEL))
	t.set_stylebox("pressed", "Button", _btn(STEEL_DEEP, GOLD))
	t.set_stylebox("disabled", "Button", _btn(Color(0.12, 0.12, 0.14, 0.75), Color(0.35, 0.35, 0.4, 0.6)))
	t.set_stylebox("focus", "Button", _btn(Color(0.14, 0.18, 0.26, 0.96), GOLD))
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.58))
	t.set_font_size("font_size", "Button", 14)
	t.set_font_size("font_size", "Label", 14)
	t.set_color("font_color", "Label", MUTED)
	t.set_constant("h_separation", "HBoxContainer", 8)
	t.set_constant("v_separation", "VBoxContainer", 6)
	return t

static func apply_to_tree(root: Node) -> void:
	var theme := build()
	_apply_recursive(root, theme)

static func _apply_recursive(n: Node, theme: Theme) -> void:
	if n is Control:
		(n as Control).theme = theme
	for c in n.get_children():
		_apply_recursive(c, theme)

static func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = STEEL_DARK
	sb.border_color = STEEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

static func shop_slot() -> StyleBoxFlat:
	var sb := _btn(Color(0.10, 0.12, 0.18, 0.95), STEEL_BORDER)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
