class_name DeckStyle
extends RefCounted
## Colours and small widget helpers of the deck's screens and its network map (ADR 0113), from the
## approved mockup (design/prototypes/hacking_screens.html): the terminal's teal on a dark panel.
## Status colours depend on what a device reports (DeviceStatus words, its disabled flag) and on the
## viewer's access, never on what the device is: offline grey, disabled red, access amber, alert
## words orange, else green (relative luminance about 0.1, 0.3, 0.6, 0.5 and 0.7).

const TITLE_COLOR: Color = Color(0.55, 0.95, 0.85)
const TEXT_COLOR: Color = Color(0.82, 0.95, 0.9)
const DIM_COLOR: Color = Color(0.5, 0.66, 0.64)
## Online and not disabled (#73F299).
const ONLINE_COLOR: Color = Color(0.45, 0.95, 0.6)
## Out of reach: unpowered, broken, cut off, or only seen before (#575C5C).
const OFFLINE_COLOR: Color = Color(0.34, 0.36, 0.36)
## Online and switched off by a command (#FF6157).
const DISABLED_COLOR: Color = Color(1.0, 0.38, 0.34)
## Online, enabled and doing something right now (#FFB840).
const ALERT_COLOR: Color = Color(1.0, 0.72, 0.25)
## The viewer has an account on it (the mockup's amber, #FFD14D).
const ACCESS_COLOR: Color = Color(1.0, 0.82, 0.3)
## The viewer's own entry point; Computer skill assists (#73D9FF).
const SELF_COLOR: Color = Color(0.45, 0.85, 1.0)
const ERROR_COLOR: Color = Color(0.95, 0.4, 0.35)
## Screen background, panel, bar and line colours (the mockup's --os-*).
const SCREEN_COLOR: Color = Color(0.027, 0.07, 0.067, 0.98)
const PANEL_COLOR: Color = Color(0.043, 0.102, 0.098, 1.0)
const BORDER_COLOR: Color = Color(0.3, 0.75, 0.66, 0.9)
const LINE_COLOR: Color = Color(0.3, 0.75, 0.66, 0.45)
const FIELD_COLOR: Color = Color(0.012, 0.063, 0.063, 1.0)
const BUTTON_COLOR: Color = Color(0.047, 0.133, 0.125, 1.0)
## The world behind the panel, dimmed but visible.
const WORLD_DIM: Color = Color(4.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, 0.55)
## Status words that mean something is happening right now (shown orange: red means disabled).
const ALERT_WORDS: Array[String] = ["alert", "suspicious", "tracking", "firing", "ringing", "broadcasting"]

static var _mono: SystemFont = null


## The colour of a device with status `words` (DeviceStatus) that is `disabled` or not, `access`
## or not: offline grey (beats the rest: an unreachable device's state is unknown), disabled red,
## access amber, alert words orange, else green.
static func status_color(words: PackedStringArray, disabled: bool = false, access: bool = false) -> Color:
	if words.has(DeviceStatus.OFFLINE):
		return OFFLINE_COLOR
	if disabled:
		return DISABLED_COLOR
	if access:
		return ACCESS_COLOR
	for word in words:
		if ALERT_WORDS.has(word):
			return ALERT_COLOR
	return ONLINE_COLOR


## The colour of a map row: status_color() of its words, flag and access.
static func row_color(row: NetworkRow) -> Color:
	return status_color(row.status, row.disabled, row.access)


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


static func mono_font() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(
			["JetBrains Mono", "Cascadia Mono", "Consolas", "DejaVu Sans Mono", "monospace"]
		)
	return _mono


static func label(text: String, color: Color, font_size: int = 15) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override(&"font_color", color)
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


## A label in the monospace font (addresses, codes, numbers).
static func mono(text: String, color: Color, font_size: int = 13) -> Label:
	var result := label(text, color, font_size)
	result.add_theme_font_override(&"font", mono_font())
	return result


## A wrapping paragraph `width` px wide at least.
static func paragraph(text: String, color: Color = DIM_COLOR, font_size: int = 13, width: float = 200.0) -> Label:
	var result := label(text, color, font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = width
	return result


## A button that never takes keyboard focus (Esc and typing stay with the screen), in the mockup's
## teal; `primary` outlines it brighter.
static func button(text: String, font_size: int = 14, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override(&"font_size", font_size)
	var border := TITLE_COLOR if primary else LINE_COLOR
	for state: StringName in [&"normal", &"pressed"]:
		result.add_theme_stylebox_override(state, box(BUTTON_COLOR, border, 4.0, 10.0, 5.0))
	result.add_theme_stylebox_override(&"hover", box(BUTTON_COLOR, TITLE_COLOR, 4.0, 10.0, 5.0))
	result.add_theme_stylebox_override(
		&"disabled", box(BUTTON_COLOR.darkened(0.3), LINE_COLOR.darkened(0.5), 4.0, 10.0, 5.0)
	)
	result.add_theme_color_override(&"font_color", TITLE_COLOR if primary else TEXT_COLOR)
	result.add_theme_color_override(&"font_hover_color", TITLE_COLOR)
	result.add_theme_color_override(&"font_disabled_color", DIM_COLOR.darkened(0.3))
	return result


## A flat box: `fill`, a 1 px `border`, `radius`, content margins `margin_x` / `margin_y`.
static func box(
	fill: Color, border: Color, radius: float = 4.0, margin_x: float = 8.0, margin_y: float = 6.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(radius))
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


static func panel_style(border: Color = BORDER_COLOR, width: int = 1, margin: float = 22.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style
