class_name TabStyle
extends RefCounted
## Look of the Tab interface (ADR 0110): the palette of the inventory view, belt, HUD and energy
## colours (design/prototypes/tab_interface.html) and small builders for its labels, captions,
## buttons and boxes. Pages build their content in code with these. Panel and button styles are
## type variations of tab_theme.tres (TabButton, TabRow, TabFuture, TabPanel, ...; also the
## character pages' Character*): themed() gives a control the theme and a variation, style() reads
## one style. No style is built in code.

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
## A keycard's icon on the keychain (KeyIcon).
const CARD := Color("73d9ff")
## The world behind the panel, dimmed but visible.
const WORLD_DIM := Color(4.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, 0.55)
## The Tab interface's type variations.
const THEME: Theme = preload("res://ui/tab_interface/tab_theme.tres")

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
	style_label(node, size, colour)
	return node


## Gives `node` (any Label: a TimedLabel status line) the look of label().
static func style_label(node: Label, size: int = 14, colour: Color = FG) -> void:
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = colour
	node.label_settings = settings


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


## Gives `control` the Tab theme and its type variation `type` (tab_theme.tres).
static func themed(control: Control, type: StringName) -> void:
	control.theme = THEME
	control.theme_type_variation = type


## The style `item` ("panel", "normal"...) of type variation `type` in tab_theme.tres.
static func style(type: StringName, item: StringName = &"panel") -> StyleBox:
	return THEME.get_stylebox(item, type)


## A dashed-looking box for what comes in a later milestone ("Money arrives in M19.").
static func future(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Future"
	themed(panel, &"TabFuture")
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
	themed(node, &"TabButtonPrimary" if primary else &"TabButton")
	return node


## A list row button (left-aligned, transparent; amber border when `on`).
static func row_button(text: String, on: bool) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_row_button(node, on)
	return node


## (Re)styles a row_button() as on (selected) or off.
static func style_row_button(node: Button, on: bool) -> void:
	themed(node, &"TabRowOn" if on else &"TabRow")


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
