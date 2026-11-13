class_name DeckSession
extends Node
## Component of an actor that carries a deck (the Player; ADR 0113): the deck plugged in, its Map
## and its access, independent of the screen (its user's deck screen shows it, through Screens:
## SCREEN; tools keep running while it is lowered). Notices go to the user's Notices. The
## Icebreaker is its sibling IcebreakerTool.
## - Plugging: holding LMB with the deck in hand on a device with a deck port (its user's ToolUse
##   works the device, Device.accepts_tool(), and says so: `worked`) plugs the held deck in there and
##   raises the screen. The port decides the address
##   (NetworkSource): a wall jack joins its subnet, a maintenance port links to its device only, a
##   computer lends its address. Tethered: the deck unplugs when its user walks further than
##   `config.tether_distance` from the plugged entity (horizontal), can no longer act, or the deck
##   leaves the user's inventory; unplugging stops its tools.
## - Wi-Fi (M12b, ADR 0117): plug() on an access point (a Device with an AccessPoint) joins the deck
##   to its subnet over Wi-Fi once the user knows its key (WirelessTool cracks it) and stands within
##   range: its traffic starts at a node of its own linked to the access point (NetworkSource
##   WIRELESS, the access point's client address), and it stays joined, screen lowered or not, while
##   the user's eye stays within the deck's Wi-Fi range of the access point (wireless_range():
##   DeckConfig.wireless_range plus the Computer skill's `deck_wireless_range`, straight line); out of
##   range it drops (`out_of_range`) like a pulled plug, and while a jamming field covers the user or
##   the access point (`jammed`, M14b; it cannot join then either).
## - EMP (M14b): an EMP reaching its user unplugs the deck (`emp`), cable or Wi-Fi (take_emp()).
## - Map (discovery, ADR 0112, 0121): every device the deck's traffic reaches (through the routers
##   it has hacked: Router), plus the dead ones right behind them: on the subnet the deck is plugged
##   into or joined (the entry point's) at once, on a subnet behind a router once that subnet has
##   been scanned (`config.scan_time` s, +10 % trace on the tracers watching it, once per subnet:
##   kept on the deck; `scans` and `scanning` let the Map show the scan), and routers at once.
##   Devices seen once stay on the map (greyed when out of reach). Refreshed every
##   `config.refresh_interval` s and after every change. The Map draws only the seen devices on the
##   physical network of the entry point (the jack, the access point joined, the port's device:
##   DeviceNetwork.physical_network(), cables and holding wireless links, up or down, whatever the
##   routers' rules): another network the deck has seen stays remembered and shows again once the
##   deck is plugged in there. Unplugged: nothing.
## - Accounts: log_in() with a login the user's Journal knows (no trace when right; a wrong known
##   password is a failed login). With access to a device (an account, or an exploit item's admin
##   grant: ExploitItems.use_from_deck(), Device.has_access()): its commands (send()), and on a
##   computer its desktop, remotely (open_remote(): Computer.open_desktop(user, account, true); `remote` until
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
## A remote desktop opened (the Computer) or closed (null).
signal remote_changed(computer: Computer)

## The screen id the deck asks its user's Screens for (the deck's screen), and the option naming
## the tool it is raised on (the screen's tool ids; default: its Map).
const SCREEN: StringName = &"deck"
const TOOL_OPTION: StringName = &"tool"
const SEEN: String = "seen"
## The Computer skill's addition to the deck's Wi-Fi range (m).
const WIRELESS_RANGE_ATTRIBUTE: StringName = &"deck_wireless_range"
const SCANNED: String = "scanned"
const DEFAULT_CONFIG: DeckConfig = preload("res://items/deck/deck_config.tres")

@export var config: DeckConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
## The device the deck is plugged into (null: unplugged): its entry point (a jack: the jack itself).
var port: Device
## Its traffic's source while plugged in.
var source: NetworkSource
## The deck stack plugged in.
var stack: ItemStack
## The remote desktop open (null: none).
var remote: Computer
## Subnets being scanned -> seconds left.
var scans: Dictionary[StringName, float] = {}
## Read only: the devices on the entry point's network whose subnet is being scanned (at the last
## refresh): the Map lays them out unseen and shows the scan where they will appear.
var scanning: Array[Device] = []
## Why the deck was last unplugged.
var unplug_reason: StringName = &""

# The last discovery: devices the traffic reaches, those plus the dead ones behind (connected), and
# every device on the map (seen).
var _reached: Array[Device] = []
var _connected: Array[Device] = []
var _map: Array[Device] = []
var _refresh_left: float = 0.0


