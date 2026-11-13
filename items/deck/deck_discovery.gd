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
## `seen` [device keys: Device.device_id, ADR 0141], `scanned` [subnets]. EventLog:
## `deck.scan {subnet}`.
## Saves from before ADR 0141 kept entity node paths where the keys are: migrated_key() turns one
## into its device's key once the path resolves (the deck's lists and crack tables do it as they
## read them).

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
	var seen_changed := _migrate(seen)
	for device in _connected:
		var subnet := DeviceNetwork.subnet_of(device)
		var shown := scanned.has(String(subnet)) or Router.of(device.entity) != null
		if not shown and not scans.has(subnet):
			_start_scan(subnet)
		if shown:
			var key := DeckDiscovery.key_of(device)
			if not seen.has(key):
				seen.append(key)
				seen_changed = true
	if seen_changed:
		stack.state[SEEN] = seen
	# Only the seen devices on the entry point's physical network: the deck remembers the others.
	var network := DeviceNetwork.physical_network(source.device)
	_map.clear()
	var by_key := DeckDiscovery.devices_by_key(tree)
	for key: String in seen:
		var device: Device = by_key.get(key, null)
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


## The key the deck keeps state about `device` under (Device.device_id; "" for none).
static func key_of(device: Device) -> String:
	if device == null or not is_instance_valid(device):
		return ""
	return device.device_id


## Every device in `tree` by its key.
static func devices_by_key(tree: SceneTree) -> Dictionary[String, Device]:
	var found: Dictionary[String, Device] = {}
	for device in Device.all(tree):
		if not device.device_id.is_empty() and not found.has(device.device_id):
			found[device.device_id] = device
	return found


## The key a saved `key` stands for: itself, unless it is an entity node path from a save made
## before ADR 0141 that resolves in `context`'s tree to a device (its key then). An unresolved
## path stays as it is (it matches no device).
static func migrated_key(context: Node, key: String) -> String:
	if not key.begins_with("/") or context == null or not context.is_inside_tree():
		return key
	var device := Device.of(context.get_node_or_null(NodePath(key)))
	return key_of(device) if device != null and not device.device_id.is_empty() else key


## Renames the keys of `table` whose device part (before `separator`, or the whole key) is a
## pre-ADR 0141 node path (migrated_key()); true when one changed.
static func migrate_keys(table: Dictionary, context: Node, separator: String = "") -> bool:
	var changed := false
	for saved: Variant in table.keys():
		var key := str(saved)
		if not key.begins_with("/"):
			continue
		var cut := key.find(separator) if not separator.is_empty() else -1
		var path := key.substr(0, cut) if cut >= 0 else key
		var device_key := migrated_key(context, path)
		if device_key != path:
			table[device_key + (key.substr(cut) if cut >= 0 else "")] = table[saved]
			table.erase(saved)
			changed = true
	return changed


func _start_scan(subnet: StringName) -> void:
	scans[subnet] = _session.config.scan_time
	var who := EntityNames.log_name(_session.entity)
	EventLog.record(EventKinds.DECK_SCAN, who, String(subnet), {"subnet": String(subnet)})
	Tracer.report_subnet(_session.get_tree(), subnet, _session.entity, _session.source)


# Turns the pre-ADR 0141 node paths of `keys` into device keys; true when one changed.
func _migrate(keys: Array[String]) -> bool:
	var changed := false
	for i in keys.size():
		var key := DeckDiscovery.migrated_key(_session, keys[i])
		if key != keys[i]:
			keys[i] = key
			changed = true
	return changed


func _list(key: String) -> Array[String]:
	var found: Array[String] = []
	var stack := _session.stack
	if stack == null:
		return found
	for item: Variant in stack.state.get(key, []) as Array:
		found.append(str(item))
	return found
