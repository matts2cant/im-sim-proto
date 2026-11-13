class_name DeckSession
extends Node
## Component of an actor that carries a deck (the Player; ADR 0113): the deck plugged in, its Map
## and its access, independent of the screen (its user's deck screen shows it, through Screens:
## SCREEN; tools keep running while it is lowered). Notices go to the user's Notices. The
## Icebreaker is its sibling IcebreakerTool.
## It coordinates two parts (Q17, ADR 0140) and keeps the public API callers and tests use:
## - DeckLink (`link`): the connection. Holding LMB with the deck in hand on a device with a deck
##   port (its user's ToolUse works the device, Device.accepts_tool(), and says so: `worked`) plugs
##   the held deck in there and raises the screen; plug() on an access point joins its Wi-Fi (M12b,
##   ADR 0117). It stays plugged while DeckLink.check() allows (tether, Wi-Fi range, jamming, the
##   deck carried, the user able to act); unplugging stops its tools. An EMP reaching its user
##   unplugs the deck (`emp`), cable or Wi-Fi (take_emp(), M14b).
## - DeckDiscovery (`discovery`): the Map (devices reached and seen, subnet scans, kept on the
##   deck's stack). Refreshed every `config.refresh_interval` s and after every change. Unplugged:
##   nothing.
## - Accounts (here): log_in() with a login the user's Journal knows (no trace when right; a wrong
##   known password is a failed login). With access to a device (an account, or an exploit item's
##   admin grant: ExploitItems.use_from_deck(), Device.has_access()): its commands (send()), and on
##   a computer its desktop, remotely (open_remote(): Computer.open_desktop(user, account, true);
##   `remote` until `desktop_closed`). As admin of a router: its firewall rules (the deck's Firewall
##   tool). Commands and remote desktops are written to the device's log with the deck's address
##   (Device.intrusion).
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
const SEEN: String = DeckDiscovery.SEEN
## The Computer skill's addition to the deck's Wi-Fi range (m).
const WIRELESS_RANGE_ATTRIBUTE: StringName = DeckLink.WIRELESS_RANGE_ATTRIBUTE
const SCANNED: String = DeckDiscovery.SCANNED
const DEFAULT_CONFIG: DeckConfig = preload("res://items/deck/deck_config.tres")

@export var config: DeckConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
## The connection (port, source, stack, unplug reason).
var link: DeckLink = DeckLink.new()
## The Map.
var discovery: DeckDiscovery
## The remote desktop open (null: none).
var remote: Computer

## The device the deck is plugged into (null: unplugged): its entry point (a jack: the jack itself).
var port: Device:
	get:
		return link.port
## Its traffic's source while plugged in.
var source: NetworkSource:
	get:
		return link.source
## The deck stack plugged in.
var stack: ItemStack:
	get:
		return link.stack
## Why the deck was last unplugged.
var unplug_reason: StringName:
	get:
		return link.unplug_reason
## Subnets being scanned -> seconds left (DeckDiscovery).
var scans: Dictionary[StringName, float]:
	get:
		return discovery.scans
## Read only: the devices whose subnet is being scanned (DeckDiscovery).
var scanning: Array[Device]:
	get:
		return discovery.scanning

var _refresh_left: float = 0.0


func _init() -> void:
	add_to_group(EmpEffect.GROUP)
	discovery = DeckDiscovery.new(self)


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG
	entity = Entities.of_component(self, entity_path) as Node3D
	EmpEffect.listen(entity)
	var tool_use := ToolUse.of(entity)
	if tool_use != null:
		tool_use.worked.connect(_on_tool_worked)


## An EMP reaching its user (EmpEffect): the deck is unplugged (`emp`).
func take_emp(_seconds: float, _cause: Stimulus = null) -> void:
	unplug(&"emp")


## True when `user` or `access_point`'s entity is jammed (DeckLink.jammed()).
static func jammed(user: Node, access_point: Device) -> bool:
	return DeckLink.jammed(user, access_point)


## The DeckSession child of `node`, or null.
static func of(node: Node) -> DeckSession:
	if node == null or not is_instance_valid(node):
		return null
	for child in node.get_children():
		if child is DeckSession:
			return child as DeckSession
	return null


func is_plugged() -> bool:
	return link.is_plugged()


## True when the deck is joined to an access point's Wi-Fi (not plugged into a port).
func is_wireless() -> bool:
	return link.is_wireless()


## The deck's Wi-Fi range for `user` (m; DeckLink.wireless_range()).
static func wireless_range(user: Node, p_config: DeckConfig) -> float:
	return DeckLink.wireless_range(user, p_config)


## Where `user` looks from (DeckLink.eye_of()).
static func eye_of(user: Node) -> Vector3:
	return DeckLink.eye_of(user)


## Straight-line distance from `user`'s eye to `device`'s entity (m; DeckLink.distance()).
static func distance(user: Node, device: Device) -> float:
	return DeckLink.distance(user, device)


