class_name AlarmController
extends Node
## Component (ADR 0075, ADR 0077): the alarm controller's behaviour, beside the entity's Device. In
## group `alarm_controller` (GROUP: the debug panel finds controllers there).
## - `device.incident` (a sensor's report, origin = where) or `command.trigger`, unless disarmed:
##   rings for `duration` seconds (another one restarts the time). While ringing it sends
##   `command.ring` to every device it reaches that accepts it (sirens), again every `ring_refresh`
##   seconds, and `command.silence` when it stops. On an incident it also sends `command.broadcast`
##   at the incident location to every device it reaches that accepts it (radio base stations).
## - `command.reset` stops the ringing. `command.disarm` (or `command.disable`) stops it and makes it
##   ignore incidents and triggers until `command.enable` re-arms it.
## - Losing power or breaking (its Device going down) stops it; it cannot send while down anyway.
## - Loss of signal (M12c, ADR 0115): it supervises the devices that report to it, i.e. every device
##   whose incidents would reach it now (DeviceGraph.reaches(device, controller): through up gear and
##   the routers' rules). Every `supervision_interval` seconds while it is up it takes stock
##   (LossOfSignal); each supervised device that no longer reaches it (broken, unpowered, cut off)
##   is a trouble note for the security console (trouble_lines()). `fault_drops` drops within
##   `fault_window` seconds raise one network fault: an incident like any other (guards respond)
##   at the failed equipment, the down device the dropped ones share upstream
##   (NetworkRoute.shared_cut(): the switch or router that cut them), else the first dropped
##   device. While it rings for a fault its entity carries FAULT, so sirens announce it with their
##   fault pattern. Down, it supervises nothing and takes stock again once back up.
## The commands arrive through its receptrons (DeviceActionEffect, blocked while unpowered or
## broken). EventLog: `alarm.raised {by, point, duration, again, fault}`, `alarm.ended {reason}`
## (timeout, reset, disarmed, unpowered), `alarm.armed {armed}`, `alarm.ignored {by}` (disarmed),
## `alarm.trouble {device}` (one per drop), `alarm.network_fault {at, drops, point}`.
## Saveable (time left, where, armed, its clock and trouble notes).

signal changed(ringing: bool)

const GROUP: StringName = &"alarm_controller"
## On its entity while it rings for a network fault (sirens use their fault pattern).
const FAULT: StringName = &"alarm.network_fault"
## The `by` of a network fault's alarm.raised.
const FAULT_BY := "network fault"

@export var config: AlarmControllerConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var timer := AlarmTimer.new()
var armed: bool = true
## Where it was last raised from (the incident location, or the controller for a trigger).
var point: Vector3 = Vector3.ZERO
## Its supervision of the devices that report to it (trouble notes, network faults).
var supervision := LossOfSignal.new()
## Seconds since the level started (the trouble notes' times).
var clock: float = 0.0

