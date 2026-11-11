class_name NetworkGraph
extends Control
## A network map (ADR 0083, 0099; the deck's Map since ADR 0113, moved from ui/terminal/): one node
## per NetworkRow its owner gives it (the deck's discovered devices; the M8 terminal's network), grouped
## by the hub it hangs on and placed by NetworkLayout, the cables along the layout's routes (solid
## green between two online devices, also when one is disabled: the link works; dashed grey
## otherwise), the owner's own device outlined. Each node shows its name and its address and status
## words; its outline and status line take the device's colour (DeckStyle.row_color(): offline
## grey, disabled red, access amber, alert words orange, else green).
## The map pans and zooms (NetworkView): drag with the left or middle mouse button to move it, the
## wheel zooms around the cursor, fit_view() (the Fit button, F on the screen) shows the whole
## network; it opens fitted (request_fit()). The nodes, their labels and the cables live in
## `content`, a child scaled and moved by the view; the menu and the Fit button stay in the panel.
## Clicking a node (without dragging) opens a small menu beside it, kept inside the panel: its name,
## status and, by default, one button per command of its row (none while offline; a button emits
## `command_pressed`); an owner with `menu_builder` fills the menu itself (the deck: accounts,
## Icebreaker, actions). Clicking the background closes it; `menu_closed` tells the owner.

signal command_pressed(command: StringName, target: Device)
## The menu was opened on `target` (null: it closed).
signal selection_changed(target: Device)

## Space kept around the network when fitted (px).
const FIT_MARGIN: float = 24.0
## A node's cable end is NODE_TOP below its box's top edge (the middle of its name button).
const NODE_TOP: float = 12.0
const MENU_WIDTH: float = 210.0
## Gap between a node's box and its menu (panel px).
const MENU_GAP: float = 8.0
## Zoom factor per wheel notch.
const ZOOM_STEP: float = 1.15
## A press moving further than this (px) is a drag, not a click.
const DRAG_THRESHOLD: float = 4.0
## Trackpad pan gesture speed (px per unit).
const PAN_GESTURE_SPEED: float = 12.0
const CABLE_WIDTH: float = 2.0
## Dashes of a cable with an offline end (content px).
const DASH: float = 7.0
const DASH_GAP: float = 5.0
const BACKGROUND: Color = Color(0.02, 0.05, 0.05)
## A node box's fill, a disabled node's (tinted red: a second cue beside the outline), and the
## selected node's (with a white outline).
const NODE_FILL: Color = Color(0.04, 0.1, 0.1, 1.0)
const DISABLED_FILL: Color = Color(0.22, 0.08, 0.08, 1.0)
const SELECTED_FILL: Color = Color(0.13, 0.22, 0.22, 1.0)
const LIVE_CABLE_COLOR: Color = Color(0.3375, 0.7125, 0.45)

## Command -> button label for the default menu (empty: the words after `command.`).
var command_label: Callable = Callable()
## Fills the menu below its title and status: Callable(row: NetworkRow, column: VBoxContainer);
## empty: one button per command of the row.
var menu_builder: Callable = Callable()
## The menu's width (px).
var menu_width: float = MENU_WIDTH
var rows: Array[NetworkRow] = []
var cables: Array[Vector2i] = []
## The device whose menu is open (null: none).
var selected: Device
var view := NetworkView.new()
## The last placement (null before the first network).
var layout: NetworkLayout
## Holds the nodes and draws the cables; moved and scaled by `view`.
var content: Control

var menu: PanelContainer
var menu_title: Label
var menu_status: Label
var fit_button: Button