## True when `device` stands within `user`'s deck Wi-Fi range (DeckLink.in_range()).
static func in_range(user: Node, device: Device, p_config: DeckConfig) -> bool:
	return DeckLink.in_range(user, device, p_config)


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
	var next := DeckLink.source_for(entity, device, deck_stack, config)
	if next == null:
		return false
	if link.is_current(next):
		return true
	if is_plugged():
		unplug(&"replugged")
	link.attach(next, deck_stack)
	var data := {"device": _name_of(device), "port": NetworkSource.kind_name(next.kind), "address": next.address}
	EventLog.record(EventKinds.DECK_PLUGGED, _who(), _name_of(device), data)
	plugged_changed.emit(true)
	refresh()
	return true


## Unplugs the deck (`reason`: walked_away, out_of_range or jammed (Wi-Fi), emp, cannot_act, no_deck,
## gone, replugged): its tools stop, the screen closes. Lowering the screen never unplugs.
func unplug(reason: StringName = &"unplugged") -> void:
	if link.port == null:
		return
	var was := link.port
	close_remote()
	EventLog.record(EventKinds.DECK_UNPLUGGED, _who(), _name_of(was), {"device": _name_of(was), "reason": reason})
	link.unplug_reason = reason
	plugged_changed.emit(false)
	link.detach(reason)
	discovery.clear()
	Screens.close(entity, SCREEN)


## The deck stack in the user's hand, or null. A hand is the player's inventory layer
## (PlayerInventory); another character plugs a deck it carries by passing its stack to plug().
func held_deck() -> ItemStack:
	var hands := PlayerInventory.of(entity)
	if hands == null:
		return null
	var held := hands.in_hand()
	return held if held != null and held.item.is_tool_of(Device.DECK_TOOL) else null


func _physics_process(delta: float) -> void:
	if link.port == null:
		return
	var inventory := Inventory.of(entity)
	var carried := inventory == null or inventory.has(stack)
	var reason := link.check(entity, config, carried)
	if not reason.is_empty():
		unplug(reason)
		return
	var scanned := discovery.step_scans(delta)
	_refresh_left -= delta
	if scanned or _refresh_left <= 0.0:
		refresh()


## Discovers again (reach, scans, the map: DeckDiscovery) and tells the screens.
func refresh() -> void:
	_refresh_left = config.refresh_interval
	if not is_plugged() or not is_inside_tree():
		return
	discovery.refresh()
	changed.emit()


## Every device on the map: seen (in the order first seen) and on the entry point's physical
## network; empty while unplugged.
func map_devices() -> Array[Device]:
	if not is_plugged():
		return [] as Array[Device]
	return discovery.map_devices()


## The devices the deck's traffic reaches now (at the last refresh).
func reached_devices() -> Array[Device]:
	return discovery.reached_devices()


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


## True when `deck_stack` has scanned `subnet` (DeckDiscovery.has_scanned()).
static func has_scanned(deck_stack: ItemStack, subnet: StringName) -> bool:
	return DeckDiscovery.has_scanned(deck_stack, subnet)


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
	var data := {"command": command, "from": _name_of(port), "to": target, "sent": sent, "by": entity}
	if sent:
		var stimulus := Device.command_stimulus(command, device, entity)
		StimulusSystem.emit(stimulus)
		data["stimulus"] = stimulus.id
		device.intrusion.device_log.record(DeviceLog.REMOTE, source.address, _who(), String(command))
	EventLog.record(EventKinds.DEVICE_COMMAND, _name_of(port), target, data)
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
	EventLog.record(EventKinds.DECK_REMOTE, _who(), _name_of(device), {"device": _name_of(device), "user": user})
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
	return discovery.hidden_routes(device)


## The tracers the screens show a bar for (Tracer.bars_for()); a bar names a tracer only once its
## host is on the map (map_devices()).
func tracers() -> Array[Tracer]:
	if not is_plugged() or not is_inside_tree():
		return [] as Array[Tracer]
	return Tracer.bars_for(get_tree(), entity, discovery.connected_devices(), source.address)


## `text`, plus the router note when `device` is a router (its subnets now show on the map).
static func access_notice(device: Device, text: String) -> String:
	if Router.of(device.entity) != null:
		return "%s. Router hacked: scanning the subnets behind it" % text
	return text


## Where the deck keeps state about `device` (DeckDiscovery.path_of()).
static func path_of(device: Device) -> String:
	return DeckDiscovery.path_of(device)


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


# Its user works a tool target (ToolUse): the deck on a device (or a panel of one) plugs in there
# and raises the screen.
func _on_tool_worked(target: Node, tool: StringName) -> void:
	if tool != Device.DECK_TOOL:
		return
	var device := Device.of(target)
	if device != null:
		plug_and_raise(device)


func _name_of(device: Device) -> String:
	return EntityNames.device_log_name(device)


func _who() -> String:
	return EntityNames.log_name(entity)
