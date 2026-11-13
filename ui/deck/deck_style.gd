class_name DeckStyle
extends RefCounted
## Colours and small widget helpers of the deck's screens and its network map (ADR 0113), from the
## approved mockup (design/prototypes/hacking_screens.html): the terminal's teal on a dark panel.
## Boxes, buttons and fields are type variations of ui/window/window_theme.tres (DeckButton,
## DeckCard, DeckTrack, ...): the deck's WindowFrame carries that theme, so widgets built here get
## their look once they are inside it.
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
## The deck's panel colour (its header and tools; the map shots' backdrop).
const PANEL_COLOR: Color = Color(0.043, 0.102, 0.098, 1.0)
## The world behind the panel, dimmed but visible.
const WORLD_DIM: Color = Color(4.0 / 255.0, 6.0 / 255.0, 8.0 / 255.0, 0.55)
## What a Computer skill assist line starts with.
const ASSIST_PREFIX: String = "Computer skill · "
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


## Makes `target`'s children show what `fresh`'s do (both filled by the same code, `fresh` out of the
## tree) and frees `fresh`: a refresh that keeps the buttons under the cursor. A button with the same
## place, class and look keeps its node (a press held on it and its hover survive the refresh) and
## takes the fresh one's signal connections; a container holding buttons is matched child by child;
## everything else is swapped for its fresh copy. Children of another number or class are all
## replaced.
static func reconcile(target: Node, fresh: Node) -> void:
	_reconcile_children(target, fresh)
	fresh.free()


static func _reconcile_children(target: Node, fresh: Node) -> void:
	var olds: Array[Node] = []
	for child in target.get_children():
		if not child.is_queued_for_deletion():
			olds.append(child)
	var news := fresh.get_children()
	var same := olds.size() == news.size()
	if same:
		for i in olds.size():
			if olds[i].get_class() != news[i].get_class() or olds[i].get_script() != news[i].get_script():
				same = false
				break
	if not same:
		for child in olds:
			discard(child)
		for child in news:
			fresh.remove_child(child)
			target.add_child(child)
		return
	for i in olds.size():
		var old := olds[i]
		var new := news[i]
		if old is BaseButton and _button_key(old as BaseButton) == _button_key(new as BaseButton):
			_take_connections(old, new)
			_reconcile_children(old, new)
		elif not old is BaseButton and _has_button(new) and _has_button(old):
			_reconcile_children(old, new)
		else:
			fresh.remove_child(new)
			target.add_child(new)
			target.move_child(new, old.get_index())
			discard(old)


# What a button shows and does when pressed, apart from its connections and a press held on it (a
# plain button reports a held press as `button_pressed`). Only what the button itself sets counts
# (its type variation and overrides): `fresh` is out of the tree, where the theme does not reach.
static func _button_key(button: BaseButton) -> Array:
	var key: Array = [
		button.disabled,
		button.toggle_mode,
		button.toggle_mode and button.button_pressed,
		button.tooltip_text,
		button.mouse_filter,
		button.theme_type_variation,
	]
	if button.has_theme_color_override(&"font_color"):
		key.append(button.get_theme_color(&"font_color"))
	if button.has_theme_font_size_override(&"font_size"):
		key.append(button.get_theme_font_size(&"font_size"))
	var text_button := button as Button
	if text_button != null:
		key.append(text_button.text)
	if button.has_theme_stylebox_override(&"normal"):
		var style := button.get_theme_stylebox(&"normal") as StyleBoxFlat
		if style != null:
			key.append_array([style.bg_color, style.border_color, style.border_width_left])
	return key


static func _take_connections(old: Node, new: Node) -> void:
	for signal_name: StringName in [&"pressed", &"toggled", &"button_down", &"button_up"]:
		for connection: Dictionary in old.get_signal_connection_list(signal_name):
			old.disconnect(signal_name, connection["callable"] as Callable)
		for connection: Dictionary in new.get_signal_connection_list(signal_name):
			old.connect(signal_name, connection["callable"] as Callable, connection["flags"] as int)


static func _has_button(node: Node) -> bool:
	for child in node.get_children():
		if child is BaseButton or _has_button(child):
			return true
	return false


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
	var result := Label.new()
	result.text = text
	style_mono(result, color, font_size)
	return result


## Gives `target` (any Label: a TimedLabel toast) the look of mono().
static func style_mono(target: Label, color: Color, font_size: int = 13) -> void:
	target.add_theme_color_override(&"font_color", color)
	target.add_theme_font_size_override(&"font_size", font_size)
	target.add_theme_font_override(&"font", mono_font())


## A wrapping paragraph `width` px wide at least.
static func paragraph(text: String, color: Color = DIM_COLOR, font_size: int = 13, width: float = 200.0) -> Label:
	var result := label(text, color, font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = width
	return result


## A button that never takes keyboard focus (Esc and typing stay with the screen), in the mockup's
## teal (DeckButton); `primary` outlines it brighter (DeckButtonPrimary).
static func button(text: String, font_size: int = 14, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text
	result.focus_mode = Control.FOCUS_NONE
	result.theme_type_variation = &"DeckButtonPrimary" if primary else &"DeckButton"
	result.add_theme_font_size_override(&"font_size", font_size)
	return result


## A bar's track (DeckTrack) `width` x `height` px with a fill of `fraction` in `color`.
static func track(width: float, height: float, fraction: float, color: Color) -> Panel:
	var result := Panel.new()
	result.theme_type_variation = &"DeckTrack"
	result.custom_minimum_size = Vector2(width, height)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = color
	fill.size = Vector2(width * clampf(fraction, 0.0, 1.0), height)
	result.add_child(fill)
	return result


## A skill assist line ("Computer skill · about +30 % trace"), outlined blue (DeckAssist).
static func assist(text: String) -> Label:
	var result := mono(ASSIST_PREFIX + text, SELF_COLOR, 12)
	result.theme_type_variation = &"DeckAssist"
	return result


## "7.5 s", "18 s".
static func seconds(value: float) -> String:
	return "%s s" % number(value)


## A value to one decimal, without ".0".
static func number(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(roundi(rounded))
	return "%.1f" % rounded
