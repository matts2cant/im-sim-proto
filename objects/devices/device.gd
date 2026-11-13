class_name Device
extends Node
## Component: makes its entity a network device (ADR 0075, 0077, 0113). Any entity can carry it; a
## network switch is just a device with links.
## - State: mirrored into the entity's tags: `state.unpowered` while its Powered is off (or an EMP
##   `outage` runs when it has none), `state.broken` once its Breakable is depleted. Up = powered
##   and unbroken; `state_changed` reports every change.
## - Cables and reach: `links` (undirected: one end lists a cable; entities or Device nodes) and
##   `wireless` (an access point's entity: a radio link while in its range and not jammed,
##   wireless_link()). Reach is DeviceGraph's (DeviceGraphBuilder): every node on the path is up; a
##   Router gates subnets (ADR 0113).
## - Commands: send_command() delivers a CONTACT stimulus of the command type to a target it reaches
##   (and that `trusted` allows); the target's receptrons run DeviceActionEffect -> receive_action()
##   -> `action_received` for its behaviour components. A device accepts a command when one of its
##   receivers wants it; command constants live with their components (DeviceStatus: which apply).
## - Incidents: report_incident() sends `device.incident` to every device it reaches that accepts it.
## - Network data: `address`, `subnet` (empty: a cabled device's, else the implicit &""), `deck_port`
##   (how a deck plugs in: DeviceNetwork.port_kind()). `intrusion` (DeviceIntrusion): exploit grants
##   and the device's log; access is an account (DeviceAccounts) or a grant (has_access(), is_admin()).
## - Interfaces (conventions.md): the deck's tool target (ToolUse: accepts_tool(), tool_hold()), the
##   address source (DeviceNetwork.ADDRESS_GROUP: device_address()) and EMP-reactive (EmpEffect:
##   take_emp()). It knows nothing about the deck: DeckSession reacts to ToolUse's `worked`.
## - `status_light`: a StatusLight on the entity (its model's light, or its lamp: ADR 0122, 0130).
## - `device_id`: its stable key (ADR 0141; the deck's memory, the Journal's code id fallback).
## EventLog: `device.command {command, from, to, sent, point}` for every attempt,
## `device.state {device, up, unpowered, broken}` on changes. Saveable (`broken`, `intrusion`,
## `outage`, `id`).

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
## The device's stable key (ADR 0141): what a deck remembers it by (seen, cracks, Wi-Fi keys) and
## what the Journal files its logins under when it names no credentials id. Set in a level for a
## fixed one; empty: a random one is made when it enters the tree, and saved.
@export var device_id: String = ""

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


func _enter_tree() -> void:
	if device_id.is_empty():
		device_id = Device.generate_id()


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
## A new random device key (16 hex digits; not affected by the global random seed).
static func generate_id() -> String:
	return "d" + Crypto.new().generate_random_bytes(8).hex_encode()


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
	data["id"] = device_id
	return data


func load_state(data: Dictionary) -> void:
	broken = bool(data.get("broken", broken))
	var saved_id := str(data.get("id", ""))
	if not saved_id.is_empty():
		device_id = saved_id
	outage = maxf(float(data.get("outage", 0.0)), 0.0)
	set_physics_process(outage > 0.0)
	intrusion.from_dict(data)
	if data.has("exploit_admins") and str(data.get(NetworkIdentity.FORMAT_KEY, "")) != NetworkIdentity.FORMAT:
		intrusion.rekey(func(saved: String) -> String: return NetworkIdentity.migrate(self, saved))
	_apply()
