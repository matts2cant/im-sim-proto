class_name HitMarkerRules
extends RefCounted
## Pure (ADR 0126): which hit marker the crosshair shows for an EventLog entry, from the damage the
## shooter's own stimuli did. A stimulus is the shooter's when its `stimulus.emitted` names a source
## in `shooter_names` (the player's node name, like MissionTally's attribution); a character's
## damage, stun, knockout or death caused (`by`) by one of them gives a marker, except on the
## shooter itself. A guard's hit, a fire's pulse or a barrel's blast is not the shooter's.
## Kinds by priority: KILL > KNOCKOUT > HEAD > STUN > BODY (stronger() keeps the stronger one when
## several land on one shot: shotgun pellets).

enum Kind { NONE, BODY, STUN, HEAD, KNOCKOUT, KILL }

const EMITTED: StringName = &"stimulus.emitted"
const DAMAGED: StringName = &"actor.damaged"
const STUNNED: StringName = &"actor.stunned"
const KNOCKED_OUT: StringName = &"actor.knocked_out"
const DIED: StringName = &"actor.died"
const HEAD_PART: StringName = &"head"
## Only damage stimuli can hit (`damage.ballistic`, `damage.stun`, ...).
const DAMAGE_PREFIX: String = "damage."
## Stimulus ids remembered (the latest); older ones are forgotten.
const MEMORY: int = 64

var shooter_names: Array[String] = []

var _ids: Array[int] = []


func _init(p_shooter_names: Array[String] = []) -> void:
	shooter_names = p_shooter_names


## The marker `entry` asks for, NONE when it is not a hit by the shooter. Remembers the shooter's
## stimuli as they are emitted.
func observe(entry: EventLogEntry) -> Kind:
	var data := entry.data
	if entry.kind == EMITTED:
		var damage := str(data.get("type", "")).begins_with(DAMAGE_PREFIX)
		if damage and shooter_names.has(str(data.get("source", entry.source))):
			_remember(int(data.get("id", 0)))
		return Kind.NONE
	var kind := Kind.NONE
	match entry.kind:
		DAMAGED:
			if float(data.get("amount", 0.0)) > 0.0:
				kind = Kind.HEAD if StringName(str(data.get("part", ""))) == HEAD_PART else Kind.BODY
		STUNNED:
			kind = Kind.STUN
		KNOCKED_OUT:
			kind = Kind.KNOCKOUT
		DIED:
			kind = Kind.KILL
	return kind if kind != Kind.NONE and _is_hit(entry) else Kind.NONE


## The stronger of two markers (the later one on a tie).
static func stronger(a: Kind, b: Kind) -> Kind:
	return b if int(b) >= int(a) else a


func clear() -> void:
	_ids.clear()


# Caused by one of the shooter's stimuli, on someone else.
func _is_hit(entry: EventLogEntry) -> bool:
	if shooter_names.has(entry.target):
		return false
	var by: Variant = entry.data.get("by", 0)
	return (by is int or by is float) and _ids.has(int(by))


func _remember(id: int) -> void:
	if id == 0:
		return
	_ids.append(id)
	if _ids.size() > MEMORY:
		_ids.pop_front()
