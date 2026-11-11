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
##   is enough. Reach is pure logic in DeviceGraph: X reaches Y when a path of links exists whose
##   every node (X, Y and every switch between) is up.
## - Commands: send_command() delivers a CONTACT stimulus of the command type (`command.ring`, ...)
##   at the target's entity through StimulusSystem, only when this device reaches the target. The
##   target's receptrons (objects/devices/receptrons/) run DeviceActionEffect, blocked by
##   `state.unpowered` and `state.broken`, which calls receive_action(): the `action_received`
##   signal tells the entity's behaviour components (AlarmController, Siren, ...). Nothing branches
##   on what a device is: a device accepts a command when one of its receivers wants that type.
## - Incidents: report_incident() sends `device.incident` (origin = the incident location) to every
##   device this one reaches that accepts it (alarm controllers).
## EventLog: `device.command {command, from, to, sent, point}` for every attempt,
## `device.state {device, up, unpowered, broken}` on changes. Saveable (`broken`).

signal state_changed(up: bool)
signal action_received(action: StringName, stimulus: Stimulus)

const GROUP: StringName = &"device"
const UNPOWERED: StringName = &"state.unpowered"
const BROKEN: StringName = &"state.broken"
## Sensor -> alarm controller: an intruder was detected; origin = where.
const INCIDENT: StringName = &"device.incident"
## Remote commands (the shared contract of M8; who may send which is M12).
const OPEN: StringName = &"command.open"
const CLOSE: StringName = &"command.close"
const LOCK: StringName = &"command.lock"
const UNLOCK: StringName = &"command.unlock"
const RING: StringName = &"command.ring"
const SILENCE: StringName = &"command.silence"
const TEST: StringName = &"command.test"
const DISARM: StringName = &"command.disarm"
const RESET: StringName = &"command.reset"
const TRIGGER: StringName = &"command.trigger"
const DISABLE: StringName = &"command.disable"
const ENABLE: StringName = &"command.enable"
## Alarm controller -> radio base station: broadcast the incident at the stimulus origin.
const BROADCAST: StringName = &"command.broadcast"
## Camera remote actions (ADR 0079): stop / resume its sweep, turn it one pan step left / right.
const STOP_SWEEP: StringName = &"command.stop_sweep"
const RESUME_SWEEP: StringName = &"command.resume_sweep"
const PAN_LEFT: StringName = &"command.pan_left"
const PAN_RIGHT: StringName = &"command.pan_right"
## Turret target presets (ADR 0079): each sets the turret's hostile tags from its TurretConfig.
const TARGET_INTRUDERS: StringName = &"command.target_intruders"
const TARGET_GUARDS: StringName = &"command.target_guards"
const TARGET_EVERYONE: StringName = &"command.target_everyone"
## send_command() without a point: the stimulus origin is the target's position.
const NO_POINT: Vector3 = Vector3.INF

## Devices this one is cabled to: paths to their entities (or their Device nodes).
@export var links: Array[NodePath] = []
## Nodes hidden once the device is broken (a siren's horn, an indicator).
@export var broken_hide: Array[NodePath] = []
@export var entity_path: NodePath = ^".."

var entity: Node3D
var powered: Powered
var breakable: Breakable
var broken: bool = false

var _was_up: bool = true


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	if entity == null:
		push_warning("Device %s: entity_path %s is not a Node3D" % [get_path(), entity_path])
		return
	if ActorState.tags_of(entity) == null:
		push_warning("Device %s: the entity has no Tags; receptrons cannot block on its state" % get_path())
	powered = Powered.of(entity)
	if powered != null:
		powered.power_changed.connect(_on_power_changed)
	breakable = Breakable.of(entity)
	if breakable != null:
		breakable.depleted.connect(_on_depleted)
		breakable.broken.connect(_on_depleted.bind(null))
	_apply()


