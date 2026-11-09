class_name NetworkGraph
extends Control
## The terminal screen's Network tab (ADR 0083): one node per device of the terminal's physical
## network (Terminal.devices()), placed by NetworkLayout (a top-down floor plan of their world
## positions), arcs for the cables (solid between two online devices, dashed otherwise; longer cables
## bow further so cables along one wall stay apart), the terminal itself outlined. Each node shows
## its name and its status words (offline grey, alert words red). Clicking a node opens a small menu
## under it: its name, status and one button per command it accepts (none while offline); a button
## emits `command_pressed`. Clicking the background closes it.

signal command_pressed(command: StringName, target: Device)

## Space kept free around the nodes (px).
const MARGIN: float = 56.0
## Nodes closer than this (px, centre to centre) are pushed apart.
const MIN_GAP: float = 84.0
## Then their boxes (name and status line) are pushed this far apart (px, edge to edge), kept
## NODE_INSET inside the panel. A node's point (cable end) is NODE_TOP below its box's top edge.
const NODE_GAP: float = 6.0
const NODE_INSET: float = 6.0
const NODE_TOP: float = 14.0
## Node box widths are rounded up to this (px) for pushing apart.
const BOX_WIDTH_STEP: float = 24.0
const MAX_STRETCH: float = 2.0
const MENU_WIDTH: float = 210.0
## Gap between a node's centre and the top of its menu (px).
const MENU_OFFSET: float = 34.0
## A cable bows sideways by this fraction of its length (at its middle), at most CABLE_BOW_MAX px.
const CABLE_BOW: float = 0.15
const CABLE_BOW_MAX: float = 70.0
## Length of one arc segment (px): a dash of a dashed cable.
const CABLE_SEGMENT: float = 9.0
const BACKGROUND: Color = Color(0.02, 0.05, 0.05)

var config: TerminalConfig
var rows: Array[Terminal.Row] = []
var cables: Array[Vector2i] = []
## Node centres, same order as `rows`.
var points: Array[Vector2] = []
## The device whose menu is open (null: none).
var selected: Device

var menu: PanelContainer
var menu_title: Label
var menu_status: Label