var _nodes: Array[Control] = []
var _styles: Array[StyleBoxFlat] = []
var _menu_buttons: VBoxContainer
# Fit at the next chance (the panel has a size and a network).
var _fit_pending: bool = true
# The view is as fit_view() left it: a resize fits again.
var _fitted: bool = false
# Where the left or middle button went down (INF: not down), the last drag point, and whether the
# press became a drag.
var _press_at: Vector2 = Vector2.INF
var _drag_last: Vector2 = Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.draw.connect(_draw_cables)
	add_child(content)
	menu = PanelContainer.new()
	menu.visible = false
	menu.custom_minimum_size.x = menu_width
	menu.z_index = 1
	menu.add_theme_stylebox_override(&"panel", DeckStyle.panel_style(DeckStyle.BORDER_COLOR, 1, 10.0))
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	menu.add_child(column)
	menu_title = DeckStyle.label("", DeckStyle.TITLE_COLOR, 16)
	column.add_child(menu_title)
	menu_status = DeckStyle.label("", DeckStyle.TEXT_COLOR, 13)
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.custom_minimum_size.x = menu_width - 20.0
	column.add_child(menu_status)
	_menu_buttons = VBoxContainer.new()
	_menu_buttons.add_theme_constant_override(&"separation", 4)
	column.add_child(_menu_buttons)
	add_child(menu)
	fit_button = DeckStyle.button("Fit", 13)
	fit_button.name = "Fit"
	fit_button.tooltip_text = "Show the whole network (F)"
	fit_button.z_index = 1
	var fit_style := DeckStyle.panel_style(DeckStyle.BORDER_COLOR, 1, 6.0)
	fit_style.content_margin_left = 12.0
	fit_style.content_margin_right = 12.0
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		fit_button.add_theme_stylebox_override(state, fit_style)
	fit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	fit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fit_button.pressed.connect(fit_view)
	add_child(fit_button)


## Shows `p_rows` (NetworkRow, typed or not: the deck's rows) and their
## `p_cables` (index pairs into them); `p_labels`: the default menu's command labels (a Callable, or
## an object with `label_for(command)` such as a DeckConfig; null: keep). An open menu stays open
## on the same device and shows its new status. The view stays where it is (see request_fit()).
func show_network(p_rows: Array, p_cables: Array[Vector2i], p_labels: Variant = null) -> void:
	rows = NetworkRow.list(p_rows)
	cables = p_cables
	if p_labels is Callable:
		command_label = p_labels as Callable
	elif p_labels is Object and (p_labels as Object).has_method(&"label_for"):
		command_label = Callable(p_labels as Object, &"label_for")
	for node in _nodes:
		DeckStyle.discard(node)
	_nodes.clear()
	_styles.clear()
	for i in rows.size():
		var node := _node(rows[i])
		_nodes.append(node)
		content.add_child(node)
	_layout()
	if is_instance_valid(selected) and _index_of(selected) < 0:
		selected = null
	_update_menu()


## Fits the view as soon as the panel has a size and a network (the terminal screen asks on open).
func request_fit() -> void:
	_fit_pending = true
	_try_fit()


## Shows the whole network, centred (the Fit button, F).
func fit_view() -> void:
	_fit_pending = false
	_fitted = true
	view.fit(layout.bounds if layout != null else Rect2(), _panel_size(), FIT_MARGIN)
	_apply_view()


## Zooms by `factor` around `point` (graph coordinates), as the wheel does.
func zoom_at(point: Vector2, factor: float) -> void:
	_fitted = false
	view.zoom_at(point, factor)
	_apply_view()


## Moves the map by `by` px, as a drag does.
func pan(by: Vector2) -> void:
	_fitted = false
	view.pan(by)
	_apply_view()


## Opens the menu of the node named `device_name` (tests); false when there is none.
func select(device_name: String) -> bool:
	var index := _index_by_name(device_name)
	if index < 0:
		return false
	_open_menu(index)
	return true


func close_menu() -> void:
	var was := selected
	selected = null
	_update_menu()
	if was != null:
		selection_changed.emit(null)


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


## The outline colour of the node of `device_name` as drawn (white while selected), or black.
func node_color(device_name: String) -> Color:
	var index := _index_by_name(device_name)
	return _styles[index].border_color if index >= 0 else Color.BLACK


## The colour of the status line under the node of `device_name`, or black.
func node_status_color(device_name: String) -> Color:
	var index := _index_by_name(device_name)
	if index < 0:
		return Color.BLACK
	return (_nodes[index].get_node(^"Status") as Label).get_theme_color(&"font_color")


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


## Each node's box (name and status line) in content coordinates (zoom 1), in row order (tests).
func node_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node in _nodes:
		rects.append(Rect2(node.position, node.size))
	return rects


