class_name DeckMapView
extends Control
## The deck's Map tool (ADR 0112, 0113, 0121): a NetworkGraph of DeckSession.map_devices() (amber:
## access, grey: out of reach), each box with its kind's colour strip and icon (DeviceKinds) and its
## status light's square (ADR 0130: show_kind_and_light()), plus the devices whose
## subnet is being scanned (DeckSession.scanning: laid out unseen, the graph draws the scan), the
## network the deck is plugged into only; unplugged (from the Wi-Fi key screen) it draws nothing and
## says UNPLUGGED_NOTE. A device's menu: DeckDeviceMenu. Drag pans, the wheel zooms, F fits. It
## rebuilds its nodes only when what they show changes (signature()), so a still cursor keeps its
## hover. A device whose wireless link is jammed (M14b) stays on the Map (the physical network),
## its square blinking amber and its words JAMMED_WORD.

## A jammed device's status words on the Map.
const JAMMED_WORD: String = "jammed"
const HINT: String = "Click a device. Amber: you have access. Drag to pan, wheel to zoom, F to fit. Esc: lower the deck"
## What the Map says while the deck is not plugged in (it draws nothing).
const UNPLUGGED_NOTE: String = "Plug the deck into a device to see its network."

var session: DeckSession
var ice: IcebreakerTool
var graph: NetworkGraph
var menu := DeckDeviceMenu.new()
## The line while unplugged (UNPLUGGED_NOTE).
var unplugged_label: Label

var kinds: DeviceKinds = DeviceKinds.shipped()

var _signature: String = ""
var _fit_on_show: bool = true


func _init() -> void:
	name = "Map"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	graph = NetworkGraph.new()
	graph.name = "Graph"
	graph.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The deck's frame paints the body behind it (the graph's own backdrop would cover the frame's
	# rounded corner).
	graph.draw_backdrop = false
	graph.menu_width = DeckDeviceMenu.WIDTH
	graph.menu_builder = menu.build
	add_child(graph)
	var inset := float(WindowFrame.metric(&"inset"))
	var hint := DeckStyle.mono(HINT, DeckStyle.DIM_COLOR, 12)
	hint.name = "Hint"
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = inset
	hint.offset_top = -inset - 12.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	unplugged_label = DeckStyle.label(UNPLUGGED_NOTE, DeckStyle.DIM_COLOR, 15)
	unplugged_label.name = "Unplugged"
	unplugged_label.set_anchors_preset(Control.PRESET_CENTER)
	unplugged_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	unplugged_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	unplugged_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unplugged_label.visible = false
	add_child(unplugged_label)


func bind(p_session: DeckSession, p_ice: IcebreakerTool) -> void:
	session = p_session
	ice = p_ice
	menu.bind(session, ice)
	_signature = ""


## Forgets what it shows: the next refresh rebuilds the nodes.
func invalidate() -> void:
	_signature = ""


## Closes the menu and fits the view once the next rows arrive.
func reset() -> void:
	_signature = ""
	graph.close_menu()
	_fit_on_show = true
	graph.request_fit()


func refresh() -> void:
	unplugged_label.visible = not session.is_plugged()
	var rows := map_rows()
	graph.scans = scan_state()
	var signature := signature_of(rows)
	if signature == _signature:
		return
	_signature = signature
	graph.subnets = Router.subnet_info(get_tree())
	graph.show_network(rows, cables_of(rows))
	if _fit_on_show and not rows.is_empty():
		_fit_on_show = false
		graph.request_fit()


## The rows the Map shows now.
func map_rows() -> Array[NetworkRow]:
	var rows: Array[NetworkRow] = []
	if session == null:
		return rows
	var reached := session.reached_devices()
	var shown := session.map_devices()
	var pending := session.scanning.duplicate()
	shown.append_array(pending)
	for device in shown:
		if not is_instance_valid(device) or not is_instance_valid(device.entity):
			continue
		var row := NetworkRow.new()
		row.scanning = pending.has(device)
		row.device = device
		row.name = NetworkSource.display_name(device)
		row.is_self = device == session.port
		row.online = reached.has(device) or (row.is_self and device.is_up())
		show_kind_and_light(row, kinds)
		row.show_words(DeviceStatus.words_of(device.entity, row.online))
		if row.light == StatusLight.State.JAMMED:
			row.status = PackedStringArray([JAMMED_WORD])
		row.disabled = row.online and DeviceStatus.is_disabled(device.entity)
		row.has_view = DeviceStatus.has_view(device.entity)
		row.access = session.has_access(device)
		place_in_network(row, device)
		rows.append(row)
	return rows


