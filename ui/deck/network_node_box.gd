class_name NetworkNodeBox
extends VBoxContainer
## One node of a NetworkGraph (ADR 0083, 0099): the device's name button ("name · role") over its
## status line (its address, then its status words without "online"). The outline and the status
## line take the device's colour (DeckStyle.row_color(): offline grey, disabled red, access amber,
## alert words orange, else green); the owner's own device is outlined thick blue, a disabled one is
## tinted red inside, the selected one white and lighter inside. Name and status sit on the bus side
## of the box (centred on a hub). Children "Button" and "Status" (tests find them by name).

var button: Button
var status: Label
## The button's box in every state (restyle() changes it in place).
var style: StyleBoxFlat


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
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override(&"font_color", DeckStyle.TEXT_COLOR if row.online else color)
	button.add_theme_color_override(&"font_hover_color", DeckStyle.TITLE_COLOR)
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
## red-tinted inside); `selected` white and lighter inside (readable on every colour).
func restyle(row: NetworkRow, selected: bool) -> void:
	style.border_color = DeckStyle.SELF_COLOR if row.is_self else DeckStyle.row_color(row)
	style.set_border_width_all(3 if row.is_self else 1)
	style.bg_color = NetworkGraph.DISABLED_FILL if row.disabled else NetworkGraph.NODE_FILL
	if selected:
		style.border_color = Color.WHITE
		style.set_border_width_all(3 if row.is_self else 2)
		style.bg_color = NetworkGraph.SELECTED_FILL