## The box of `device_name` as shown in the panel (graph coordinates), or an empty Rect2.
func node_screen_rect(device_name: String) -> Rect2:
	var index := _index_by_name(device_name)
	if index < 0:
		return Rect2()
	return view.rect_to_screen(Rect2(_nodes[index].position, _nodes[index].size))


## The name of the node under `point` (graph coordinates), "" when none.
func node_name_at(point: Vector2) -> String:
	var index := _index_at(point)
	return rows[index].name if index >= 0 else ""


## The cables as pairs of device names (tests).
func cable_names() -> Array[String]:
	var names: Array[String] = []
	for cable in cables:
		names.append("%s-%s" % [rows[cable.x].name, rows[cable.y].name])
	return names


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null:
		_mouse_button(button)
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _press_at != Vector2.INF:
		if not _dragging and motion.position.distance_to(_press_at) > DRAG_THRESHOLD:
			_dragging = true
			_drag_last = _press_at
		if _dragging:
			pan(motion.position - _drag_last)
			_drag_last = motion.position
		accept_event()
		return
	var gesture := event as InputEventPanGesture
	if gesture != null:
		pan(-gesture.delta * PAN_GESTURE_SPEED)
		accept_event()
		return
	var magnify := event as InputEventMagnifyGesture
	if magnify != null:
		zoom_at(magnify.position, magnify.factor)
		accept_event()


func _mouse_button(button: InputEventMouseButton) -> void:
	match button.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if button.pressed:
				var notches := button.factor if button.factor > 0.0 else 1.0
				var step := pow(ZOOM_STEP, notches)
				zoom_at(button.position, step if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step)
			accept_event()
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			if button.pressed:
				_press_at = button.position
				_dragging = false
			else:
				if not _dragging and _press_at != Vector2.INF and button.button_index == MOUSE_BUTTON_LEFT:
					_click(button.position)
				_press_at = Vector2.INF
				_dragging = false
			accept_event()


# A click (no drag): a node opens its menu, the background closes it.
func _click(point: Vector2) -> void:
	var index := _index_at(point)
	if index < 0:
		close_menu()
	elif rows[index].device != selected:
		_open_menu(index)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, size), DeckStyle.BORDER_COLOR.darkened(0.5), false, 1.0)


# The cables, in content coordinates: dashed ones first, so a live bus shared with them stays solid.
func _draw_cables() -> void:
	if layout == null:
		return
	for pass_live: bool in [false, true]:
		for k in mini(cables.size(), layout.routes.size()):
			var cable := cables[k]
			if cable.x >= rows.size() or cable.y >= rows.size():
				continue
			var live := cable_live(k)
			if live != pass_live:
				continue
			var route := layout.routes[k]
			if route.size() < 2:
				continue
			if live:
				content.draw_polyline(route, cable_color(k), CABLE_WIDTH, true)
				continue
			for dash in dashes(route, DASH, DASH_GAP):
				content.draw_line(dash[0], dash[1], cable_color(k), CABLE_WIDTH, true)


## True when cable `k` joins two online devices (drawn solid; else dashed). A disabled end does not
## matter: the link works (commands reach the device, the player can enable it again).
func cable_live(k: int) -> bool:
	if k < 0 or k >= cables.size() or cables[k].x >= rows.size() or cables[k].y >= rows.size():
		return false
	return rows[cables[k].x].online and rows[cables[k].y].online


## The colour cable `k` is drawn in: green while live, the offline grey otherwise.
func cable_color(k: int) -> Color:
	return LIVE_CABLE_COLOR if cable_live(k) else DeckStyle.OFFLINE_COLOR


## `route` cut into dashes of `dash` px with `gap` px between them, as [from, to] pairs.
static func dashes(route: PackedVector2Array, dash: float, gap: float) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	var period := dash + gap
	var walked := 0.0
	for i in route.size() - 1:
		var from := route[i]
		var length := from.distance_to(route[i + 1])
		if length <= 0.0:
			continue
		var direction := (route[i + 1] - from) / length
		var along := 0.0
		while along < length:
			var phase := fmod(walked + along, period)
			var step := minf((dash - phase) if phase < dash else (period - phase), length - along)
			if phase < dash:
				found.append(PackedVector2Array([from + direction * along, from + direction * (along + step)]))
			along += maxf(step, 0.001)
		walked += length
	return found


