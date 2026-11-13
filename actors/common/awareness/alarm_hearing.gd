class_name AlarmHearing
extends Node
## Component (ADR 0077): the entity hears alarm sirens. The `heard_siren` receptron
## (HeardAlarmEffect) calls hear() on every siren pulse it perceives; the entity counts as hearing
## a siren for `hold` seconds after the last pulse (longer than the siren's 1 s interval). Any
## entity can carry it: a guard's AlertComms answers `heard` (wary, search), the player's HUD shows
## "ALARM" while is_hearing(). EventLog: `actor.heard_alarm {actor, point}` when it starts hearing.
## Not saved: the next pulse restores it.

signal heard(at: Vector3)

## Seconds it keeps hearing after the last pulse.
@export var hold: float = 1.5

## Where the last pulse came from.
var point: Vector3 = Vector3.ZERO

var _left: float = 0.0


static func of(node: Node) -> AlarmHearing:
	if node == null:
		return null
	for child in node.get_children():
		if child is AlarmHearing:
			return child as AlarmHearing
	return null


func is_hearing() -> bool:
	return _left > 0.0


## A siren pulse from `at` was heard.
func hear(at: Vector3) -> void:
	if not is_hearing():
		var actor := String(get_parent().name) if get_parent() != null else ""
		EventLog.record(EventKinds.ACTOR_HEARD_ALARM, "", actor, {"actor": actor, "point": at})
	_left = hold
	point = at
	heard.emit(at)


func _physics_process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
