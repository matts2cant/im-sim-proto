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
## The commands arrive through its receptrons (DeviceActionEffect, blocked while unpowered or
## broken). EventLog: `alarm.raised {by, point, duration, again}`, `alarm.ended {reason}` (timeout,
## reset, disarmed, unpowered), `alarm.armed {armed}`, `alarm.ignored {by}` (disarmed).
## Saveable (time left, where, armed).

signal changed(ringing: bool)

const GROUP: StringName = &"alarm_controller"

@export var config: AlarmControllerConfig
@export var entity_path: NodePath = ^".."

var entity: Node3D
var device: Device
var timer := AlarmTimer.new()
var armed: bool = true
## Where it was last raised from (the incident location, or the controller for a trigger).
var point: Vector3 = Vector3.ZERO

var _refresh_left: float = 0.0


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


## Starts (or restarts) ringing at `at`; `by` is logged. `incident`: also broadcast the location.
## Ignored while disarmed or down.
func raise(at: Vector3, by: String = "", incident: bool = false) -> void:
	if device == null or not device.is_up():
		return
	if not armed:
		EventLog.record(&"alarm.ignored", by, _name(), {"by": by, "point": at})
		return
	var again := timer.is_on()
	timer.raise(config.duration)
	point = at
	var data := {"by": by, "point": at, "duration": config.duration, "again": again}
	EventLog.record(&"alarm.raised", by, _name(), data)
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
	EventLog.record(&"alarm.armed", "", _name(), {"armed": armed})
	if not armed:
		stop("disarmed")


func _physics_process(delta: float) -> void:
	if not timer.is_on():
		return
	if timer.step(delta):
		_ended("timeout")
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_ring_sirens()


func _ended(reason: String) -> void:
	if device != null:
		device.send_to_all(Device.SILENCE)
	EventLog.record(&"alarm.ended", "", _name(), {"reason": reason})
	changed.emit(false)


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
	return {"left": timer.left, "point": point, "armed": armed, "refresh": _refresh_left}


func load_state(data: Dictionary) -> void:
	timer.left = float(data.get("left", timer.left))
	point = data.get("point", point)
	armed = bool(data.get("armed", armed))
	_refresh_left = float(data.get("refresh", _refresh_left))
