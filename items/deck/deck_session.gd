class_name DeckSession
extends Node
## Component of an actor that carries a deck (the Player; ADR 0113): the deck plugged in, its Map
## and its access, independent of the screen (DeckScreen shows it; tools keep running while it is
## lowered). The Icebreaker is its sibling IcebreakerTool.
## - Plugging: holding LMB with the deck in hand on a device with a deck port (Device.tool_hold())
##   plugs the held deck in there and raises the screen. The port decides the address
##   (NetworkSource): a wall jack joins its subnet, a maintenance port links to its device only, a
##   computer lends its address. Tethered: the deck unplugs when its user walks further than
##   `config.tether_distance` from the plugged entity (horizontal), can no longer act, or the deck
##   leaves the user's inventory; unplugging stops its tools.
## - Map (discovery, ADR 0112): every device the deck's traffic reaches (through the routers it has
##   hacked: Router), plus the dead ones right behind them, once its subnet has been scanned
##   (`config.scan_time` s, +10 % trace on the tracers watching it, once per subnet: kept on the
##   deck), and routers at once. Devices seen once stay on the map (greyed when out of reach).
##   Refreshed every `config.refresh_interval` s and after every change.
## - Accounts: log_in() with a login the user's Journal knows (no trace when right; a wrong known
##   password is a failed login). With access to a device (an account, or an exploit's grant:
##   ExploitTool, Device.has_access()): its commands (send()), and on a computer its desktop,
##   remotely (open_remote(): Computer.open_desktop(user, account, true); `remote` until
##   `desktop_closed`). As admin of a router: its firewall rules (the deck's Firewall tool). Commands
##   and remote desktops are written to the device's log with the deck's address
##   (Device.intrusion).
## - Discovery lives in the deck's stack `state` (saved with the inventory, travelling with the
##   item): `seen` [device paths], `scanned` [subnets].
## EventLog: `deck.plugged {device, port, address}`, `deck.unplugged {device, reason}`,
## `deck.scan {subnet}`, `deck.remote {device, user}`; commands log as `device.command`, logins as
## `network.login`.

## The deck was plugged in or unplugged.
signal plugged_changed(plugged: bool)
## Something the map shows changed (discovery, access, a crack): screens refresh.
signal changed
## A short message for the user ("Cracked kbrandt: added to the Journal").
signal notice(text: String)
## A remote desktop opened (the Computer) or closed (null).
signal remote_changed(computer: Computer)

const SEEN: String = "seen"
const SCANNED: String = "scanned"
const DEFAULT_CONFIG: DeckConfig = preload("res://items/deck/deck_config.tres")

@export var config: DeckConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
## The device the deck is plugged into (null: unplugged).
var port: Device
## Its traffic's source while plugged in.
var source: NetworkSource
## The deck stack plugged in.
var stack: ItemStack
## The remote desktop open (null: none).
var remote: Computer
## Subnets being scanned -> seconds left.
var scans: Dictionary[StringName, float] = {}
## Why the deck was last unplugged.
var unplug_reason: StringName = &""

# The last discovery: devices the traffic reaches, those plus the dead ones behind (connected), and
# every device on the map (seen).
var _reached: Array[Device] = []
var _connected: Array[Device] = []
var _map: Array[Device] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	entity = get_node_or_null(entity_path) as Node3D


## The DeckSession child of `node`, or null.
static func of(node: Node) -> DeckSession:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is DeckSession:
			return child as DeckSession
	return null


func is_plugged() -> bool:
	return port != null and is_instance_valid(port)


## Plugs the held deck into `device` (unless already there) and raises the screen.
func plug_and_raise(device: Device) -> void:
	if port != device and not plug(device):
		return
	var screen := DeckScreen.of(entity)
	if screen != null and not screen.is_open():
		screen.open_for(self)


## Plugs `deck_stack` (default: the deck in the user's hand) into `device`. False without a deck or
## a port.
func plug(device: Device, deck_stack: ItemStack = null) -> bool:
	if deck_stack == null:
		deck_stack = held_deck()
	if deck_stack == null or device == null or not is_instance_valid(device):
		return false
	var kind := DeviceNetwork.port_kind(device)
	if kind == Device.DeckPort.NONE or kind == Device.DeckPort.AUTO:
		return false
	if is_plugged():
		unplug(&"replugged")
	port = device
	stack = deck_stack
	unplug_reason = &""
	source = NetworkSource.for_user(entity, device, _source_kind(kind))
	var data := {"device": _name_of(device), "port": Device.DeckPort.keys()[kind], "address": source.address}
	EventLog.record(&"deck.plugged", _who(), _name_of(device), data)
	plugged_changed.emit(true)
	refresh()
	return true


