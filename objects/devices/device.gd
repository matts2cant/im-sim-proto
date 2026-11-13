class_name Device
extends Node
## Component: makes its entity a network device (ADR 0075, ADR 0077). Any entity can carry it; a
## network switch is just a device with links.
## - State: it mirrors the entity's state into tags: `state.unpowered` while its Powered is off,
##   `state.broken` once its Breakable is depleted (device scenes keep the broken husk:
##   `break_on_depleted` off). No Powered: always powered; no Breakable: never broken. It is up
##   while powered and unbroken; `state_changed` reports every change.
## - Cables (M8; addresses, subnets and firewalls are M12): `links` lists the devices this one is
##   cabled to (their entities or Device nodes); links are undirected, so listing a cable on one end
##   is enough. Reach is pure logic in DeviceGraph (built from the level by DeviceGraphBuilder): X
##   reaches Y when a path of links exists whose every node (X, Y and every switch between) is up.
## - Commands: send_command() delivers a CONTACT stimulus of the command type (`command.ring`, ...)
##   at the target's entity through StimulusSystem, only when this device reaches the target. The
##   target's receptrons (objects/devices/receptrons/) run DeviceActionEffect, blocked by
##   `state.unpowered` and `state.broken`, which calls receive_action(): the `action_received`
##   signal tells the entity's behaviour components (AlarmController, Siren, ...). Nothing branches
##   on what a device is: a device accepts a command when one of its receivers wants that type. The
##   command constants live with the components that handle them (Door.OPEN, Siren.RING, ...;
##   DeviceStatus: which apply now).
## - Incidents: report_incident() sends `device.incident` (origin = the incident location) to every
##   device this one reaches that accepts it (alarm controllers).
## - Network (M12a, ADR 0113): `address` and `subnet` (empty: the subnet of a cabled device that
##   names one, else the implicit &"" every level without network data is on); a device with a
##   Router component is a gate between subnets (DeviceGraph): it lets a device's traffic through by
##   its rules (default allow) and a user's (the deck) only once that user has an account on it.
##   `trusted`: the devices allowed to command this one (empty: any device that reaches it, M8's
##   behaviour); incidents are reports, not commands, and ignore it.
## - Intrusion (M12b, ADR 0115, 0121): `intrusion` (DeviceIntrusion, saved) holds the users an
##   exploit item gave admin access and its log (logins, failed logins, exploits used and the
##   commands it receives, with the source address). Access (has_access(), is_admin()) is an account
##   (DeviceAccounts) or an exploit item's grant (admin).
## - Wireless (M12b, ADR 0115, 0117): `wireless` names an access point (an entity with an
##   AccessPoint) this device links to by radio instead of a cable; the link holds while the device
##   is not network gear (DeviceNetwork.is_network_gear()) and stands within the access point's
##   `wireless_range` (wireless_link()). It is a link of the reach graph like a cable: a down access
##   point cuts its wireless devices off. `links` stays the cables.
## - Status light (M12c, ADR 0122): it attaches a StatusLight to its entity, unless `status_light`
##   is off. An entity with its own lamp (DeviceLamp) shows the state there while on a network (one
##   light per device); without a model or a lamp it shows none. An entity built
##   from a device model (ADR 0130 step 2) always gets one: it drives the model's own light, sockets
##   and name plates (ModelFace).
## - The deck (ADR 0113): `deck_port` (a NetworkSource.Kind: AUTO, NONE, JACK, PORT or HOST) says
##   how a deck plugs into it (a wall jack joins its subnet, a maintenance port links to this device
##   only, a computer lends its address); AUTO: a computer (Computer component) is a host, a device
##   without cables has a maintenance port, else none (DeviceNetwork.port_kind()). It is the deck's
##   tool target (accepts_tool() / tool_hold(), worked through ToolUse like a lock); the user's
##   deck reacts to ToolUse's `worked` signal (DeckSession plugs in and raises its screen): a device
##   knows nothing about the deck.
## - EMP and jamming (M14b, ADR 0131): a device is electronic: an EMP (EmpEffect) cuts its power for
##   its seconds, through its Powered (Powered.take_emp()), or its own `outage` when it has none (a
##   door controller without power wiring). A jamming field (JammingField) drops its wireless link
##   while either end stands inside one: wireless_link() is the radio link the range allows (the
##   physical link: subnets, the Map); DeviceNetwork.is_jammed() says when the jamming alone cuts
##   it, and the reach graph then leaves it out.
## EventLog: `device.command {command, from, to, sent, point}` for every attempt,
## `device.state {device, up, unpowered, broken}` on changes. Saveable (`broken`, `intrusion`,
## `outage`).