## The Device child of `node` (an entity), or `node` itself when it is a Device; null otherwise.
static func of(node: Node) -> Device:
	if node == null:
		return null
	if node is Device:
		return node as Device
	for child in node.get_children():
		if child is Device:
			return child as Device
	return null


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


## The reach graph of every device in `tree` (ids: Device instance ids).
static func graph(tree: SceneTree) -> DeviceGraph:
	var result := DeviceGraph.new()
	var devices := all(tree)
	for device in devices:
		result.add_node(device.get_instance_id(), device.is_up())
	for device in devices:
		for other in device.linked():
			result.link(device.get_instance_id(), other.get_instance_id())
	return result


## Powered and unbroken (and its entity still in the level).
func is_up() -> bool:
	if not is_instance_valid(entity) or entity.is_queued_for_deletion() or not is_inside_tree():
		return false
	return not broken and (powered == null or powered.on)


func is_powered() -> bool:
	return powered == null or powered.on


## The devices `links` names (missing or freed ones skipped).
func linked() -> Array[Device]:
	var found: Array[Device] = []
	for path in links:
		var device := Device.of(get_node_or_null(path))
		if device != null and device != self and not found.has(device):
			found.append(device)
	return found


## True when this device reaches `target` (an entity or its Device) through up devices.
func reaches(target: Node) -> bool:
	var other := Device.of(target)
	if other == null or not is_inside_tree():
		return false
	return Device.graph(get_tree()).reaches(get_instance_id(), other.get_instance_id())


## Every device this one reaches (itself excluded); with `accepting`, only those that accept that
## stimulus type (accepts()). Breadth-first: nearest first.
func reached(accepting: StringName = &"") -> Array[Device]:
	var found: Array[Device] = []
	if not is_inside_tree():
		return found
	for id in Device.graph(get_tree()).reachable(get_instance_id()):
		var device := instance_from_id(id) as Device
		if device != null and (accepting.is_empty() or device.accepts(accepting, entity)):
			found.append(device)
	return found


## Every device this one is cabled to through up devices, the last one up or down (DeviceGraph
## .connected()): reached() without a type, plus the down devices right behind a reached one or
## cabled to this one (a computer lists those as unpowered or broken). Nearest first.
func connected_devices() -> Array[Device]:
	var found: Array[Device] = []
	if not is_inside_tree():
		return found
	for id in Device.graph(get_tree()).connected(get_instance_id()):
		var device := instance_from_id(id) as Device
		if device != null:
			found.append(device)
	return found


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
## StimulusSystem (delivered on the next tick). Logged either way. True when sent.
## `by`: who operated this device to send it (a computer's user), logged with the stimulus id as
## `by` and `stimulus` so what the command starts traces back to them (mission tallies, ADR 0087).
func send_command(command: StringName, target: Node, at: Vector3 = NO_POINT, by: Node = null) -> bool:
	var other := Device.of(target)
	var sent := other != null and reaches(other)
	var target_name := String(other.entity.name) if other != null and is_instance_valid(other.entity) else ""
	var data := {"command": command, "from": _entity_name(), "to": target_name, "sent": sent}
	if at != NO_POINT:
		data["point"] = at
	if sent:
		var stimulus := Device.command_stimulus(command, other, entity, at)
		StimulusSystem.emit(stimulus)
		data["stimulus"] = stimulus.id
	if is_instance_valid(by):
		data["by"] = String(by.name)
	EventLog.record(&"device.command", _entity_name(), target_name, data)
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
		var data := {"device": _entity_name(), "up": up, "unpowered": not is_powered(), "broken": broken}
		EventLog.record(&"device.state", _entity_name(), "", data)
		state_changed.emit(up)


func _entity_name() -> String:
	return String(entity.name) if is_instance_valid(entity) else String(name)


func save_state() -> Dictionary:
	return {"broken": broken}


func load_state(data: Dictionary) -> void:
	broken = bool(data.get("broken", broken))
	_apply()