func _layout() -> void:
	var positions: Array[Vector3] = []
	for row in rows:
		positions.append(row.position())
	var sizes: Array[Vector2] = []
	for node in _nodes:
		node.size = node.get_combined_minimum_size()
		sizes.append(node.size)
	var panel := _panel_size()
	var aspect := snappedf(panel.x / panel.y, 0.1) if panel.y > 0.0 else 2.4
	layout = NetworkLayout.arrange(positions, cables, sizes, NODE_TOP, aspect)
	for i in _nodes.size():
		_nodes[i].position = layout.rects[i].position
		_align(_nodes[i], layout.sides[i])
	# A Control is culled by its own rect: the content's covers everything it draws.
	content.size = layout.bounds.size
	content.queue_redraw()
	view.set_content(layout.bounds)
	if not _try_fit():
		_apply_view()


# Name and status aligned on the bus side of the node's box (centred on a hub).
func _align(node: Control, side: int) -> void:
	var flags := Control.SIZE_SHRINK_CENTER
	var alignment := HORIZONTAL_ALIGNMENT_CENTER
	if side < 0:
		flags = Control.SIZE_SHRINK_END
		alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif side > 0:
		flags = Control.SIZE_SHRINK_BEGIN
		alignment = HORIZONTAL_ALIGNMENT_LEFT
	var status := node.get_node(^"Status") as Label
	(node.get_node(^"Button") as Control).size_flags_horizontal = flags
	status.size_flags_horizontal = flags
	status.horizontal_alignment = alignment


func _try_fit() -> bool:
	if not _fit_pending or layout == null or rows.is_empty() or _panel_size().x <= 0.0:
		return false
	fit_view()
	return true


func _on_resized() -> void:
	if _fitted:
		_fit_pending = true
	if _try_fit():
		return
	view.resize(_panel_size())
	_apply_view()


func _panel_size() -> Vector2:
	return size.max(custom_minimum_size)


func _apply_view() -> void:
	if view.panel == Vector2.ZERO:
		view.panel = _panel_size()
	content.position = view.offset
	content.scale = Vector2.ONE * view.zoom
	_place_menu()


func _node(row: NetworkRow) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var node_button := Button.new()
	node_button.text = row.name
	node_button.focus_mode = Control.FOCUS_NONE
	node_button.add_theme_font_size_override(&"font_size", 13)
	node_button.name = "Button"
	# Pass: a drag that starts on a node moves the map, the wheel over a node zooms.
	node_button.mouse_filter = Control.MOUSE_FILTER_PASS
	var color := DeckStyle.row_color(row)
	var style := StyleBoxFlat.new()
	style.bg_color = NODE_FILL
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	_styles.append(style)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		node_button.add_theme_stylebox_override(state, style)
	node_button.add_theme_color_override(&"font_color", DeckStyle.TEXT_COLOR if row.online else color)
	node_button.add_theme_color_override(&"font_hover_color", DeckStyle.TITLE_COLOR)
	node_button.pressed.connect(_on_node_pressed.bind(row.device))
	box.add_child(node_button)
	var status := DeckStyle.label(_short_status(row), color, 11)
	status.name = "Status"
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cables pass under the nodes: the status line hides them.
	var backing := StyleBoxFlat.new()
	backing.bg_color = BACKGROUND
	backing.set_content_margin_all(1)
	status.add_theme_stylebox_override(&"normal", backing)
	box.add_child(status)
	return box


# The node's status line: its address (if any), then its words without "online" (offline devices
# say "offline").
func _short_status(row: NetworkRow) -> String:
	var words := PackedStringArray()
	if not row.address.is_empty():
		words.append(row.address)
	var states := PackedStringArray()
	for word in row.status:
		if word != DeviceStatus.ONLINE:
			states.append(word)
	words.append(DeckStyle.status_text(states) if not states.is_empty() else DeviceStatus.ONLINE)
	return DeckStyle.status_text(words)


func _on_node_pressed(device: Device) -> void:
	if _dragging:
		return
	var index := _index_of(device)
	if index >= 0:
		_open_menu(index)


