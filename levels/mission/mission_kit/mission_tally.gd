class_name MissionTally
extends RefCounted
## Pure: a mission's tallies and badges from EventLog entries (ADR 0087, ADR 0136), no scene tree.
## Fed every entry as it is recorded (EventLog.entry_added); it never reads the log's history.
## - Attribution: a stimulus is the player's when its source entity has `player_tag` (the
##   `stimulus.emitted` entry's source entity, never its name) or its cause (`cause_id`) is one of
##   the player's: so the blast of a barrel the player shot, the fire it lit and that fire's pulses
##   are the player's too. A device command a player operated (a computer: `device.command` whose
##   `by` entity has the tag) is the player's, and so is what it starts (a turret's shots name the
##   command that retargeted it as their cause, WeaponHolder.cause_id). Noise never harms and is not
##   tracked.
## - Kills: `actor.died` of anyone but a player whose killing stimulus (`by`) is the player's.
##   Knockouts: `actor.knocked_out` the same way.
## - Alarms: `alarm.raised` that started a ring (not `again`). Alerts: `actor.awareness` to
##   `alerted`. Bodies found: `actor.body_found`.
## - Broken (M12c, ADR 0115): the objects the player broke, by stable id (object_id(): the entity's
##   node path, the identity saves use): any Breakable whose health reaches 0 under the player's
##   damage (`object.damaged` with `health` <= 0 and an attributed `by`: props that fall apart and
##   devices that keep their broken husk alike), that explodes from the player's stimulus
##   (`object.exploded`), or that burns out after the player set it alight (`object.ignited` then
##   `object.broken` reason `burnt_out`).
## - Ghost: no alert, no alarm, no body found (Suspicious is fine). Pacifist: no kill. Clean hands:
##   nothing broken.
## Not attributed (known gaps): a thrown prop's impact (its source is the prop; a crate thrown to
## pieces breaks no clean hands) and fall damage after a push (the faller is its own source).
## Saved with the mission (to_dict); attributed stimulus ids stay valid across a load because the
## quicksave reserves them (StimulusSystem.reserve_ids, QuickSave.STIMULUS_IDS).

const BURNT_OUT: String = "burnt_out"
const ALERTED: String = "alerted"
const UNTRACKED_TYPES: Array[String] = ["noise"]
## Data key of the operator entity on `device.command`.
const BY: StringName = &"by"

## Entities with this tag are the player.
## The player character's tag (MissionData.player_tag sets it for a mission).
var player_tag: StringName = ActorState.PLAYER
var kills: int = 0
var knockouts: int = 0
var alarms: int = 0
var alerts: int = 0
var bodies_found: int = 0
## Stable ids (object_id()) of the objects the player broke (id -> true).
var broken: Dictionary[String, bool] = {}

## Ids of the player's stimuli (stimulus id -> true).
var _attributed: Dictionary[int, bool] = {}
## Stable ids of the objects the player set alight (id -> true).
var _lit: Dictionary[String, bool] = {}


func _init(p_player_tag: StringName = ActorState.PLAYER) -> void:
	player_tag = p_player_tag


## The stable id of an object entity: its node path from the scene root (saves restore the level at
## the same paths, LevelSnapshot). "" for none.
static func object_id(entity: Node) -> String:
	if entity == null:
		return ""
	return String(entity.get_path()) if entity.is_inside_tree() else "#%d" % entity.get_instance_id()


## True when `entity` is a player character (has `player_tag`).
func is_player(entity: Node) -> bool:
	return entity != null and ActorState.has(entity, player_tag)


## True when the player broke `entity`.
func has_broken(entity: Node) -> bool:
	var id := object_id(entity)
	return not id.is_empty() and broken.has(id)


## True when the stimulus `id` was the player's (directly or down a cause chain).
func is_attributed(id: int) -> bool:
	return id != 0 and _attributed.has(id)


