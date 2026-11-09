class_name TerminalStyle
extends RefCounted
## Colours and small widget helpers shared by the terminal screen and its network graph (ADR 0083).
## Status colours depend on what the device reports (DeviceStatus words and its disabled flag), never
## on what the device is. Offline grey, disabled red and the default green differ in brightness too
## (relative luminance about 0.1, 0.3 and 0.7), so they stay apart without hue.

const TITLE_COLOR: Color = Color(0.55, 0.95, 0.85)
const TEXT_COLOR: Color = Color(0.82, 0.95, 0.9)
const DIM_COLOR: Color = Color(0.5, 0.66, 0.64)
## Online and not disabled (#73F299).
const ONLINE_COLOR: Color = Color(0.45, 0.95, 0.6)
## The terminal cannot reach it: unpowered, broken or cut off (#575C5C).
const OFFLINE_COLOR: Color = Color(0.34, 0.36, 0.36)
## Online and switched off by a command (#FF6157).
const DISABLED_COLOR: Color = Color(1.0, 0.38, 0.34)
## Online, enabled and doing something right now (#FFB840).
const ALERT_COLOR: Color = Color(1.0, 0.72, 0.25)
const SELF_COLOR: Color = Color(0.45, 0.85, 1.0)
const ERROR_COLOR: Color = Color(0.95, 0.4, 0.35)
const PANEL_COLOR: Color = Color(0.03, 0.07, 0.07, 1.0)
const BORDER_COLOR: Color = Color(0.3, 0.75, 0.66, 0.9)
## Status words that mean something is happening right now: shown in the alert colour (amber: red
## means disabled).
const ALERT_WORDS: Array[String] = ["alert", "suspicious", "tracking", "firing", "ringing", "broadcasting"]


## The colour of a device with status `words` (DeviceStatus) that is `disabled` or not: offline
## grey (beats disabled: an unreachable device's state is unknown), disabled red, alert words amber,
## else green.
static func status_color(words: PackedStringArray, disabled: bool = false) -> Color:
	if words.has(DeviceStatus.OFFLINE):
		return OFFLINE_COLOR
	if disabled:
		return DISABLED_COLOR
	for word in words:
		if ALERT_WORDS.has(word):
			return ALERT_COLOR
	return ONLINE_COLOR


## The colour of a terminal row (Terminal.devices()): status_color() of its words and flag.
static func row_color(row: Terminal.Row) -> Color:
	return status_color(row.status, row.disabled)


## The words joined for display ("online · enabled · sweeping").
static func status_text(words: PackedStringArray) -> String:
	return " · ".join(words)


## Drops `node` from a rebuilt list: hidden at once and freed at the end of the frame, but left in
## the tree until then (safe inside its own `pressed` signal, and never an orphan).
static func discard(node: Node) -> void:
	var item := node as CanvasItem
	if item != null:
		item.visible = false
	node.queue_free()


static func label(text: String, color: Color, font_size: int = 15) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override(&"font_color", color)
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


## A button that never takes keyboard focus (Esc and typing stay with the screen).
static func button(text: String, font_size: int = 15) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


static func panel_style(border: Color = BORDER_COLOR, width: int = 1, margin: float = 22.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style