var _refresh_left: float = 0.0
var _supervise_left: float = 0.0
# Supervised device id -> where it was at the last stock-taking (a dropped one may be freed).
var _positions: Dictionary[int, Vector3] = {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	entity = get_node_or_null(entity_path) as Node3D
	device = Device.of(entity)
	if device == null or config == null:
		push_warning("AlarmController %s: needs a Device sibling and a config" % get_path())
		set_physics_process(false)
		return
	device.action_received.connect(_on_action)
	device.state_changed.connect(_on_device_state_changed)
	supervision.threshold = config.fault_drops
	supervision.window = config.fault_window
	supervision.max_notes = config.trouble_notes


## The AlarmController component of `node` (an entity), or null.
static func of(node: Node) -> AlarmController:
	if node == null:
		return null
	if node is AlarmController:
		return node as AlarmController
	for child in node.get_children():
		if child is AlarmController:
			return child as AlarmController
	return null


## Every alarm controller in `tree`.
static func all(tree: SceneTree) -> Array[AlarmController]:
	var found: Array[AlarmController] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group(GROUP):
		if node is AlarmController and not node.is_queued_for_deletion():
			found.append(node as AlarmController)
	return found


func is_ringing() -> bool:
	return timer.is_on()


func time_left() -> float:
	return timer.left


## Disarmed (`command.disarm` or `command.disable`), for security screens (DeviceStatus).
func device_disabled() -> bool:
	return not armed


## Status words for security screens (DeviceStatus, ADR 0083): armed / disarmed, ringing / silent.
func device_status() -> PackedStringArray:
	return PackedStringArray(["armed" if armed else "disarmed", "ringing" if is_ringing() else "silent"])


## Starts (or restarts) ringing at `at`; `by` is logged. `incident`: also broadcast the location.
## `fault`: a network fault (sirens announce it with their fault pattern; the next incident or
## trigger turns it back into an ordinary alarm). Ignored while disarmed or down.
func raise(at: Vector3, by: String = "", incident: bool = false, fault: bool = false) -> void:
	if device == null or not device.is_up():
		return
	if not armed:
		EventLog.record(EventKinds.ALARM_IGNORED, by, _name(), {"by": by, "point": at})
		return
	var again := timer.is_on()
	timer.raise(config.duration)
	point = at
	ActorState.set_tag(entity, FAULT, fault)
	var data := {"by": by, "point": at, "duration": config.duration, "again": again, "fault": fault}
	EventLog.record(EventKinds.ALARM_RAISED, by, _name(), data)
	_ring_sirens()
	if incident:
		device.send_to_all(Device.BROADCAST, at)
	if not again:
		changed.emit(true)


## Stops ringing (sirens it reaches are silenced); `reason` is logged.
func stop(reason: String) -> void:
	if not timer.is_on():
		return
	timer.clear()
	_ended(reason)


## Arms (true) or disarms (false); disarming stops the ringing.
func set_armed(value: bool) -> void:
	if value == armed:
		return
	armed = value
	EventLog.record(EventKinds.ALARM_ARMED, "", _name(), {"armed": armed})
	if not armed:
		stop("disarmed")


## The trouble notes' lines, newest first ("02:15  CAM-GATE  lost signal").
func trouble_lines() -> PackedStringArray:
	return supervision.lines()


## True while it rings for a network fault.
func is_fault() -> bool:
	return is_ringing() and ActorState.has(entity, FAULT)


func _physics_process(delta: float) -> void:
	clock += delta
	_supervise(delta)
	if not timer.is_on():
		return
	if timer.step(delta):
		_ended("timeout")
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_ring_sirens()


func _ended(reason: String) -> void:
	ActorState.set_tag(entity, FAULT, false)
	if device != null:
		device.send_to_all(Device.SILENCE)
	EventLog.record(EventKinds.ALARM_ENDED, "", _name(), {"reason": reason})
	changed.emit(false)


# Takes stock of who reports to it every `supervision_interval` seconds (see the class description).
func _supervise(delta: float) -> void:
	_supervise_left -= delta
	if _supervise_left > 0.0:
		return
	_supervise_left = config.supervision_interval
	if config.fault_drops <= 0 or not device.is_up() or not is_inside_tree():
		supervision.reset()
		return
	var graph := Device.graph(get_tree())
	var own := device.get_instance_id()
	var present: Dictionary[int, String] = {}
	for id in graph.component(own):
		var other := instance_from_id(id) as Device
		if other == null or not is_instance_valid(other.entity) or not graph.reaches(id, own):
			continue
		present[id] = NetworkSource.display_name(other)
		_positions[id] = other.entity.global_position
	for id in supervision.update(present, clock):
		var dropped := instance_from_id(id) as Device
		var shown := NetworkSource.display_name(dropped) if is_instance_valid(dropped) else ""
		EventLog.record(EventKinds.ALARM_TROUBLE, shown, _name(), {"device": shown, "time": clock})
	var burst := supervision.fault_due(clock)
	if not burst.is_empty():
		_raise_fault(graph, own, burst)


# One network fault for `burst` (the dropped device ids) at the failed equipment.
func _raise_fault(graph: DeviceGraph, own: int, burst: PackedInt64Array) -> void:
	var cut := NetworkRoute.shared_cut(graph, own, burst)
	var cut_device := instance_from_id(cut) as Device if cut != 0 else null
	var at: Vector3 = _positions.get(burst[0], entity.global_position)
	var where := ""
	if cut_device != null and is_instance_valid(cut_device.entity):
		at = cut_device.entity.global_position
		where = NetworkSource.display_name(cut_device)
	var data := {"at": where, "drops": burst.size(), "point": at}
	EventLog.record(EventKinds.ALARM_NETWORK_FAULT, FAULT_BY, _name(), data)
	raise(at, FAULT_BY, true, true)


func _ring_sirens() -> void:
	_refresh_left = config.ring_refresh
	device.send_to_all(Device.RING)


func _on_action(action: StringName, stimulus: Stimulus) -> void:
	match action:
		Device.INCIDENT:
			raise(stimulus.origin, stimulus.source_name(), true)
		Device.TRIGGER:
			raise(entity.global_position, stimulus.source_name())
		Device.RESET:
			stop("reset")
		Device.DISARM, Device.DISABLE:
			set_armed(false)
		Device.ENABLE:
			set_armed(true)


func _on_device_state_changed(up: bool) -> void:
	if not up:
		stop("broken" if device.broken else "unpowered")


func _name() -> String:
	return String(entity.name) if entity != null else String(name)


func save_state() -> Dictionary:
	var data := {"left": timer.left, "point": point, "armed": armed, "refresh": _refresh_left, "clock": clock}
	data["fault"] = ActorState.has(entity, FAULT)
	data["supervision"] = supervision.to_dict()
	return data


## Loading takes stock of who reports to it afresh (no drop is counted across a load).
func load_state(data: Dictionary) -> void:
	timer.left = float(data.get("left", timer.left))
	point = data.get("point", point)
	armed = bool(data.get("armed", armed))
	_refresh_left = float(data.get("refresh", _refresh_left))
	clock = float(data.get("clock", clock))
	ActorState.set_tag(entity, FAULT, bool(data.get("fault", false)) and timer.is_on())
	supervision.from_dict(data.get("supervision", {}) as Dictionary)
	_positions.clear()
	_supervise_left = 0.0
