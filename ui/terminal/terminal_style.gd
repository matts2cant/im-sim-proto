class_name TerminalStyle
extends RefCounted
## Colours and small widget helpers shared by the terminal screen and its network graph (ADR 0083).
## Status colours depend on the words only (DeviceStatus), never on what the device is.

const TITLE_COLOR: Color = Color(0.55, 0.95, 0.85)
const TEXT_COLOR: Color = Color(0.82, 0.95, 0.9)
const DIM_COLOR: Color = Color(0.5, 0.66, 0.64)
const ONLINE_COLOR: Color = Color(0.45, 0.95, 0.6)
const OFFLINE_COLOR: Color = Color(0.42, 0.45, 0.45)
const ALERT_COLOR: Color = Color(1.0, 0.42, 0.32)
const SELF_COLOR: Color = Color(0.45, 0.85, 1.0)
const ERROR_COLOR: Color = Color(0.95, 0.4, 0.35)
const PANEL_COLOR: Color = Color(0.03, 0.07, 0.07, 1.0)
const BORDER_COLOR: Color = Color(0.3, 0.75, 0.66, 0.9)
## Status words that mean something is happening right now: shown in the alert colour.
const ALERT_WORDS: Array[String] = ["alert", "suspicious", "tracking", "firing", "ringing", "broadcasting"]


## The colour of a device with status `words` (DeviceStatus): offline grey, alert words red, else
## green.
static func status_color(words: PackedStringArray) -> Color:
	if words.has(DeviceStatus.OFFLINE):
		return OFFLINE_COLOR
	for word in words:
		if ALERT_WORDS.has(word):
			return ALERT_COLOR
	return ONLINE_COLOR


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