signal state_changed(up: bool)
signal action_received(action: StringName, stimulus: Stimulus)

const GROUP: StringName = &"device"
const UNPOWERED: StringName = &"state.unpowered"
const BROKEN: StringName = &"state.broken"
## Sensor -> alarm controller: an intruder was detected; origin = where.
const INCIDENT: StringName = &"device.incident"
## send_command() without a point: the stimulus origin is the target's position.
const NO_POINT: Vector3 = Vector3.INF
## ItemData.tool_kind of the deck.
const DECK_TOOL: StringName = &"deck"
## Graph id of a deck plugged into a wall jack (a node of its own, cabled to the jack).
const DECK_NODE: int = -1

## Devices this one is cabled to: paths to their entities (or their Device nodes).
@export var links: Array[NodePath] = []
## Nodes hidden once the device is broken (a siren's horn, an antenna, a camera's lens).
@export var broken_hide: Array[NodePath] = []
@export var entity_path: NodePath = ^".."

@export_group("Network")
## Its IP address as screens show it ("10.0.10.12"); empty: none shown.
@export var address: String = ""
## Its subnet; empty: the subnet of a cabled device that names one (a switch), else the implicit one.
@export var subnet: StringName = &""
## Devices (entities or Device nodes) allowed to command it; empty: any device that reaches it.
@export var trusted: Array[NodePath] = []
## How a deck plugs into it (AUTO, NONE, JACK, PORT or HOST; see the class description).
@export var deck_port: NetworkSource.Kind = NetworkSource.Kind.AUTO
## The access point (its entity or Device) it links to by radio instead of a cable; empty: none.
@export var wireless: NodePath = ^""
## Shows its state on a StatusLight (its model's light, or its lamp while on a network).
@export var status_light: bool = true

var entity: Node3D
var powered: Powered
var breakable: Breakable
var broken: bool = false
## Exploit access and its log (saved).
var intrusion: DeviceIntrusion = DeviceIntrusion.new()
## Seconds of outage left (an EMP) when it has no Powered of its own; 0: none.
var outage: float = 0.0

var _was_up: bool = true


func _init() -> void:
	add_to_group(ToolUse.GROUP)
	add_to_group(DeviceNetwork.ADDRESS_GROUP)
	add_to_group(EmpEffect.GROUP)


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LevelSnapshot.GROUP)
	set_physics_process(false)
	entity = Entities.of_component(self, entity_path) as Node3D
	if entity == null:
		push_warning("Device %s: entity_path %s is not a Node3D" % [get_path(), entity_path])
		return
	EmpEffect.listen(entity)
	if Tags.of(entity) == null:
		push_warning("Device %s: the entity has no Tags; receptrons cannot block on its state" % get_path())
	powered = Powered.of(entity)
	if powered != null:
		powered.power_changed.connect(_on_power_changed)
	breakable = Breakable.of(entity)
	if breakable != null:
		breakable.depleted.connect(_on_depleted)
		breakable.broken.connect(_on_depleted.bind(null))
	_apply()
	if not wireless.is_empty():
		_check_wireless.call_deferred()
	if status_light:
		# Deferred: the level's other devices (and the cables naming this one) are ready by then.
		_attach_status_light.call_deferred()


## The Device child of `node` (an entity), or `node` itself when it is a Device; for a panel of a
## device (a DevicePanel, or a body with one: a door controller's wall box, ADR 0130), that device;
## null otherwise.
static func of(node: Node) -> Device:
	if node == null:
		return null
	if node is Device:
		return node as Device
	if node is DevicePanel:
		return (node as DevicePanel).target()
	for child in node.get_children():
		if child is Device:
			return child as Device
	var panel := DevicePanel.of(node)
	return panel.target() if panel != null else null


## Every device in `tree`.
static func all(tree: SceneTree) -> Array[Device]:
	var found: Array[Device] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(GROUP):
		var device := node as Device
		if device != null and device.is_inside_tree() and not device.is_queued_for_deletion():
			found.append(device)
	return found


## Tool interface (ToolUse): a deck plugs in when this device has a port for it.
func accepts_tool(tool: StringName) -> bool:
	return tool == DECK_TOOL and DeviceNetwork.port_kind(self) != NetworkSource.Kind.NONE