## Unplugs the deck (`reason`: walked_away, cannot_act, no_deck, gone, replugged): its tools stop,
## the screen closes. Lowering the screen never unplugs.
func unplug(reason: StringName = &"unplugged") -> void:
	if port == null:
		return
	var was := port
	close_remote()
	EventLog.record(&"deck.unplugged", _who(), _name_of(was), {"device": _name_of(was), "reason": reason})
	unplug_reason = reason
	plugged_changed.emit(false)
	port = null
	source = null
	stack = null
	scans.clear()
	_reached.clear()
	_connected.clear()
	_map.clear()
	var screen := DeckScreen.of(entity)
	if screen != null and screen.is_open():
		screen.close()


## The deck stack in the user's hand, or null.
func held_deck() -> ItemStack:
	var hands := _inventory()
	if hands == null:
		return null
	var held := hands.in_hand()
	if held == null or held.item.use_action != ItemData.UseAction.EQUIP_TOOL:
		return null
	return held if held.item.tool_kind == Device.DECK_TOOL else null


func _physics_process(delta: float) -> void:
	if port == null:
		return
	var reason := _unplug_check()
	if not reason.is_empty():
		unplug(reason)
		return
	var scanned := _step_scans(delta)
	_refresh_left -= delta
	if scanned or _refresh_left <= 0.0:
		refresh()


# Why the deck must unplug now, or &"".
func _unplug_check() -> StringName:
	if not is_instance_valid(port) or not is_instance_valid(port.entity) or port.entity.is_queued_for_deletion():
		return &"gone"
	if not is_instance_valid(entity) or not ActorState.can_act(entity):
		return &"cannot_act"
	var hands := _inventory()
	if hands != null and not hands.inventory.stacks.has(stack):
		return &"no_deck"
	var flat := entity.global_position - port.entity.global_position
	flat.y = 0.0
	if flat.length() > config.tether_distance:
		return &"walked_away"
	return &""


## Discovers again (reach, scans, the map) and tells the screens.
func refresh() -> void:
	_refresh_left = config.refresh_interval
	if not is_plugged() or not is_inside_tree():
		return
	var tree := get_tree()
	_connected = source.connected(tree)
	_reached = source.reached(tree)
	var scanned := _list(SCANNED)
	var seen := _list(SEEN)
	var seen_changed := false
	for device in _connected:
		var subnet := DeviceNetwork.subnet_of(device)
		var shown := scanned.has(String(subnet)) or Router.of(device.entity) != null
		if not shown and not scans.has(subnet):
			_start_scan(subnet)
		if shown:
			var path := path_of(device)
			if not seen.has(path):
				seen.append(path)
				seen_changed = true
	if seen_changed:
		stack.state[SEEN] = seen
	_map.clear()
	for path: String in seen:
		var device := Device.of(get_node_or_null(NodePath(path)))
		if device != null and not _map.has(device):
			_map.append(device)
	changed.emit()


## Every device on the map (seen, in the order first seen).
func map_devices() -> Array[Device]:
	return _map.duplicate()


## The devices the deck's traffic reaches now (at the last refresh).
func reached_devices() -> Array[Device]:
	return _reached.duplicate()


## True when the deck can talk to `device` now: reached and not blocked by a tracer.
func is_online(device: Device) -> bool:
	if not is_plugged() or device == null or not is_inside_tree():
		return false
	return source.reaches(get_tree(), device) and not Tracer.blocks(device, source.address)


## True when a tracer watching `device` blocks the deck's address.
func is_blocked(device: Device) -> bool:
	return is_plugged() and Tracer.blocks(device, source.address)


## True when the user has access to `device` (an account, or an exploit's grant).
func has_access(device: Device) -> bool:
	return device != null and is_instance_valid(device) and device.has_access(entity)


## True when `deck_stack` has scanned `subnet` (its devices' software shows on the Map).
static func has_scanned(deck_stack: ItemStack, subnet: StringName) -> bool:
	if deck_stack == null:
		return false
	return (deck_stack.state.get(SCANNED, []) as Array).has(String(subnet))


## True when `device` is where the deck is plugged in (a jack: the jack itself).
func is_entry(device: Device) -> bool:
	return device != null and device == port


## Logs in on `device` as `user` with the password the user's Journal knows. True on success (no
## trace); a wrong known password is a failed login (+trace).
func log_in(device: Device, user: String) -> bool:
	var accounts := DeviceAccounts.of(device.entity) if device != null else null
	if accounts == null or not is_online(device) or not accounts.knows_login(entity, user):
		return false
	var ok := accounts.login_from(user, accounts.known_password(entity, user), entity, source)
	if ok:
		notice.emit(access_notice(device, "Logged in as %s" % user))
	refresh()
	return ok


## The commands of the deck's table `device` accepts, in table order.
func commands_for(device: Device) -> Array[StringName]:
	var found: Array[StringName] = []
	if device == null:
		return found
	for command: StringName in config.command_labels:
		if device.accepts(command, entity):
			found.append(command)
	return found