## Subnet -> (progress 0..1, seconds left) of each scan running now (DeckSession.scans).
func scan_state() -> Dictionary[StringName, Vector2]:
	var found: Dictionary[StringName, Vector2] = {}
	if session == null:
		return found
	var total := maxf(session.config.scan_time, 0.001)
	for subnet: StringName in session.scans:
		var left := session.scans[subnet]
		found[subnet] = Vector2(clampf(1.0 - left / total, 0.0, 1.0), left)
	return found


## Fills `row`'s look in the device language (ADR 0130) from its device's kind (`kinds`, found by
## tags: icon and colour; none without a kind) and its status light (NetworkRow.light_of(), with
## `row.online` as reached).
static func show_kind_and_light(row: NetworkRow, kinds: DeviceKinds) -> void:
	var kind := kinds.kind_for(row.device.entity) if is_instance_valid(row.device) else null
	row.icon = kind.icon if kind != null else PackedStringArray()
	row.kind_color = kind.color if kind != null else Color.TRANSPARENT
	row.light = NetworkRow.light_of(row.device, row.online)


## Fills `row`'s network place from `device`: its address, its subnet and, for a router, the
## subnets it joins, both addresses and the word "router" (ADR 0112 amendment).
static func place_in_network(row: NetworkRow, device: Device) -> void:
	row.address = device.address
	row.subnet = DeviceNetwork.subnet_of(device)
	if AccessPoint.of(device.entity) != null:
		row.role = "access point"
	var router := Router.of(device.entity)
	if router == null:
		return
	row.joins = router.subnets()
	row.role = "router"
	var addresses := router.addresses()
	if not addresses.is_empty():
		row.address = " · ".join(addresses)


## The cables and wireless links between `rows`, as index pairs (lower first), each once.
static func cables_of(rows: Array[NetworkRow]) -> Array[Vector2i]:
	var index_of: Dictionary[Device, int] = {}
	for i in rows.size():
		index_of[rows[i].device] = i
	var pairs: Array[Vector2i] = []
	for i in rows.size():
		var ends := rows[i].device.linked()
		if rows[i].device.wireless_link() != null:
			ends.append(rows[i].device.wireless_link())
		for other in ends:
			if not index_of.has(other):
				continue
			var pair := Vector2i(mini(i, index_of[other]), maxi(i, index_of[other]))
			if not pairs.has(pair):
				pairs.append(pair)
	return pairs


## What the map's nodes and their menus show: a change rebuilds them.
func signature_of(rows: Array[NetworkRow]) -> String:
	var parts := PackedStringArray()
	for row in rows:
		var progress := 0.0
		var accounts := DeviceAccounts.of(row.device.entity)
		if accounts != null:
			for each in accounts.accounts:
				progress += ice.saved_progress(row.device, each.user)
		(
			parts
			. append(
				(
					"%s|%s|%s|%s|%s|%d|%s|%d"
					% [
						row.name,
						row.online,
						row.access,
						row.disabled,
						" ".join(row.status),
						roundi(progress * 20.0),
						session.is_blocked(row.device),
						row.light,
					]
				)
			)
		)
		(
			parts
			. append(
				(
					"%s|%s|%s|%d"
					% [
						row.scanning,
						row.device.is_admin(session.entity),
						DeckSession.has_scanned(session.stack, row.subnet),
						ExploitItems.count(session.entity, ExploitItems.kind_of(row.device)),
					]
				)
			)
		)
	parts.append(str(Icebreaker.assist(session.entity)))
	parts.append(str(Icebreaker.max_strength(session.entity)))
	return "\n".join(parts)