func _open_menu(index: int) -> void:
	selected = rows[index].device
	_update_menu()
	selection_changed.emit(selected)


func _update_menu() -> void:
	var index := _index_of(selected) if is_instance_valid(selected) else -1
	_restyle(index)
	menu.visible = index >= 0
	if index < 0:
		return
	var row := rows[index]
	menu.custom_minimum_size.x = menu_width
	menu_status.custom_minimum_size.x = menu_width - 20.0
	menu_title.text = row.name
	var words := PackedStringArray([row.address]) if not row.address.is_empty() else PackedStringArray()
	words.append_array(row.status)
	menu_status.text = DeckStyle.status_text(words)
	menu_status.add_theme_color_override(&"font_color", DeckStyle.row_color(row))
	for child in _menu_buttons.get_children():
		DeckStyle.discard(child)
	if menu_builder.is_valid():
		menu_builder.call(row, _menu_buttons)
		_place_menu()
		return
	for command in row.commands:
		var text := String(command.trim_prefix("command.")).capitalize()
		if command_label.is_valid():
			text = str(command_label.call(command))
		var command_button := DeckStyle.button(text, 14)
		command_button.pressed.connect(func() -> void: command_pressed.emit(command, row.device))
		_menu_buttons.add_child(command_button)
	if row.commands.is_empty():
		var reason := "No connection." if not row.online else "No commands."
		_menu_buttons.add_child(DeckStyle.label(reason, DeckStyle.DIM_COLOR, 13))
	_place_menu()


# Node outlines: the owner's own device thick blue, the others their row colour (a disabled one
# red-tinted inside); the selected one white and lighter inside (readable on every colour).
func _restyle(selected_index: int) -> void:
	for i in mini(_styles.size(), rows.size()):
		var style := _styles[i]
		var row := rows[i]
		style.border_color = DeckStyle.SELF_COLOR if row.is_self else DeckStyle.row_color(row)
		style.set_border_width_all(3 if row.is_self else 1)
		style.bg_color = DISABLED_FILL if row.disabled else NODE_FILL
		if i == selected_index:
			style.border_color = Color.WHITE
			style.set_border_width_all(3 if row.is_self else 2)
			style.bg_color = SELECTED_FILL


# Beside the selected node as shown, inside the panel; it follows the node when the view moves.
# Places, each slid inside the panel: the node's outer side (away from its bus, where its column has
# no neighbours), below, above, the bus side (a hub: below, right, left, above); the first that does
# not cover the node wins, else the first.
func _place_menu() -> void:
	var index := _index_of(selected) if is_instance_valid(selected) else -1
	if index < 0 or index >= _nodes.size():
		return
	menu.reset_size()
	var panel := _panel_size()
	var menu_size := menu.get_combined_minimum_size()
	menu.size = menu_size
	var box := view.rect_to_screen(Rect2(_nodes[index].position, _nodes[index].size))
	var middle := box.get_center()
	var below := Vector2(middle.x - menu_size.x * 0.5, box.end.y + MENU_GAP)
	var above := Vector2(middle.x - menu_size.x * 0.5, box.position.y - MENU_GAP - menu_size.y)
	var right := Vector2(box.end.x + MENU_GAP, box.position.y)
	var left := Vector2(box.position.x - MENU_GAP - menu_size.x, box.position.y)
	var side := layout.sides[index] if layout != null and index < layout.sides.size() else 0
	var candidates: Array[Vector2] = [below, right, left, above]
	if side > 0:
		candidates = [right, below, above, left]
	elif side < 0:
		candidates = [left, below, above, right]
	var limit := (panel - menu_size).max(Vector2.ZERO)
	var at := candidates[0].clamp(Vector2.ZERO, limit)
	for candidate in candidates:
		var slid := candidate.clamp(Vector2.ZERO, limit)
		if not Rect2(slid, menu_size).intersects(box):
			at = slid
			break
	menu.position = at


func _index_at(point: Vector2) -> int:
	var at := view.to_content(point)
	for i in range(_nodes.size() - 1, -1, -1):
		if Rect2(_nodes[i].position, _nodes[i].size).has_point(at):
			return i
	return -1


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
