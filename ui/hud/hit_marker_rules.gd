class_name HitMarkerRules
extends RefCounted
## Pure (ADR 0126, ADR 0136): which hit marker the crosshair shows for an EventLog entry, from the
## damage the shooter's own stimuli did. The shooter is the character the HUD belongs to (watch()),
## held as an entity reference, never by name. A stimulus is the shooter's when its
## `stimulus.emitted` entry's source entity is the shooter; a character's damage, stun, knockout or
## death caused (`by`) by one of them gives a marker, except on the shooter itself. A guard's hit, a
## fire's pulse or a barrel's blast is not the shooter's.
## Kinds by priority: KILL > KNOCKOUT > HEAD > STUN > BODY (stronger() keeps the stronger one when
## several land on one shot: shotgun pellets). Entries: EventKinds (the keys each one carries).

enum Kind { NONE, BODY, STUN, HEAD, KNOCKOUT, KILL }

const HEAD_PART: StringName = &"head"
## Only damage stimuli can hit (`damage.ballistic`, `damage.stun`, ...).
const DAMAGE_PREFIX: String = "damage."
## Stimulus ids remembered (the latest); older ones are forgotten.
const MEMORY: int = 64

## Instance id of the watched shooter (0: none).
var _shooter_id: int = 0
var _ids: Array[int] = []


func _init(shooter: Node = null) -> void:
	watch(shooter)


## Shows the hits of `shooter` from now on (null: nobody's).
func watch(shooter: Node) -> void:
	_shooter_id = shooter.get_instance_id() if is_instance_valid(shooter) else 0


## True when `entity` is the watched shooter.
func is_shooter(entity: Node) -> bool:
	return _shooter_id != 0 and entity != null and entity.get_instance_id() == _shooter_id


## The marker `entry` asks for, NONE when it is not a hit by the shooter. Remembers the shooter's
## stimuli as they are emitted.
func observe(entry: EventLogEntry) -> Kind:
	var data := entry.data
	if entry.kind == EventKinds.STIMULUS_EMITTED:
		var damage := str(data.get("type", "")).begins_with(DAMAGE_PREFIX)
		if damage and is_shooter(entry.source_entity()):
			_remember(int(data.get("id", 0)))
		return Kind.NONE
	var kind := Kind.NONE
	match entry.kind:
		EventKinds.ACTOR_DAMAGED:
			if float(data.get("amount", 0.0)) > 0.0:
				kind = Kind.HEAD if StringName(str(data.get("part", ""))) == HEAD_PART else Kind.BODY
		EventKinds.ACTOR_STUNNED:
			kind = Kind.STUN
		EventKinds.ACTOR_KNOCKED_OUT:
			kind = Kind.KNOCKOUT
		EventKinds.ACTOR_DIED:
			kind = Kind.KILL
	return kind if kind != Kind.NONE and _is_hit(entry) else Kind.NONE


## The stronger of two markers (the later one on a tie).
static func stronger(a: Kind, b: Kind) -> Kind:
	return b if int(b) >= int(a) else a


func clear() -> void:
	_ids.clear()


# Caused by one of the shooter's stimuli, on someone else.
func _is_hit(entry: EventLogEntry) -> bool:
	if is_shooter(entry.target_entity()):
		return false
	var by: Variant = entry.data.get("by", 0)
	return (by is int or by is float) and _ids.has(int(by))


func _remember(id: int) -> void:
	if id == 0:
		return
	_ids.append(id)
	if _ids.size() > MEMORY:
		_ids.pop_front()
