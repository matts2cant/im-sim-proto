class_name NetworkGraph
extends Control
## A network map (ADR 0083, 0099; the deck's Map since ADR 0113, moved from ui/terminal/): one node
## (NetworkNodeBox) per NetworkRow its owner gives it (the deck's discovered devices; the M8
## terminal's network), grouped by the hub it hangs on and placed by NetworkLayout; the subnet boxes
## and cables behind them (NetworkMapPainter), the owner's own device outlined.
## The map pans and zooms (NetworkView): drag the background with the left or middle mouse button
## to move it (a press on a node or the menu never drags; a press becomes a drag past DRAG_THRESHOLD
## px), the wheel zooms around the cursor, fit_view() (the Fit button, F on the screen) shows the whole
## network; it opens fitted (request_fit()). The nodes, their labels and the cables live in
## `content`, a child scaled and moved by the view; the menu and the Fit button stay in the panel.
## Subnets (ADR 0112 amendment): the nodes are laid out by their row's subnet; each subnet with data
## in `subnets` (Subnet: name, range, colour) is a box behind its devices; a router row (it joins
## two subnets or more) stands between the boxes, "router" after its name. A subnet shows its box
## only while one of its devices is on the map.
## Scans (ADR 0121): a row whose subnet is being scanned (NetworkRow.scanning) is laid out where it
## will appear but not drawn; its subnet's box is drawn dashed and blinking with "Scanning <NAME>
## <range>…", a progress bar and the seconds left (`scans`), and a marching dashed link from the
## router that leads there (NetworkMapPainter). The map animates while a scan shows.
## Wireless links (M12b, ADR 0117): a cable whose rows' devices are linked by radio
## (Device.wireless_link(): `wireless`) is laid out like a cable (so wireless devices sit with their
## access point) and drawn dashed in WIRELESS_COLOR.
## Clicking a node (without dragging) opens its menu (NetworkMenu) beside it: by default one button
## per command of its row (`command_pressed`); an owner with `menu_builder` fills it itself (the
## deck). Clicking the background closes it; `selection_changed` tells the owner.
## Refreshes keep the widgets under the cursor: show_network() rebuilds the nodes only when what they
## draw changed, and the menu reconciles its buttons, so a click held on one survives the owner's
## refresh.

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
## The backdrop's edge line.
const EDGE_COLOR: Color = Color(0.15, 0.375, 0.33, 0.9)
## A node box's fill, a disabled node's (tinted red: a second cue beside the outline), and the
## selected node's (with a white outline).
const NODE_FILL: Color = Color(0.04, 0.1, 0.1, 1.0)
const DISABLED_FILL: Color = Color(0.22, 0.08, 0.08, 1.0)
const SELECTED_FILL: Color = Color(0.13, 0.22, 0.22, 1.0)
const LIVE_CABLE_COLOR: Color = Color(0.3375, 0.7125, 0.45)
## A wireless link's colour (the mockup's light blue #7fd4ff) and dashes (content px).
const WIRELESS_COLOR: Color = Color(0.498, 0.831, 1.0)
const WIRELESS_DASH: float = 6.0
const WIRELESS_GAP: float = 5.0
## A subnet box's fill and border opacity (its colour from its Subnet), its corner radius.
const SUBNET_FILL_ALPHA: float = 0.1
const SUBNET_BORDER_ALPHA: float = 0.55
const SUBNET_RADIUS: int = 8
const SUBNET_TITLE_SIZE: int = 14

## Command -> button label for the default menu (empty: the words after `command.`).
var command_label: Callable = Callable()
## Fills the menu below its title and status: Callable(row: NetworkRow, column: VBoxContainer);
## empty: one button per command of the row.
var menu_builder: Callable = Callable()
## The menu's width (px).
var menu_width: float = MENU_WIDTH
var rows: Array[NetworkRow] = []
var cables: Array[Vector2i] = []
## The indices of the cables that are wireless links (show_network() finds them).
var wireless: PackedInt32Array = PackedInt32Array()
## Subnet id -> its data (Router.subnet_info()): the subnets drawn as boxes.
var subnets: Dictionary[StringName, Subnet] = {}
## Subnet id -> (progress 0..1, seconds left) of the scans the map shows (set by the owner).
var scans: Dictionary[StringName, Vector2] = {}
## The subnets of the last layout, in region order (layout.region_rects).
var region_ids: Array[StringName] = []
## Subnet id -> its box as drawn now (content coordinates), for each subnet with data and devices on
## the map: {"rect": Rect2, "color": Color (its Subnet's), "title": String, "title_rect": Rect2,
## "scanning": bool (every device in it is being scanned: drawn as the scan)}.
var subnet_boxes: Dictionary[StringName, Dictionary] = {}
## Paints BACKGROUND and an edge line behind the map (off inside a WindowFrame, which paints its
## body itself).
var draw_backdrop: bool = true
## The device whose menu is open (null: none).
var selected: Device
var view := NetworkView.new()
## The last placement (null before the first network).
var layout: NetworkLayout
## Holds the nodes and draws the cables; moved and scaled by `view`.
var content: Control