func _ready() -> void:
	add_to_group(EmpEffect.GROUP)
	if config == null:
		config = DEFAULT_CONFIG
	entity = get_node_or_null(entity_path) as Node3D
	EmpEffect.listen(entity)
	var tool_use := ToolUse.of(entity)
	if tool_use != null:
		tool_use.worked.connect(_on_tool_worked)


## An EMP reaching its user (EmpEffect): the deck is unplugged (`emp`).
func take_emp(_seconds: float, _cause: Stimulus = null) -> void:
	unplug(&"emp")


## True when a jamming field covers `user`'s eye or `access_point` (a deck's Wi-Fi link to it).
static func jammed(user: Node, access_point: Device) -> bool:
	if access_point == null or not is_instance_valid(access_point) or not is_instance_valid(access_point.entity):
		return false
	return JammingField.jams_link(eye_of(user), access_point.entity.global_position)


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


## True when the deck is joined to an access point's Wi-Fi (not plugged into a port).
func is_wireless() -> bool:
	return is_plugged() and source != null and source.kind == NetworkSource.Kind.WIRELESS


## The deck's Wi-Fi range for `user` (m): `config`'s base plus the user's Computer skill.
static func wireless_range(user: Node, p_config: DeckConfig) -> float:
	var base := p_config.wireless_range if p_config != null else 8.0
	return Attributes.read(user, WIRELESS_RANGE_ATTRIBUTE, base)


## Where `user` looks from: its eye (an `eye_transform()` method, the Player's), else its origin.
static func eye_of(user: Node) -> Vector3:
	if user == null or not is_instance_valid(user):
		return Vector3.ZERO
	if user.has_method(&"eye_transform"):
		return (user.call(&"eye_transform") as Transform3D).origin
	return (user as Node3D).global_position if user is Node3D else Vector3.ZERO


## Straight-line distance from `user`'s eye to `device`'s entity (m; INF when either is gone).
static func distance(user: Node, device: Device) -> float:
	if device == null or not is_instance_valid(device) or not is_instance_valid(device.entity):
		return INF
	if user == null or not is_instance_valid(user) or not device.entity.is_inside_tree():
		return INF
	return eye_of(user).distance_to(device.entity.global_position)


## True when `device` stands within `user`'s deck Wi-Fi range (`p_config`'s base plus the skill).
static func in_range(user: Node, device: Device, p_config: DeckConfig) -> bool:
	return distance(user, device) <= wireless_range(user, p_config)


## Plugs the held deck into `device` (unless already there) and raises the screen.
func plug_and_raise(device: Device) -> void:
	if port != device and not plug(device):
		return
	if not Screens.is_open(entity, SCREEN):
		Screens.open(entity, SCREEN, self)


## Plugs `deck_stack` (default: the deck in the user's hand) into `device`. False without a deck or
## a port. An access point: joins its Wi-Fi (only with its key, within range; already joined there:
## true, nothing changes).
func plug(device: Device, deck_stack: ItemStack = null) -> bool:
	if deck_stack == null:
		deck_stack = held_deck()
	if deck_stack == null or device == null or not is_instance_valid(device):
		return false
	if AccessPoint.of(device) != null:
		return _join_wireless(device, deck_stack)
	var kind := DeviceNetwork.port_kind(device)
	if kind == NetworkSource.Kind.NONE or kind == NetworkSource.Kind.AUTO:
		return false
	if is_plugged():
		unplug(&"replugged")
	port = device
	stack = deck_stack
	unplug_reason = &""
	source = NetworkSource.for_user(entity, device, kind)
	var data := {"device": _name_of(device), "port": NetworkSource.kind_name(kind), "address": source.address}
	EventLog.record(&"deck.plugged", _who(), _name_of(device), data)
	plugged_changed.emit(true)
	refresh()
	return true


## Unplugs the deck (`reason`: walked_away, out_of_range or jammed (Wi-Fi), emp, cannot_act, no_deck,
## gone, replugged): its tools stop,
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
	scanning.clear()
	Screens.close(entity, SCREEN)


## The deck stack in the user's hand, or null.
func held_deck() -> ItemStack:
	var hands := _inventory()
	if hands == null:
		return null
	var held := hands.in_hand()
	return held if held != null and held.item.is_tool_of(Device.DECK_TOOL) else null


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
	if is_wireless():
		return _wifi_check()
	var flat := entity.global_position - port.entity.global_position
	flat.y = 0.0
	if flat.length() > config.tether_distance:
		return &"walked_away"
	return &""


# Why the deck's Wi-Fi must drop now (jammed, out_of_range), or &"".
func _wifi_check() -> StringName:
	if DeckSession.jammed(entity, port):
		return &"jammed"
	return &"" if in_range(entity, port, config) else &"out_of_range"


