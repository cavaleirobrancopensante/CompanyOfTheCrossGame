class_name UI
extends RefCounted
## Small helpers to build big, thumb-friendly UI in code.

const BG := Color(0.105, 0.09, 0.07)
const PANEL := Color(0.17, 0.145, 0.11)
const PARCHMENT := Color(0.91, 0.86, 0.75)
const GOLD := Color(0.79, 0.64, 0.29)
const RED := Color(0.55, 0.12, 0.12)
const DIM := Color(0.65, 0.6, 0.5)
const GOOD := Color(0.55, 0.8, 0.5)
const BAD := Color(0.9, 0.45, 0.4)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var normal := _box(Color(0.26, 0.2, 0.13), GOLD.darkened(0.3))
	var hover := _box(Color(0.32, 0.25, 0.16), GOLD)
	var pressed := _box(RED, GOLD)
	var disabled := _box(Color(0.18, 0.16, 0.13), Color(0.3, 0.28, 0.24))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.42, 0.36))
	t.set_color("font_color", "Label", PARCHMENT)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.border_color = GOLD.darkened(0.45)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.set_content_margin_all(14)
	t.set_stylebox("panel", "PanelContainer", panel)
	var scroll_bg := StyleBoxEmpty.new()
	t.set_stylebox("panel", "ScrollContainer", scroll_bg)
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(2)
	b.set_corner_radius_all(10)
	b.content_margin_left = 16
	b.content_margin_right = 16
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	return b


static func button(text: String, cb: Callable, min_h: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


static func label(text: String, font_size: int = 26, color: Color = PARCHMENT, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


## A full-screen margin + scroll + vbox page; returns the vbox to fill.
static func page(parent: Control) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	m.add_theme_constant_override("margin_top", 40)
	parent.add_child(m)
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(s)
	var v := vbox(14)
	s.add_child(v)
	return v


static func status_line() -> String:
	return "Day %d   Gold %d   Food %d (-%d/d)\nMen %d (+%d wounded)   Morale %d   Faith %d" % [
		Game.day, Game.gold, Game.food, Game.daily_food(), Game.total_men(), Game.total_wounded(),
		Game.morale, Game.faith]