## The device menu (a PanelContainer); its title and status labels.
var menu: NetworkMenu
var menu_title: Label
var menu_status: Label
var fit_button: Button

var _nodes: Array[NetworkNodeBox] = []
# Per region: its title (null for a subnet without data).
var _titles: Array[Control] = []
# Fit at the next chance (the panel has a size and a network).
var _fit_pending: bool = true
# The view is as fit_view() left it: a resize fits again.
var _fitted: bool = false
# Where the left or middle button went down (INF: not down), the last drag point, and whether the
# press became a drag.
var _press_at: Vector2 = Vector2.INF
var _drag_last: Vector2 = Vector2.ZERO
var _dragging: bool = false
# What the nodes, cables and subnet boxes show (show_network() rebuilds them only when it changes).
var _drawn: String = ""


func _ready() -> void:
	# Its widgets' looks (DeckButton, DeckCard): also when shown outside the deck's frame.
	theme = WindowFrame.THEME
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.draw.connect(func() -> void: NetworkMapPainter.paint(self))
	add_child(content)
	menu = NetworkMenu.new(menu_width)
	menu.command_pressed.connect(command_pressed.emit)
	menu_title = menu.title
	menu_status = menu.status
	add_child(menu)
	fit_button = DeckStyle.button("Fit", 13)
	fit_button.name = "Fit"
	fit_button.tooltip_text = "Show the whole network (F)"
	fit_button.z_index = 1
	var margin := WindowFrame.metric(&"space_s")
	fit_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, margin)
	fit_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fit_button.pressed.connect(fit_view)
	add_child(fit_button)


## Shows `p_rows` (NetworkRow, typed or not: the deck's rows) and their
## `p_cables` (index pairs into them); `p_labels`: the default menu's command labels (command ->
## label, such as a DeckConfig's `label_for`; an empty Callable keeps them). An open menu stays open
## on the same device and shows its new status. The view stays where it is (see request_fit()).
func show_network(p_rows: Array, p_cables: Array[Vector2i], p_labels: Callable = Callable()) -> void:
	rows = NetworkRow.list(p_rows)
	cables = p_cables
	wireless = NetworkRow.wireless_cables(rows, cables)
	if p_labels.is_valid():
		command_label = p_labels
	# Nothing drawn changed (an owner's periodic refresh): the nodes stay, so a click held on one
	# survives it.
	var key := NetworkMapInputs.drawn_key(rows, cables, wireless, subnets, _panel_size())
	if key == _drawn and _nodes.size() == rows.size():
		if is_instance_valid(selected) and _index_of(selected) < 0:
			selected = null
		_update_menu()
		return
	_drawn = key
	for node in _nodes:
		DeckStyle.discard(node)
	for title in _titles:
		if title != null:
			DeckStyle.discard(title)
	_nodes.clear()
	_titles.clear()
	for i in rows.size():
		var node := NetworkNodeBox.new(rows[i])
		node.button.pressed.connect(_on_node_pressed.bind(rows[i].device))
		# Laid out where it will appear, not drawn until its subnet is scanned.
		node.visible = not rows[i].scanning
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


## The names of the nodes drawn (not the ones being scanned), in row order.
func node_names() -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		if not row.scanning:
			names.append(row.name)
	return names


## The subnets whose box in `graph` shows a scan now.
static func scanning_subnets(graph: NetworkGraph) -> Array[StringName]:
	var found: Array[StringName] = []
	for id: StringName in graph.subnet_boxes:
		if graph.subnet_boxes[id].get("scanning", false):
			found.append(id)
	return found


## The router row in `graph` that `subnet`'s scan link starts from (a drawn router joining it), or
## null.
static func scan_router(graph: NetworkGraph, subnet: StringName) -> NetworkRow:
	for row in graph.rows:
		if row.is_between() and not row.scanning and row.joins.has(subnet):
			return row
	return null


## The node button of `device_name`, or null.
func node_button(device_name: String) -> Button:
	var index := _index_by_name(device_name)
	return _nodes[index].button if index >= 0 else null


## The status line under the node of `device_name` ("" when there is none).
func node_status(device_name: String) -> String:
	var index := _index_by_name(device_name)
	return _nodes[index].status.text if index >= 0 else ""


## The outline colour of the node of `device_name` as drawn (white while selected), or black.
func node_color(device_name: String) -> Color:
	var index := _index_by_name(device_name)
	return _nodes[index].style.border_color if index >= 0 else Color.BLACK


## The colour of the status line under the node of `device_name`, or black.
func node_status_color(device_name: String) -> Color:
	var index := _index_by_name(device_name)
	if index < 0:
		return Color.BLACK
	return _nodes[index].status.get_theme_color(&"font_color")


