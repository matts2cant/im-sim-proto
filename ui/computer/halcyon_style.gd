class_name HalcyonStyle
extends RefCounted
## Look of the Halcyon OS overlay (ADR 0114, design/prototypes/hacking_screens.html): the teal
## screen palette inside the Tab interface's frame, and small builders for its labels, buttons and
## boxes. Status colours depend on what a device reports (DeviceStatus words and its disabled flag),
## never on what it is: offline grey, disabled red, alert words amber, else green.

const OS_BG := Color("071211")
const OS_PANEL := Color("0b1a19")
const LINE := Color(77.0 / 255.0, 191.0 / 255.0, 168.0 / 255.0, 0.45)
const FIELD_BG := Color("031010")
const BUTTON_BG := Color("0c2220")
const SELECTED_BG := Color(140.0 / 255.0, 242.0 / 255.0, 217.0 / 255.0, 0.06)
const REMOTE_BAR := Color("08201d")
const TEAL := Color("8cf2d9")
const TEXT := Color("d1f2e6")
const DIM := Color("7fa8a3")
const ONLINE := Color("73f299")
const OFFLINE := Color("575c5c")
const ALERT := Color("ffb840")
const BAD := Color("e5534b")
const AMBER := Color("ffd14d")
const SELF := Color("73d9ff")
## Status words that mean something is happening right now: shown in the alert colour.
const ALERT_WORDS: Array[String] = ["alert", "suspicious", "tracking", "firing", "ringing", "broadcasting"]


## The colour of a device with status `words` (DeviceStatus) that is `disabled` or not: offline grey
## (an unreachable device's state is unknown), disabled red, alert words amber, else green.
static func status_color(words: PackedStringArray, disabled: bool = false) -> Color:
	if words.has(DeviceStatus.OFFLINE):
		return OFFLINE
	if disabled:
		return BAD
	for word in words:
		if ALERT_WORDS.has(word):
			return ALERT
	return ONLINE


## The words joined for display ("online · enabled · sweeping").
static func status_text(words: PackedStringArray) -> String:
	return " · ".join(words)


## A list row's short status: "offline", else the words after "online" ("online" when none).
static func short_status(words: PackedStringArray) -> String:
	if words.has(DeviceStatus.OFFLINE):
		return DeviceStatus.OFFLINE
	var rest := PackedStringArray()
	for word in words:
		if word != DeviceStatus.ONLINE:
			rest.append(word)
	return status_text(rest) if not rest.is_empty() else DeviceStatus.ONLINE


static func label(text: String, size: int = 14, colour: Color = TEXT, mono: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	var settings := LabelSettings.new()
	settings.font_size = size
	settings.font_color = colour
	if mono:
		settings.font = TabStyle.mono_font()
	node.label_settings = settings
	return node


## A wrapping paragraph.
static func paragraph(text: String, size: int = 14, colour: Color = TEXT) -> Label:
	var node := label(text, size, colour)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(120, 0)
	return node


## An uppercase caption ("INBOX").
static func caption(text: String) -> Label:
	return label(text.to_upper(), 11, DIM, true)


static func box(bg: Color, border: Color, width: int = 1, radius: int = 4, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## A button that never takes keyboard focus (Esc and typing stay with the screen). `danger`: red
## on hover.
static func button(text: String, primary: bool = false, danger: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override(&"font_size", 13)
	var border := TEAL if primary else LINE
	var normal := box(BUTTON_BG, border, 1, 4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = BAD if danger else TEAL
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", hover)
	node.add_theme_stylebox_override(&"pressed", hover)
	node.add_theme_stylebox_override(&"disabled", normal)
	node.add_theme_color_override(&"font_color", TEAL if primary else TEXT)
	node.add_theme_color_override(&"font_hover_color", BAD if danger else TEAL)
	node.add_theme_color_override(&"font_pressed_color", TEAL)
	return node


## A flat list entry (Mail, Files, Security lists): a toggle with a teal border when selected.
static func list_entry(text: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.toggle_mode = true
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override(&"font_size", 13)
	var normal := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 4, 8)
	var hover := box(Color(0, 0, 0, 0), LINE, 1, 4, 8)
	var chosen := box(SELECTED_BG, TEAL, 1, 4, 8)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"hover", hover)
	node.add_theme_stylebox_override(&"pressed", chosen)
	node.add_theme_stylebox_override(&"hover_pressed", chosen)
	node.add_theme_color_override(&"font_color", TEXT)
	node.add_theme_color_override(&"font_hover_color", TEXT)
	node.add_theme_color_override(&"font_pressed_color", TEXT)
	node.add_theme_color_override(&"font_hover_pressed_color", TEXT)
	return node


## A text field.
static func field(secret: bool) -> LineEdit:
	var node := LineEdit.new()
	node.secret = secret
	node.custom_minimum_size = Vector2(260, 0)
	node.add_theme_font_override(&"font", TabStyle.mono_font())
	node.add_theme_font_size_override(&"font_size", 14)
	node.add_theme_color_override(&"font_color", TEXT)
	var normal := box(FIELD_BG, LINE, 1, 4, 8)
	var focused := box(FIELD_BG, TEAL, 1, 4, 8)
	node.add_theme_stylebox_override(&"normal", normal)
	node.add_theme_stylebox_override(&"focus", focused)
	return node


## A 1 px line (vertical when `vertical`).
static func rule(vertical: bool = false) -> ColorRect:
	var node := ColorRect.new()
	node.color = LINE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	return node


## Drops `node` from a rebuilt list: hidden at once and freed at the end of the frame, but left in
## the tree until then (safe inside its own `pressed` signal).
static func discard(node: Node) -> void:
	var item := node as CanvasItem
	if item != null:
		item.visible = false
	node.queue_free()