## Working it never finishes: the user's tool reacts to ToolUse's `worked` signal (the deck plugs
## in here and raises its screen).
func tool_hold(_user: Node, _delta: float) -> bool:
	return false


func tool_release(_user: Node) -> void:
	pass


## Powered and unbroken (and its entity still in the level).
func is_up() -> bool:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion() or not is_inside_tree():
		return false
	return not broken and is_powered()


## Its Powered is on (Powered.is_on()); without one, no outage runs.
func is_powered() -> bool:
	return powered.is_on() if powered != null else outage <= 0.0


## An EMP (EmpEffect): its Powered loses power for `seconds` (Powered.take_emp()); without one, its
## own outage (the longer of this and one already running).
func take_emp(seconds: float, _cause: Stimulus = null) -> void:
	if powered != null or seconds <= outage:
		return
	outage = seconds
	set_physics_process(true)
	_apply()


func _physics_process(delta: float) -> void:
	outage = maxf(outage - delta, 0.0)
	if outage <= 0.0:
		set_physics_process(false)
		_apply()


## The devices `links` names (missing or freed ones skipped).
func linked() -> Array[Device]:
	var found: Array[Device] = []
	for path in links:
		var device := Device.of(get_node_or_null(path))
		if device != null and device != self and not found.has(device):
			found.append(device)
	return found


## The access point `wireless` names when the radio link holds: that device has an AccessPoint, this
## one is not network gear and stands within its range; else null (no link).
func wireless_link() -> Device:
	if wireless.is_empty():
		return null
	var other := Device.of(get_node_or_null(wireless))
	if other == null or other == self or not is_instance_valid(entity):
		return null
	var access_point := AccessPoint.of(other)
	if access_point == null or DeviceNetwork.is_network_gear(self):
		return null
	return other if access_point.covers(entity.global_position) else null


## True when this device reaches `target` (an entity or its Device) through up devices.
func reaches(target: Node) -> bool:
	var other := Device.of(target)
	if other == null or not is_inside_tree():
		return false
	return DeviceGraphBuilder.build(get_tree()).reaches(get_instance_id(), other.get_instance_id())


## Every device this one reaches (itself excluded); with `accepting`, only those that accept that
## stimulus type (accepts()). Breadth-first: nearest first.
func reached(accepting: StringName = &"") -> Array[Device]:
	var found: Array[Device] = []
	if not is_inside_tree():
		return found
	for id in DeviceGraphBuilder.build(get_tree()).reachable(get_instance_id()):
		var device := instance_from_id(id) as Device
		if device != null and (accepting.is_empty() or device.accepts(accepting, entity)):
			found.append(device)
	return found


## True when `by` has access here: an account (DeviceAccounts) or an exploit item's grant.
func has_access(by: Node) -> bool:
	var accounts := DeviceAccounts.of(entity)
	if accounts != null and accounts.has_access(by):
		return true
	return intrusion.has_exploit(NetworkIdentity.key_of(by))


## True when `by` has admin access here: an admin account or an exploit item's grant.
func is_admin(by: Node) -> bool:
	var accounts := DeviceAccounts.of(entity)
	if accounts != null and accounts.is_admin(by):
		return true
	return intrusion.has_exploit(NetworkIdentity.key_of(by))


## Its network address (`address`) for screens that ask any component (DeviceNetwork.address_of(),
## ADR 0114): the deck's network layer offers it here. (The dead devices behind a live link:
## NetworkSource.connected().)
func device_address() -> String:
	return address


## True when a receiver of this device's entity wants stimuli of `type` (has a receptron for it)
## from `source`. Says nothing about whether the device is up.
func accepts(type: StringName, source: Node = null) -> bool:
	if not is_instance_valid(entity):
		return false
	var probe := Stimulus.make_contact(type, 1.0, entity, source)
	for receiver in StimulusSystem.receivers():
		if is_instance_valid(receiver) and receiver.entity == entity and receiver.wants(probe):
			return true
	return false


## The command stimulus `command` from `source` at `target`'s entity; `at`: its origin (NO_POINT:
## the target's position). Senders that are not devices (the debug panel) emit it themselves.
static func command_stimulus(
	command: StringName, target: Node, source: Node = null, at: Vector3 = NO_POINT
) -> Stimulus:
	var device := Device.of(target)
	var target_entity: Node = device.entity if device != null and is_instance_valid(device.entity) else target
	var stimulus := Stimulus.make_contact(command, 1.0, target_entity, source)
	if at != NO_POINT:
		stimulus.origin = at
	return stimulus