## The open menu's command button `label`, or null.
func menu_button(label: String) -> Button:
	return menu.button(label)


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
				# Only the background drags: a press on a node is its button's click.
				_press_at = button.position if _index_at(button.position) < 0 else Vector2.INF
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
	if draw_backdrop:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
		draw_rect(Rect2(Vector2.ZERO, size), EDGE_COLOR, false, 1.0)


## True when cable `k` joins two online devices (drawn solid; else dashed). A disabled end does not
## matter: the link works (commands reach the device, the player can enable it again).
func cable_live(k: int) -> bool:
	if k < 0 or k >= cables.size() or cables[k].x >= rows.size() or cables[k].y >= rows.size():
		return false
	return rows[cables[k].x].online and rows[cables[k].y].online


## The colour cable `k` is drawn in: green while live (light blue for a wireless link), the offline
## grey otherwise.
func cable_color(k: int) -> Color:
	if not cable_live(k):
		return DeckStyle.OFFLINE_COLOR
	return WIRELESS_COLOR if wireless.has(k) else LIVE_CABLE_COLOR


## `route` cut into dashes of `dash` px with `gap` px between them, as [from, to] pairs.
static func dashes(route: PackedVector2Array, dash: float, gap: float) -> Array[PackedVector2Array]:
	return NetworkMapPainter.dashes(route, dash, gap)


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
	var regions := NetworkMapInputs.regions(rows, region_ids)
	var titles: Array[Vector2] = []
	for id in region_ids:
		var title := _title(id)
		_titles.append(title)
		titles.append(title.get_combined_minimum_size() if title != null else Vector2.ZERO)
	layout = NetworkLayout.arrange(positions, cables, sizes, NODE_TOP, aspect, regions, titles)
	for i in _nodes.size():
		_nodes[i].position = layout.rects[i].position
		_nodes[i].align(layout.sides[i])
	subnet_boxes.clear()
	for r in _titles.size():
		if _titles[r] == null or not layout.region_rects[r].has_area():
			continue
		var scanning := _all_scanning(region_ids[r])
		# A scan draws its own words in the box (NetworkMapPainter).
		_titles[r].visible = not scanning
		_titles[r].position = layout.title_positions[r]
		_titles[r].size = titles[r]
		var words := PackedStringArray()
		for child in _titles[r].get_children():
			words.append((child as Label).text)
		subnet_boxes[region_ids[r]] = {
			"rect": layout.region_rects[r],
			"color": subnets[region_ids[r]].map_color,
			"title": " ".join(words),
			"title_rect": Rect2(_titles[r].position, _titles[r].size),
			"scanning": scanning,
		}
	# A Control is culled by its own rect: the content's covers everything it draws.
	content.size = layout.bounds.size
	content.queue_redraw()
	view.set_content(layout.bounds)
	if not _try_fit():
		_apply_view()


# True when subnet `id` has members on the map and every one of them is being scanned.
func _all_scanning(id: StringName) -> bool:
	var members := 0
	for row in rows:
		if row.is_between() or row.subnet != id:
			continue
		if not row.scanning:
			return false
		members += 1
	return members > 0


func _process(_delta: float) -> void:
	# The scan boxes blink and their links march.
	if content != null and not NetworkGraph.scanning_subnets(self).is_empty():
		content.queue_redraw()


# The title of subnet `id`'s box (in the content), or null without data.
func _title(id: StringName) -> Control:
	var data: Subnet = subnets.get(id)
	if data == null:
		return null
	var line := NetworkMapPainter.subnet_title(id, data)
	content.add_child(line)
	return line


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
	for i in mini(_nodes.size(), rows.size()):
		_nodes[i].restyle(rows[i], i == index)
	menu.visible = index >= 0
	if index < 0:
		return
	menu.show_row(rows[index], menu_width, menu_builder, command_label)
	_place_menu()


# Beside the selected node as shown, inside the panel; it follows the node when the view moves.
func _place_menu() -> void:
	var index := _index_of(selected) if is_instance_valid(selected) else -1
	if index < 0 or index >= _nodes.size():
		return
	var box := view.rect_to_screen(Rect2(_nodes[index].position, _nodes[index].size))
	var side := layout.sides[index] if layout != null and index < layout.sides.size() else 0
	menu.place(box, side, _panel_size())


func _index_at(point: Vector2) -> int:
	var at := view.to_content(point)
	for i in range(_nodes.size() - 1, -1, -1):
		if _nodes[i].visible and Rect2(_nodes[i].position, _nodes[i].size).has_point(at):
			return i
	return -1


func _index_of(device: Device) -> int:
	for i in rows.size():
		if rows[i].device == device:
			return i
	return -1


func _index_by_name(device_name: String) -> int:
	for i in rows.size():
		if rows[i].name == device_name and not rows[i].scanning:
			return i
	return -1
