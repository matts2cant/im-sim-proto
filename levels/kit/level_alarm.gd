class_name LevelAlarm
extends Node3D
## The level-wide alarm (ADR 0072): one per level (`level_alarm.tscn`), found through the group
## `level_alarm` (no autoload). Raised by an `alarm.raise` stimulus from any emitter (its receiver's
## `alarm_raise` receptron; make_raise() builds one that reaches the whole level), it stays on for
## `duration` seconds, restarting when raised again, then ends; clear() ends it at once (debug
## panel). While it is on every character with an AlertComms stays wary and searches (Alerted ones
## carry on), and the HUD shows "ALARM". Alarm panels and cameras (M8) emit the stimulus; guards do
## not run to panels yet. EventLog: `alarm.raised {by, point, duration, again}`,
## `alarm.ended {reason}` (timeout, cleared). Saveable (time left, where it was raised).

signal changed(raised: bool)

const GROUP: StringName = &"level_alarm"
const RAISE: StringName = &"alarm.raise"
## Reach of make_raise(): farther than any level.
const REACH: float = 10000.0

@export var duration: float = 90.0

var timer := AlarmTimer.new()
## Where it was last raised from.
var point: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")


## The level's alarm, or null when the level has none.
static func current(tree: SceneTree) -> LevelAlarm:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as LevelAlarm


## An `alarm.raise` stimulus from `source` at `origin` that reaches the alarm anywhere in the level.
static func make_raise(origin: Vector3, source: Node = null) -> Stimulus:
	return Stimulus.make_radius(RAISE, 1.0, origin, REACH, source)


func is_raised() -> bool:
	return timer.is_on()


func time_left() -> float:
	return timer.left


func raise(at: Vector3, by_name: String = "") -> void:
	var again := timer.is_on()
	timer.raise(duration)
	point = at
	var data := {"by": by_name, "point": at, "duration": duration, "again": again}
	EventLog.record(&"alarm.raised", by_name, String(name), data)
	if not again:
		changed.emit(true)


func clear() -> void:
	if not timer.is_on():
		return
	timer.clear()
	_ended("cleared")


func _physics_process(delta: float) -> void:
	if timer.step(delta):
		_ended("timeout")


func _ended(reason: String) -> void:
	EventLog.record(&"alarm.ended", "", String(name), {"reason": reason})
	changed.emit(false)


func save_state() -> Dictionary:
	return {"left": timer.left, "point": point}


func load_state(data: Dictionary) -> void:
	timer.left = float(data.get("left", timer.left))
	point = data.get("point", point)
