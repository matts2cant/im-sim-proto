class_name HalcyonStyle
extends RefCounted
## Look of the Halcyon OS overlay (ADR 0114, design/prototypes/hacking_screens.html): the teal
## screen palette and small builders for its labels, buttons and fields. Boxes, buttons and fields
## are type variations of ui/window/window_theme.tres (HalcyonButton, HalcyonListEntry, HalcyonField,
## HalcyonCard, ...): the overlay's WindowFrame carries that theme. Status colours are this palette's
## colours for the tones of the screens' one colour rule (DeviceStatus.tone(): offline grey, disabled
## red, alert amber, else green), never what the device is.

const LINE := Color(77.0 / 255.0, 191.0 / 255.0, 168.0 / 255.0, 0.45)
const TEAL := Color("8cf2d9")
const TEXT := Color("d1f2e6")
const DIM := Color("7fa8a3")
const ONLINE := Color("73f299")
const OFFLINE := Color("575c5c")
const ALERT := Color("ffb840")
const BAD := Color("e5534b")
const AMBER := Color("ffd14d")
const SELF := Color("73d9ff")
## The colour of each tone of DeviceStatus.tone() (the Security app has no access tone: green).
const TONES: Dictionary[DeviceStatus.Tone, Color] = {
	DeviceStatus.Tone.ONLINE: ONLINE,
	DeviceStatus.Tone.OFFLINE: OFFLINE,
	DeviceStatus.Tone.DISABLED: BAD,
	DeviceStatus.Tone.ACCESS: ONLINE,
	DeviceStatus.Tone.ALERT: ALERT,
}


## The colour of a device with status `words` (DeviceStatus) that is `disabled` or not and says an
## `alert` word or not: TONES of DeviceStatus.tone().
static func status_color(words: PackedStringArray, disabled: bool = false, alert: bool = false) -> Color:
	return TONES[DeviceStatus.tone(words, disabled, false, alert)]


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


## A button that never takes keyboard focus (Esc and typing stay with the screen): HalcyonButton,
## HalcyonButtonPrimary (`primary`) or HalcyonButtonDanger (`danger`: red on hover).
static func button(text: String, primary: bool = false, danger: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.theme_type_variation = (
		&"HalcyonButtonPrimary" if primary else (&"HalcyonButtonDanger" if danger else &"HalcyonButton")
	)
	return node


## A flat list entry (Mail, Files, Security lists, the dock): a toggle with a teal border when
## selected (HalcyonListEntry).
static func list_entry(text: String = "") -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.toggle_mode = true
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.theme_type_variation = &"HalcyonListEntry"
	return node


## A text field (HalcyonField).
static func field(secret: bool) -> LineEdit:
	var node := LineEdit.new()
	node.secret = secret
	node.custom_minimum_size = Vector2(260, 0)
	node.add_theme_font_override(&"font", TabStyle.mono_font())
	node.theme_type_variation = &"HalcyonField"
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