var _nodes: Array[Control] = []
var _styles: Array[StyleBoxFlat] = []
var _menu_buttons: VBoxContainer
# What the last placement was computed from ([area, world positions, boxes]).
var _layout_key: Array = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	menu = PanelContainer.new()
	menu.visible = false
	menu.custom_minimum_size.x = MENU_WIDTH
	menu.z_index = 1
	menu.add_theme_stylebox_override(&"panel", TerminalStyle.panel_style(TerminalStyle.BORDER_COLOR, 1, 10.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	menu.add_child(column)
	menu_title = TerminalStyle.label("", TerminalStyle.TITLE_COLOR, 16)
	column.add_child(menu_title)
	menu_status = TerminalStyle.label("", TerminalStyle.TEXT_COLOR, 13)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.custom_minimum_size.x = MENU_WIDTH - 20.0
	column.add_child(menu_status)
	_menu_buttons = VBoxContainer.new()
	_menu_buttons.add_theme_constant_override(&"separation", 4)
	column.add_child(_menu_buttons)
	add_child(menu)


## Shows `p_rows` (Terminal.devices()) and their `p_cables` (Terminal.cables()); an open menu stays
## open on the same device and shows its new status.
func show_network(p_rows: Array[Terminal.Row], p_cables: Array[Vector2i], p_config: TerminalConfig) -> void:
	rows = p_rows
	cables = p_cables
	config = p_config
	for node in _nodes:
		TerminalStyle.discard(node)
	_nodes.clear()
	_styles.clear()
	for i in rows.size():
		var node := _node(rows[i])
		_nodes.append(node)
		add_child(node)
	move_child(menu, get_child_count() - 1)
	_layout()
	if is_instance_valid(selected) and _index_of(selected) < 0:
		selected = null
	_update_menu()


## Opens the menu of the node named `device_name` (tests); false when there is none.
func select(device_name: String) -> bool:
	var index := _index_by_name(device_name)
	if index < 0:
		return false
	_open_menu(index)
	return true


func close_menu() -> void:
	selected = null
	_update_menu()


## The node names, in row order.
func node_names() -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		names.append(row.name)
	return names


## The node button of `device_name`, or null.
func node_button(device_name: String) -> Button:
	var index := _index_by_name(device_name)
	return _nodes[index].get_node(^"Button") as Button if index >= 0 else null


## The status line under the node of `device_name` ("" when there is none).
func node_status(device_name: String) -> String:
	var index := _index_by_name(device_name)
	return (_nodes[index].get_node(^"Status") as Label).text if index >= 0 else ""


## The open menu's command button `label`, or null.
func menu_button(label: String) -> Button:
	if not menu.visible:
		return null
	for child in _menu_buttons.get_children():
		var command_button := child as Button
		if command_button != null and not command_button.is_queued_for_deletion() and command_button.text == label:
			return command_button
	return null


## The open menu's command button labels.
func menu_labels() -> Array[String]:
	var labels: Array[String] = []
	if menu.visible:
		for child in _menu_buttons.get_children():
			if child is Button and not child.is_queued_for_deletion():
				labels.append((child as Button).text)
	return labels


## Each node's box (name and status line) in the graph, in row order (tests).
func node_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node in _nodes:
		rects.append(Rect2(node.position, node.size))
	return rects


## The cables as pairs of device names (tests).
func cable_names() -> Array[String]:
	var names: Array[String] = []
	for cable in cables:
		names.append("%s-%s" % [rows[cable.x].name, rows[cable.y].name])
	return names


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close_menu()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, size), TerminalStyle.BORDER_COLOR.darkened(0.5), false, 1.0)
	for cable in cables:
		if cable.x >= points.size() or cable.y >= points.size():
			continue
		var live := rows[cable.x].online and rows[cable.y].online
		var color := TerminalStyle.ONLINE_COLOR.darkened(0.25) if live else TerminalStyle.OFFLINE_COLOR.darkened(0.1)
		var arc := cable_arc(points[cable.x], points[cable.y], size.max(custom_minimum_size) * 0.5)
		if live:
			draw_polyline(arc, color, 2.0, true)
			continue
		# Dashed: every other segment.
		for i in range(0, arc.size() - 1, 2):
			draw_line(arc[i], arc[i + 1], color, 2.0, true)


## The cable from `from` to `to` as a polyline of CABLE_SEGMENT pieces: a quadratic arc bowing
## toward `inside` (the panel's centre), CABLE_BOW of its length at the middle.
static func cable_arc(from: Vector2, to: Vector2, inside: Vector2) -> PackedVector2Array:
	var along := to - from
	var middle := (from + to) * 0.5
	var bow := minf(along.length() * CABLE_BOW, CABLE_BOW_MAX)
	var side := Vector2(along.y, -along.x).normalized()
	if side.dot(inside - middle) < 0.0:
		side = -side
	# A quadratic curve reaches half its control point's offset at the middle.
	var control := middle + side * bow * 2.0
	var segments := maxi(int(along.length() / CABLE_SEGMENT), 2)
	var arc := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		arc.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	return arc


func _layout() -> void:
	var area := size.max(custom_minimum_size)
	var positions: Array[Vector3] = []
	for row in rows:
		positions.append(row.position())
	# Names and status lines are wide: the node boxes are pushed apart so no label hides another.
	# Box widths are rounded up to BOX_WIDTH_STEP, so a status change rarely moves the nodes, and the
	# last placement is reused while nothing it depends on changed (pushing apart costs tens of ms).
	var boxes: Array[Rect2] = []
	for node in _nodes:
		node.size = node.get_combined_minimum_size()
		var width := ceilf(node.size.x / BOX_WIDTH_STEP) * BOX_WIDTH_STEP
		boxes.append(Rect2(Vector2(-width * 0.5, -NODE_TOP), Vector2(width, node.size.y)))
	var key := [area, positions, boxes]
	if key != _layout_key:
		_layout_key = key
		points = NetworkLayout.project(positions, area, MARGIN, MAX_STRETCH, MIN_GAP)
		NetworkLayout.separate_boxes(points, boxes, NODE_GAP, area, NODE_INSET)
	for i in _nodes.size():
		_nodes[i].position = points[i] - Vector2(_nodes[i].size.x * 0.5, NODE_TOP)
	_place_menu()
	queue_redraw()


