class_name NetworkNodeBox
extends VBoxContainer
## One node of a NetworkGraph (ADR 0083, 0099, 0121, 0130): the device's name button ("name · role")
## over its status line (its address, then its status words without "online"). In the device
## language (ADR 0130, design/prototypes/device_language.html "The deck's Map"), a row with a kind
## shows its kind's colour as a strip on the button's left edge (child "Strip") and its kind's icon in
## that colour (child "Icon"); a row with a light (NetworkRow.light) shows a status square at the
## button's right (child "Light") in the status light's colours (StatusLight.COLORS), blinking while
## cut off (a Timer: only the square redraws), outlined while dark.
## The outline and the status line take the device's colour (DeckStyle.row_color(): offline grey,
## disabled red, access amber, alert words orange, else green); the owner's own device is outlined
## thick blue, a disabled one is tinted red inside, the selected one white and lighter inside. Name
## and status sit on the bus side of the box (centred on a hub). Children "Button" and "Status"
## (tests find them by name).

## The kind's icon (px).
const ICON_SIZE: float = 16.0
## The kind's strip on the left edge (px wide).
const STRIP_WIDTH: float = 4.0
## The status square (px), and the gaps around it.
const LIGHT_SIZE: float = 8.0
const PAD: float = 6.0
## Half a blink period of a cut-off square (s, the mockup's 0.8 s blink) and its dim alpha.
const BLINK_HALF: float = 0.4
const BLINK_DIM: float = 0.15
## The outline of a dark square (the mockup's #3a4046), so it shows on the node's fill.
const DARK_EDGE: Color = Color(0.227, 0.251, 0.275)

var button: Button
var status: Label
## The kind's icon in the button, or null.
var icon: DeviceIcon
## The kind's colour strip in the button, or null.
var strip: Panel
## The status square in the button, or null.
var light: Panel
## The square blinks (cut off).
var light_blinking: bool = false
## The button's box in every state (restyle() changes it in place).
var style: StyleBoxFlat

# The blinking square is in its dim half.
var _dimmed: bool = false


func _init(row: NetworkRow) -> void:
	add_theme_constant_override(&"separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button = Button.new()
	button.text = row.name if row.role.is_empty() else "%s · %s" % [row.name, row.role]
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 13)
	button.name = "Button"
	# Pass: the wheel over a node zooms (a press on it is its click, never a drag: the graph's input).
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	var color := DeckStyle.row_color(row)
	style = StyleBoxFlat.new()
	style.bg_color = NetworkGraph.NODE_FILL
	style.set_corner_radius_all(4)
	style.content_margin_left = PAD
	style.content_margin_right = PAD
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override(&"font_color", DeckStyle.TEXT_COLOR if row.online else color)
	button.add_theme_color_override(&"font_hover_color", DeckStyle.TITLE_COLOR)
	var left := PAD
	if row.kind_color.a > 0.0:
		strip = _strip(row.kind_color)
		button.add_child(strip)
		left += STRIP_WIDTH
	if not row.icon.is_empty():
		icon = DeviceIcon.make(row.icon, row.kind_color if row.kind_color.a > 0.0 else color, ICON_SIZE)
		icon.name = "Icon"
		_centre_v(icon, ICON_SIZE)
		icon.offset_left = left
		icon.offset_right = left + ICON_SIZE
		button.add_child(icon)
		left += ICON_SIZE + 5.0
	style.content_margin_left = left
	if row.light != NetworkRow.NO_LIGHT:
		light = _light(row.light as StatusLight.State)
		button.add_child(light)
		style.content_margin_right = PAD + LIGHT_SIZE + PAD
	add_child(button)
	status = DeckStyle.label(short_status(row), color, 11)
	status.name = "Status"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cables pass under the nodes: the status line hides them.
	var backing := StyleBoxFlat.new()
	backing.bg_color = NetworkGraph.BACKGROUND
	backing.set_content_margin_all(1)
	status.add_theme_stylebox_override(&"normal", backing)
	add_child(status)


