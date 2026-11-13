class_name DeckDiscovery
extends RefCounted
## Part of DeckSession (Q17, ADR 0140): the deck's Map (ADR 0112, 0121). Every device the deck's
## traffic reaches (through the routers it has hacked: Router), plus the dead ones right behind them:
## on the subnet the deck is plugged into or joined (the entry point's) at once, on a subnet behind a
## router once that subnet has been scanned (`config.scan_time` s, +10 % trace on the tracers
## watching it, once per subnet: kept on the deck; `scans` and `scanning` let the Map show the
## scan), and routers at once. Devices seen once stay on the map (greyed when out of reach). The Map
## draws only the seen devices on the physical network of the entry point (the jack, the access
## point joined, the port's device: DeviceNetwork.physical_network(), cables and holding wireless
## links, up or down, whatever the routers' rules): another network the deck has seen stays
## remembered and shows again once the deck is plugged in there.
## Discovery lives in the deck's stack `state` (saved with the inventory, travelling with the item):
## `seen` [device paths], `scanned` [subnets]. EventLog: `deck.scan {subnet}`.

const SEEN: String = "seen"
const SCANNED: String = "scanned"

## Subnets being scanned -> seconds left.
var scans: Dictionary[StringName, float] = {}
## Read only: the devices on the entry point's network whose subnet is being scanned (at the last
## refresh): the Map lays them out unseen and shows the scan where they will appear.
var scanning: Array[Device] = []

var _session: DeckSession
# The last discovery: devices the traffic reaches, those plus the dead ones behind (connected), and
# every device on the map (seen).
var _reached: Array[Device] = []
var _connected: Array[Device] = []
var _map: Array[Device] = []


func _init(p_session: DeckSession) -> void:
	_session = p_session


## Forgets the last discovery and the scans running (the deck was unplugged); the deck's stack keeps
## what it has seen and scanned.
func clear() -> void:
	scans.clear()
	_reached.clear()
	_connected.clear()
	_map.clear()
	scanning.clear()


## Discovers again from the session's connection: reach, scans to start, the map.
func refresh() -> void:
	var tree := _session.get_tree()
	var source := _session.source
	var stack := _session.stack
	_connected = source.connected(tree)
	_reached = source.reached(tree)
	# The entry point's subnet needs no scan (ADR 0121): it shows at once, no trace.
	var entry := DeviceNetwork.subnet_of(_session.port)
	var scanned := _list(SCANNED)
	if not scanned.has(String(entry)):
		scanned.append(String(entry))
		stack.state[SCANNED] = scanned
	var seen := _list(SEEN)
	var seen_changed := false
	for device in _connected:
		var subnet := DeviceNetwork.subnet_of(device)
		var shown := scanned.has(String(subnet)) or Router.of(device.entity) != null
		if not shown and not scans.has(subnet):
			_start_scan(subnet)
		if shown:
			var path := DeckDiscovery.path_of(device)
			if not seen.has(path):
				seen.append(path)
				seen_changed = true
	if seen_changed:
		stack.state[SEEN] = seen
	# Only the seen devices on the entry point's physical network: the deck remembers the others.
	var network := DeviceNetwork.physical_network(source.device)
	_map.clear()
	for path: String in seen:
		var device := Device.of(_session.get_node_or_null(NodePath(path)))
		if device != null and network.has(device) and not _map.has(device):
			_map.append(device)
	scanning.clear()
	for device in _connected:
		if scans.has(DeviceNetwork.subnet_of(device)) and network.has(device) and not _map.has(device):
			scanning.append(device)


## Advances the scans by `delta` s; true when one finished (its subnet is now scanned).
func step_scans(delta: float) -> bool:
	var done := false
	for subnet: StringName in scans.keys():
		var left: float = scans[subnet] - delta
		if left > 0.0:
			scans[subnet] = left
			continue
		scans.erase(subnet)
		var scanned := _list(SCANNED)
		if not scanned.has(String(subnet)):
			scanned.append(String(subnet))
			_session.stack.state[SCANNED] = scanned
		done = true
	return done


## Every device on the map: seen (in the order first seen) and on the entry point's network.
func map_devices() -> Array[Device]:
	return _map.duplicate()


## The devices the deck's traffic reaches (at the last refresh).
func reached_devices() -> Array[Device]:
	return _reached.duplicate()


## The devices reached plus the dead ones right behind them (at the last refresh).
func connected_devices() -> Array[Device]:
	return _connected.duplicate()


## The subnets the router `device` joins that are neither scanned nor being scanned.
func hidden_routes(device: Device) -> int:
	var router := Router.of(device.entity) if device != null else null
	if router == null:
		return 0
	var scanned := _list(SCANNED)
	var count := 0
	for subnet in router.subnets():
		if not scanned.has(String(subnet)) and not scans.has(subnet):
			count += 1
	return count


## True when `deck_stack` has scanned `subnet` (or the deck was plugged in there).
static func has_scanned(deck_stack: ItemStack, subnet: StringName) -> bool:
	if deck_stack == null:
		return false
	return (deck_stack.state.get(SCANNED, []) as Array).has(String(subnet))


## Where the deck keeps state about `device` (its entity's node path; "" once out of the tree).
static func path_of(device: Device) -> String:
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return ""
	return String(device.entity.get_path()) if is_instance_valid(device.entity) else String(device.get_path())


func _start_scan(subnet: StringName) -> void:
	scans[subnet] = _session.config.scan_time
	var who := EntityNames.log_name(_session.entity)
	EventLog.record(EventKinds.DECK_SCAN, who, String(subnet), {"subnet": String(subnet)})
	Tracer.report_subnet(_session.get_tree(), subnet, _session.entity, _session.source)


func _list(key: String) -> Array[String]:
	var found: Array[String] = []
	var stack := _session.stack
	if stack == null:
		return found
	for item: Variant in stack.state.get(key, []) as Array:
		found.append(str(item))
	return found