## Sends `command` to `target` (an entity or its Device) when this device reaches it: a CONTACT
## stimulus at the target's entity, origin `at` (NO_POINT: the target's position), emitted through
## StimulusSystem (delivered on the next tick), and only when the target trusts this device (an
## incident needs no trust). Logged either way. True when sent.
## `by`: who operated this device to send it (a computer's user), logged with the stimulus id as
## `by` and `stimulus` so what the command starts traces back to them (mission tallies, ADR 0087).
func send_command(command: StringName, target: Node, at: Vector3 = NO_POINT, by: Node = null) -> bool:
	var other := Device.of(target)
	var sent := other != null and reaches(other) and (command == INCIDENT or DeviceNetwork.trusts(other, self))
	var target_name := EntityNames.log_name(other.entity) if other != null else ""
	var data := {"command": command, "from": EntityNames.log_name(entity, self), "to": target_name, "sent": sent}
	if at != NO_POINT:
		data["point"] = at
	if sent:
		var stimulus := Device.command_stimulus(command, other, entity, at)
		StimulusSystem.emit(stimulus)
		data["stimulus"] = stimulus.id
		if command != INCIDENT:
			other.intrusion.device_log.record(DeviceLog.REMOTE, address, EntityNames.log_name(by), String(command))
	if is_instance_valid(by):
		data["by"] = by
	EventLog.record(EventKinds.DEVICE_COMMAND, EntityNames.log_name(entity, self), target_name, data)
	return sent


## Sends `command` to every device this one reaches that accepts it; returns how many.
func send_to_all(command: StringName, at: Vector3 = NO_POINT) -> int:
	var count := 0
	for device in reached(command):
		if send_command(command, device, at):
			count += 1
	return count


## A sensor's report: `device.incident` at `at` to every alarm controller (any device accepting
## it) this device reaches; returns how many.
func report_incident(at: Vector3) -> int:
	return send_to_all(INCIDENT, at)


## Called by DeviceActionEffect when a command (or an incident) reached the entity's receptrons.
func receive_action(action: StringName, stimulus: Stimulus) -> void:
	action_received.emit(action, stimulus)


func _on_power_changed(_on: bool) -> void:
	_apply()


func _on_depleted(_cause: Stimulus) -> void:
	if broken:
		return
	broken = true
	_apply()


# Mirrors the state into tags and the broken look; reports a change.
func _apply() -> void:
	if not is_instance_valid(entity):
		return
	ActorState.set_tag(entity, UNPOWERED, not is_powered())
	ActorState.set_tag(entity, BROKEN, broken)
	for path in broken_hide:
		var node := get_node_or_null(path) as Node3D
		if node != null:
			node.visible = not broken
	var up := is_up()
	if up != _was_up:
		_was_up = up
		var data := {
			"device": EntityNames.log_name(entity, self), "up": up, "unpowered": not is_powered(), "broken": broken
		}
		EventLog.record(EventKinds.DEVICE_STATE, entity, "", data)
		state_changed.emit(up)


# Level data check: a `wireless` link that cannot hold says why once.
func _check_wireless() -> void:
	if not is_inside_tree() or wireless_link() != null:
		return
	var other := Device.of(get_node_or_null(wireless))
	var why := "names no access point"
	if other != null and AccessPoint.of(other) != null:
		why = "is network gear" if DeviceNetwork.is_network_gear(self) else "stands out of the access point's range"
	push_warning("Device %s: its wireless link %s %s" % [get_path(), wireless, why])


func _attach_status_light() -> void:
	StatusLight.attach(self)


func save_state() -> Dictionary:
	var data := intrusion.to_dict()
	data["broken"] = broken
	data["outage"] = outage
	return data


func load_state(data: Dictionary) -> void:
	broken = bool(data.get("broken", broken))
	outage = maxf(float(data.get("outage", 0.0)), 0.0)
	set_physics_process(outage > 0.0)
	intrusion.from_dict(data)
	if data.has("exploit_admins") and str(data.get(NetworkIdentity.FORMAT_KEY, "")) != NetworkIdentity.FORMAT:
		intrusion.rekey(func(saved: String) -> String: return NetworkIdentity.migrate(self, saved))
	_apply()