## The node's status line: its address (if any), then its words without "online" (offline devices
## say "offline").
static func short_status(row: NetworkRow) -> String:
	var words := PackedStringArray()
	if not row.address.is_empty():
		words.append(row.address)
	var states := PackedStringArray()
	for word in row.status:
		if word != DeviceStatus.ONLINE:
			states.append(word)
	words.append(DeckStyle.status_text(states) if not states.is_empty() else DeviceStatus.ONLINE)
	return DeckStyle.status_text(words)


## The node box holding `node_button` (NetworkGraph.node_button()), or null.
static func of(node_button: Button) -> NetworkNodeBox:
	return node_button.get_parent() as NetworkNodeBox if node_button != null else null


## The fill colour of `panel` (a node's `strip` or `light`); transparent for null.
static func fill_of(panel: Panel) -> Color:
	var box := panel.get_theme_stylebox(&"panel") as StyleBoxFlat if panel != null else null
	return box.bg_color if box != null else Color.TRANSPARENT


## Name and status aligned on the bus side of the node's box (`side` as NetworkLayout.sides: -1
## left of its bus, 1 right, 0 a hub or router: centred).
func align(side: int) -> void:
	var flags := Control.SIZE_SHRINK_CENTER
	var alignment := HORIZONTAL_ALIGNMENT_CENTER
	if side < 0:
		flags = Control.SIZE_SHRINK_END
		alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif side > 0:
		flags = Control.SIZE_SHRINK_BEGIN
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size_flags_horizontal = flags
	status.size_flags_horizontal = flags
	status.horizontal_alignment = alignment


## The outline: the owner's own device thick blue, the others their row colour (a disabled one
## red-tinted inside); `selected` white and lighter inside (readable on every colour). The strip,
## icon and square keep their colours.
func restyle(row: NetworkRow, selected: bool) -> void:
	style.border_color = DeckStyle.SELF_COLOR if row.is_self else DeckStyle.row_color(row)
	if icon != null and row.kind_color.a <= 0.0:
		icon.colour = style.border_color
	style.set_border_width_all(3 if row.is_self else 1)
	style.bg_color = NetworkGraph.DISABLED_FILL if row.disabled else NetworkGraph.NODE_FILL
	if selected:
		style.border_color = Color.WHITE
		style.set_border_width_all(3 if row.is_self else 2)
		style.bg_color = NetworkGraph.SELECTED_FILL


func _strip(color: Color) -> Panel:
	var panel := Panel.new()
	panel.name = "Strip"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 4
	box.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override(&"panel", box)
	panel.anchor_bottom = 1.0
	panel.offset_right = STRIP_WIDTH
	return panel


func _light(state: StatusLight.State) -> Panel:
	var panel := Panel.new()
	panel.name = "Light"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = StatusLight.COLORS[state]
	if state == StatusLight.State.DARK:
		box.border_color = DARK_EDGE
		box.set_border_width_all(1)
	panel.add_theme_stylebox_override(&"panel", box)
	_centre_v(panel, LIGHT_SIZE)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -PAD - LIGHT_SIZE
	panel.offset_right = -PAD
	if state == StatusLight.State.CUT_OFF:
		light_blinking = true
		var timer := Timer.new()
		timer.name = "Blink"
		timer.wait_time = BLINK_HALF
		timer.autostart = true
		timer.timeout.connect(_blink)
		panel.add_child(timer)
	return panel


func _blink() -> void:
	_dimmed = not _dimmed
	if light != null:
		light.modulate.a = BLINK_DIM if _dimmed else 1.0


static func _centre_v(control: Control, side: float) -> void:
	control.anchor_top = 0.5
	control.anchor_bottom = 0.5
	control.offset_top = -side * 0.5
	control.offset_bottom = side * 0.5
