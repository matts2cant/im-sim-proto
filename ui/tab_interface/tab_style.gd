class_name TabStyle
extends RefCounted
## Look of the Tab interface (ADR 0110): the palette of the inventory view, belt, HUD and energy
## colours (design/prototypes/tab_interface.html) and small builders for its labels, captions,
## buttons and boxes. Pages build their content in code with these.

const PANEL := Color(13.0 / 255.0, 18.0 / 255.0, 21.0 / 255.0, 0.94)
const PANEL_2 := Color("12191d")
const CELL := Color("0f1417")
const LINE := Color(140.0 / 255.0, 158.0 / 255.0, 168.0 / 255.0, 0.35)
const LINE_STRONG := Color(140.0 / 255.0, 158.0 / 255.0, 168.0 / 255.0, 0.6)
const FG := Color("e4eaee")
const CAPTION := Color("9eb8c2")
const DIM := Color("66808a")
const AMBER := Color("ffd14d")
const ENERGY := Color("4dbfff")
const OK := Color("4fd36a")
const WARN := Color("e8c547")
const BAD := Color("e5534b")
## The world behind the panel, dimmed but visible.
const WORLD_DIM := Color(4.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, 0.55)

static var _mono: SystemFont = null


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(
			["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"]
		)
	return _mono


static func label(text: String, size: int = 14, colour: Color = FG) -> Label:
	var node := Label.new()
	node.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = colour
	node.label_settings = settings
	return node


## A label in the monospace font (codes, numbers).
static func mono(text: String, size: int = 13, colour: Color = FG) -> Label:
	var node := label(text, size, colour)
	node.label_settings.font = mono_font()
	return node


## A wrapping paragraph.
static func paragraph(text: String, size: int = 14, colour: Color = CAPTION) -> Label:
	var node := label(text, size, colour)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(120, 0)
	return node


## An uppercase section caption ("DETAILS").
static func caption(text: String) -> Label:
	var node := mono(text.to_upper(), 11, CAPTION)
	node.name = "Caption"
	return node


static func box(bg: Color, border: Color, width: int = 1, radius: int = 4, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## A dashed-looking box for what comes in a later milestone ("Money arrives in M19.").
static func future(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Future"
	var style := box(Color(0, 0, 0, 0), LINE, 1, 4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override(&"panel", style)
	var text_label := paragraph(text, 12, DIM)
	text_label.name = "Text"
	panel.add_child(text_label)
	return panel


## A small button in the panel's style; `primary` draws it amber. Never takes keyboard focus (Space
## and Enter are the player's keys).
static func button(text: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override(&"font_size", 13)
	var colour := AMBER if primary else FG
	node.add_theme_color_override(&"font_color", colour)
	node.add_theme_color_override(&"font_hover_color", AMBER)
	node.add_theme_color_override(&"font_pressed_color", AMBER)
	node.add_theme_color_override(&"font_disabled_color", Color(FG, 0.45))
	var normal := box(PANEL_2, AMBER if primary else LINE_STRONG, 1, 4)
	_pad(normal, 12.0, 7.0)
	var hover := box(PANEL_2, AMBER, 1, 4)
	_pad(hover, 12.0, 7.0)
	var disabled := box(Color(PANEL_2, 0.5), LINE, 1, 4)
	_pad(disabled, 12.0, 7.0)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", hover)
	node.add_theme_stylebox_override(&"pressed", hover)
	node.add_theme_stylebox_override(&"disabled", disabled)
	return node


## A list row button (left-aligned, transparent; amber border when `on`).
static func row_button(text: String, on: bool) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override(&"font_size", 13)
	style_row_button(node, on)
	return node


## (Re)styles a row_button() as on (selected) or off.
static func style_row_button(node: Button, on: bool) -> void:
	node.add_theme_color_override(&"font_color", FG if on else CAPTION)
	node.add_theme_color_override(&"font_hover_color", FG)
	node.add_theme_color_override(&"font_pressed_color", FG)
	var normal := box(Color(AMBER, 0.05) if on else Color(0, 0, 0, 0), AMBER if on else Color(0, 0, 0, 0), 1, 4)
	_pad(normal, 10.0, 8.0)
	var hover := box(Color(AMBER, 0.05) if on else Color(0, 0, 0, 0), AMBER if on else LINE, 1, 4)
	_pad(hover, 10.0, 8.0)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", hover)
	node.add_theme_stylebox_override(&"pressed", hover)


## A scrolling column with the panel's padding; returns the VBox to fill.
static func column(min_width: float = 0.0) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(min_width, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(side, 20)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	scroll.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "Box"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override(&"separation", 8)
	margin.add_child(vbox)
	return scroll


## The VBox inside a column().
static func column_box(scroll: ScrollContainer) -> VBoxContainer:
	return scroll.get_node(^"Margin/Box") as VBoxContainer


## A 1 px vertical line between columns.
static func divider() -> ColorRect:
	var line := ColorRect.new()
	line.name = "Divider"
	line.color = LINE
	line.custom_minimum_size = Vector2(1, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## Frees every child of `node` now (pages rebuild their content).
static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _pad(style: StyleBoxFlat, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