func _node(row: Terminal.Row) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_button := TerminalStyle.button(row.name, 13)
	node_button.name = "Button"
	node_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var color := TerminalStyle.status_color(row.status)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.1, 0.1, 1.0)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	_styles.append(style)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		node_button.add_theme_stylebox_override(state, style)
	node_button.add_theme_color_override(&"font_color", TerminalStyle.TEXT_COLOR if row.online else color)
	node_button.add_theme_color_override(&"font_hover_color", TerminalStyle.TITLE_COLOR)
	node_button.pressed.connect(_on_node_pressed.bind(row.device))
	box.add_child(node_button)
	var status := TerminalStyle.label(_short_status(row), color, 11)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Cables pass under the nodes: the status line hides them.
	var backing := StyleBoxFlat.new()
	backing.bg_color = BACKGROUND
	backing.set_content_margin_all(1)
	status.add_theme_stylebox_override(&"normal", backing)
	box.add_child(status)
	return box


# The node's status line: its words without "online" (offline devices say "offline").
func _short_status(row: Terminal.Row) -> String:
	var words := PackedStringArray()
	for word in row.status:
		if word != DeviceStatus.ONLINE:
			words.append(word)
	return TerminalStyle.status_text(words) if not words.is_empty() else DeviceStatus.ONLINE


func _on_node_pressed(device: Device) -> void:
	var index := _index_of(device)
	if index >= 0:
		_open_menu(index)


func _open_menu(index: int) -> void:
	selected = rows[index].device
	_update_menu()


func _update_menu() -> void:
	var index := _index_of(selected) if is_instance_valid(selected) else -1
	_restyle(index)
	menu.visible = index >= 0
	if index < 0:
		return
	var row := rows[index]
	menu_title.text = row.name
	menu_status.text = TerminalStyle.status_text(row.status)
	menu_status.add_theme_color_override(&"font_color", TerminalStyle.status_color(row.status))
	for child in _menu_buttons.get_children():
		TerminalStyle.discard(child)
	for command in row.commands:
		var command_button := TerminalStyle.button(config.label_for(command) if config != null else String(command), 14)
		command_button.pressed.connect(func() -> void: command_pressed.emit(command, row.device))
		_menu_buttons.add_child(command_button)
	if row.commands.is_empty():
		var reason := "No connection." if not row.online else "No commands."
		_menu_buttons.add_child(TerminalStyle.label(reason, TerminalStyle.DIM_COLOR, 13))
	_place_menu()


# Node outlines: the terminal thick blue, the others their status colour; the selected one white.
func _restyle(selected_index: int) -> void:
	for i in mini(_styles.size(), rows.size()):
		var style := _styles[i]
		var row := rows[i]
		style.border_color = TerminalStyle.SELF_COLOR if row.is_self else TerminalStyle.status_color(row.status)
		style.set_border_width_all(3 if row.is_self else 1)
		if i == selected_index:
			style.border_color = Color.WHITE
			style.set_border_width_all(3 if row.is_self else 2)


# Under the selected node (above it when there is no room below), inside the graph.
func _place_menu() -> void:
	var index := _index_of(selected) if is_instance_valid(selected) else -1
	if index < 0 or index >= points.size():
		return
	menu.reset_size()
	var area := size.max(custom_minimum_size)
	var menu_size := menu.get_combined_minimum_size()
	var at := points[index] + Vector2(-menu_size.x * 0.5, MENU_OFFSET)
	if at.y + menu_size.y > area.y:
		at.y = points[index].y - MENU_OFFSET * 0.6 - menu_size.y
	menu.position = at.clamp(Vector2.ZERO, (area - menu_size).max(Vector2.ZERO))


func _index_of(device: Device) -> int:
	for i in rows.size():
		if rows[i].device == device:
			return i
	return -1


func _index_by_name(device_name: String) -> int:
	for i in rows.size():
		if rows[i].name == device_name:
			return i
	return -1