## Discovers again (reach, scans, the map) and tells the screens.
func refresh() -> void:
	_refresh_left = config.refresh_interval
	if not is_plugged() or not is_inside_tree():
		return
	var tree := get_tree()
	_connected = source.connected(tree)
	_reached = source.reached(tree)
	# The entry point's subnet needs no scan (ADR 0121): it shows at once, no trace.
	var entry := DeviceNetwork.subnet_of(port)
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
			var path := path_of(device)
			if not seen.has(path):
				seen.append(path)
				seen_changed = true
	if seen_changed:
		stack.state[SEEN] = seen
	# Only the seen devices on the entry point's physical network: the deck remembers the others.
	var network := DeviceNetwork.physical_network(source.device)
	_map.clear()
	for path: String in seen:
		var device := Device.of(get_node_or_null(NodePath(path)))
		if device != null and network.has(device) and not _map.has(device):
			_map.append(device)
	scanning.clear()
	for device in _connected:
		if scans.has(DeviceNetwork.subnet_of(device)) and network.has(device) and not _map.has(device):
			scanning.append(device)
	changed.emit()


## Every device on the map: seen (in the order first seen) and on the entry point's physical
## network; empty while unplugged.
func map_devices() -> Array[Device]:
	if not is_plugged():
		return [] as Array[Device]
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


## True when the user has access to `device` (an account, or an exploit item's grant).
func has_access(device: Device) -> bool:
	return device != null and is_instance_valid(device) and device.has_access(entity)


## True when `deck_stack` has scanned `subnet` (or the deck was plugged in there).
static func has_scanned(deck_stack: ItemStack, subnet: StringName) -> bool:
	if deck_stack == null:
		return false
	return (deck_stack.state.get(SCANNED, []) as Array).has(String(subnet))


## Logs in on `device` as `user` with the password the user's Journal knows. True on success (no
## trace); a wrong known password is a failed login (+trace).
func log_in(device: Device, user: String) -> bool:
	var accounts := DeviceAccounts.of(device.entity) if device != null else null
	if accounts == null or not is_online(device) or not accounts.knows_login(entity, user):
		return false
	var ok := accounts.login_from(user, accounts.known_password(entity, user), entity, source)
	if ok:
		Notices.send(entity, DeckSession.access_notice(device, "Logged in as %s" % user))
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
## user's computer screen still shows it.
func close_remote() -> void:
	if remote == null:
		return
	var was := remote
	if is_instance_valid(was) and was.desktop_closed.is_connected(_on_desktop_closed):
		was.desktop_closed.disconnect(_on_desktop_closed)
	remote = null
	Screens.close(entity, Computer.SCREEN, was)
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
static func access_notice(device: Device, text: String) -> String:
	if Router.of(device.entity) != null:
		return "%s. Router hacked: scanning the subnets behind it" % text
	return text


## Where the deck keeps state about `device` (its entity's node path; "" once out of the tree).
static func path_of(device: Device) -> String:
	if device == null or not is_instance_valid(device) or not device.is_inside_tree():
		return ""
	return String(device.entity.get_path()) if is_instance_valid(device.entity) else String(device.get_path())


func _join_wireless(access_point: Device, deck_stack: ItemStack) -> bool:
	var radio := AccessPoint.of(access_point)
	if not radio.knows_key(entity) or not in_range(entity, access_point, config) or jammed(entity, access_point):
		return false
	if is_wireless() and port == access_point:
		return true
	if is_plugged():
		unplug(&"replugged")
	port = access_point
	stack = deck_stack
	unplug_reason = &""
	source = NetworkSource.wireless(entity, access_point)
	var data := {"device": _name_of(access_point), "port": "WIRELESS", "address": source.address}
	EventLog.record(&"deck.plugged", _who(), _name_of(access_point), data)
	plugged_changed.emit(true)
	refresh()
	return true


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
	# Access from an exploit item (admin): the first admin account, else the first.
	var admin := device.is_admin(entity)
	for each in accounts.accounts:
		if each != null and each.admin == admin:
			return each.user
	return accounts.accounts[0].user if not accounts.accounts.is_empty() else ""


func _on_desktop_closed() -> void:
	remote = null
	remote_changed.emit(null)


func _inventory() -> PlayerInventory:
	return PlayerInventory.of(entity)


# Its user works a tool target (ToolUse): the deck on a device (or a panel of one) plugs in there
# and raises the screen.
func _on_tool_worked(target: Node, tool: StringName) -> void:
	if tool != Device.DECK_TOOL:
		return
	var device := Device.of(target)
	if device != null:
		plug_and_raise(device)


func _name_of(device: Device) -> String:
	if device == null or not is_instance_valid(device):
		return ""
	return String(device.entity.name) if is_instance_valid(device.entity) else String(device.name)


func _who() -> String:
	return NetworkSource.user_key(entity)