## Sends `command` to `device` as its account holder (a session on the device itself): only while
## online with an account there. Logged as `device.command` (from: the entry point). True when sent.
func send(command: StringName, device: Device) -> bool:
	var sent := device != null and is_online(device) and has_access(device) and device.accepts(command, entity)
	var target := _name_of(device)
	var data := {"command": command, "from": _name_of(port), "to": target, "sent": sent, "by": _who()}
	if sent:
		var stimulus := Device.command_stimulus(command, device, entity)
		StimulusSystem.emit(stimulus)
		data["stimulus"] = stimulus.id
		device.intrusion.device_log.record(DeviceLog.REMOTE, source.address, _who(), String(command))
	EventLog.record(&"device.command", _name_of(port), target, data)
	return sent


## Opens `device`'s desktop remotely (a computer the user has an account on, online). True when
## opened; the deck returns to the map when the desktop closes.
func open_remote(device: Device) -> bool:
	var computer := Computer.of(device.entity) if device != null else null
	var accounts := DeviceAccounts.of(device.entity) if device != null else null
	if computer == null or accounts == null or not is_online(device) or not has_access(device):
		return false
	close_remote()
	var user := _remote_user(device, accounts)
	device.intrusion.device_log.record(DeviceLog.LOGIN, source.address, user, "remote desktop")
	remote = computer
	computer.desktop_closed.connect(_on_desktop_closed, CONNECT_ONE_SHOT)
	EventLog.record(&"deck.remote", _who(), _name_of(device), {"device": _name_of(device), "user": user})
	remote_changed.emit(remote)
	computer.open_desktop(entity, user, true)
	return true


## Back to the map (the deck unplugged, or a caller ends it): closes the remote desktop if the
## user's ComputerScreen still shows it.
func close_remote() -> void:
	if remote == null:
		return
	var was := remote
	if is_instance_valid(was) and was.desktop_closed.is_connected(_on_desktop_closed):
		was.desktop_closed.disconnect(_on_desktop_closed)
	remote = null
	var screen := ComputerScreen.of(entity)
	if screen != null and screen.is_remote() and screen.computer == was:
		screen.close()
	remote_changed.emit(null)


## The subnets the router `device` joins that are not on the map yet (the Master assist).
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


## The tracers the screens show a bar for (Tracer.bars_for()); a bar names a tracer only once its
## host is on the map (map_devices()).
func tracers() -> Array[Tracer]:
	if not is_plugged() or not is_inside_tree():
		return [] as Array[Tracer]
	return Tracer.bars_for(get_tree(), entity, _connected, source.address)


## `text`, plus the router note when `device` is a router (its subnets now show on the map).
func access_notice(device: Device, text: String) -> String:
	if Router.of(device.entity) != null:
		return "%s. Router hacked: the subnets behind it appear on the map" % text
	return text


## Where the deck keeps state about `device` (its entity's node path; "" once out of the tree).
static func path_of(device: Device) -> String:
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return ""
	return String(device.entity.get_path()) if is_instance_valid(device.entity) else String(device.get_path())


func _step_scans(delta: float) -> bool:
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
			stack.state[SCANNED] = scanned
		done = true
	return done


func _start_scan(subnet: StringName) -> void:
	scans[subnet] = config.scan_time
	EventLog.record(&"deck.scan", _who(), String(subnet), {"subnet": String(subnet)})
	Tracer.report_subnet(get_tree(), subnet, entity, source)


func _list(key: String) -> Array[String]:
	var found: Array[String] = []
	if stack == null:
		return found
	for item: Variant in stack.state.get(key, []) as Array:
		found.append(str(item))
	return found


func _remote_user(device: Device, accounts: DeviceAccounts) -> String:
	var names := accounts.access_of(entity)
	for user in names:
		var found := accounts.account(user)
		if found != null and found.admin:
			return user
	if not names.is_empty():
		return names[0]
	# Access from an exploit: the first account of the level it granted, else the first.
	var admin := device.is_admin(entity)
	for each in accounts.accounts:
		if each != null and each.admin == admin:
			return each.user
	return accounts.accounts[0].user if not accounts.accounts.is_empty() else ""


func _on_desktop_closed() -> void:
	remote = null
	remote_changed.emit(null)


func _inventory() -> PlayerInventory:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is PlayerInventory:
			return child as PlayerInventory
	return null


static func _source_kind(kind: Device.DeckPort) -> NetworkSource.Kind:
	match kind:
		Device.DeckPort.JACK:
			return NetworkSource.Kind.JACK
		Device.DeckPort.MAINTENANCE:
			return NetworkSource.Kind.PORT
	return NetworkSource.Kind.HOST


func _name_of(device: Device) -> String:
	if device == null or not is_instance_valid(device):
		return ""
	return String(device.entity.name) if is_instance_valid(device.entity) else String(device.name)


func _who() -> String:
	return NetworkSource.user_key(entity)