func ghost() -> bool:
	return alerts == 0 and alarms == 0 and bodies_found == 0


func pacifist() -> bool:
	return kills == 0


func clean_hands() -> bool:
	return broken.is_empty()


## Counts `entry` if it is one of the kinds above.
func observe(entry: EventLogEntry) -> void:
	var data := entry.data
	match entry.kind:
		EventKinds.STIMULUS_EMITTED:
			_observe_stimulus(entry)
		EventKinds.DEVICE_COMMAND:
			if is_player(entry.entity(BY)) and data.get("stimulus") is int:
				_attributed[int(data["stimulus"])] = true
		EventKinds.ACTOR_DIED:
			if not is_player(entry.target_entity()) and is_attributed(_id(data.get("by"))):
				kills += 1
		EventKinds.ACTOR_KNOCKED_OUT:
			if not is_player(entry.target_entity()) and is_attributed(_id(data.get("by"))):
				knockouts += 1
		EventKinds.ALARM_RAISED:
			if not bool(data.get("again", false)):
				alarms += 1
		EventKinds.ACTOR_AWARENESS:
			if str(data.get("to", "")) == ALERTED:
				alerts += 1
		EventKinds.ACTOR_BODY_FOUND:
			bodies_found += 1
		EventKinds.OBJECT_DAMAGED:
			if float(data.get("health", 1.0)) <= 0.0 and is_attributed(_id(data.get("by"))):
				broken[_object_of(entry, EventLogEntry.TARGET)] = true
		EventKinds.OBJECT_EXPLODED:
			if is_attributed(_id(data.get("by"))):
				broken[_object_of(entry, EventLogEntry.SOURCE)] = true
		EventKinds.OBJECT_IGNITED:
			if is_attributed(_id(data.get("by"))):
				_lit[_object_of(entry, EventLogEntry.SOURCE)] = true
		EventKinds.OBJECT_BROKEN:
			var object := _object_of(entry, EventLogEntry.SOURCE)
			if is_attributed(_id(data.get("by"))) or (str(data.get("reason", "")) == BURNT_OUT and _lit.has(object)):
				broken[object] = true


func to_dict() -> Dictionary:
	var ids: Array[int] = []
	ids.assign(_attributed.keys())
	return {
		"kills": kills,
		"knockouts": knockouts,
		"alarms": alarms,
		"alerts": alerts,
		"bodies_found": bodies_found,
		"attributed": ids,
		"broken": broken.keys(),
		"lit": _lit.keys(),
	}


func from_dict(data: Dictionary) -> void:
	kills = int(data.get("kills", 0))
	knockouts = int(data.get("knockouts", 0))
	alarms = int(data.get("alarms", 0))
	alerts = int(data.get("alerts", 0))
	bodies_found = int(data.get("bodies_found", 0))
	_attributed.clear()
	for id: Variant in data.get("attributed", []):
		_attributed[int(id)] = true
	broken.clear()
	for object: Variant in data.get("broken", []):
		broken[str(object)] = true
	_lit.clear()
	for object: Variant in data.get("lit", []):
		_lit[str(object)] = true


func _observe_stimulus(entry: EventLogEntry) -> void:
	var data := entry.data
	var id := _id(data.get("id"))
	if id == 0 or UNTRACKED_TYPES.has(str(data.get("type", ""))):
		return
	if is_player(entry.source_entity()) or is_attributed(_id(data.get("cause_id"))):
		_attributed[id] = true


# The stable id of the object the entry names in `role`; an object already freed when it was
# recorded gets one from the entry itself (counted, never matched again).
static func _object_of(entry: EventLogEntry, role: StringName) -> String:
	var id := object_id(entry.entity(role))
	if not id.is_empty():
		return id
	return "#%d:%s" % [entry.tick, entry.source if role == EventLogEntry.SOURCE else entry.target]


static func _id(value: Variant) -> int:
	return int(value) if value is int or value is float else 0
