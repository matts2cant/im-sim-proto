class_name MissionTally
extends RefCounted
## Pure: a mission's tallies and badges from EventLog entries (ADR 0087), no scene tree.
## - Attribution: a stimulus is the player's when its source is a player (`player_names`) or its
##   cause (`cause_id`) is one of the player's: so the blast of a barrel the player shot, the fire it
##   lit and that fire's pulses are the player's too. A device command a player operated (a computer:
##   `device.command` with `by`) is the player's, and so is what it starts (a turret's shots name the
##   command that retargeted it as their cause, WeaponHolder.cause_id). Noise never harms and is not
##   tracked.
## - Kills: `actor.died` of anyone but a player whose killing stimulus (`by`) is the player's.
##   Knockouts: `actor.knocked_out` the same way.
## - Alarms: `alarm.raised` that started a ring (not `again`). Alerts: `actor.awareness` to
##   `alerted`. Bodies found: `actor.body_found`.
## - Broken (M12c, ADR 0115): the objects the player broke, by name: any Breakable whose health
##   reaches 0 under the player's damage (`object.damaged` with `health` <= 0 and an attributed
##   `by`: props that fall apart and devices that keep their broken husk alike), that explodes from
##   the player's stimulus (`object.exploded`), or that burns out after the player set it alight
##   (`object.ignited` then `object.broken` reason `burnt_out`).
## - Ghost: no alert, no alarm, no body found (Suspicious is fine). Pacifist: no kill. Clean hands:
##   nothing broken.
## Not attributed (known gaps): a thrown prop's impact (its source is the prop; a crate thrown to
## pieces breaks no clean hands) and fall damage after a push (the faller is its own source).
## Saved with the mission (to_dict); attributed stimulus ids stay valid across a load because the
## quicksave reserves them (StimulusSystem.reserve_ids, QuickSave.STIMULUS_IDS).

const EMITTED: StringName = &"stimulus.emitted"
const COMMAND: StringName = &"device.command"
const DIED: StringName = &"actor.died"
const KNOCKED_OUT: StringName = &"actor.knocked_out"
const ALARM: StringName = &"alarm.raised"
const AWARENESS: StringName = &"actor.awareness"
const BODY_FOUND: StringName = &"actor.body_found"
const DAMAGED: StringName = &"object.damaged"
const EXPLODED: StringName = &"object.exploded"
const IGNITED: StringName = &"object.ignited"
const BROKEN: StringName = &"object.broken"
const BURNT_OUT: String = "burnt_out"
const ALERTED: String = "alerted"
const UNTRACKED_TYPES: Array[String] = ["noise"]

## EventLog source names of the player characters.
var player_names: Array[String] = []
var kills: int = 0
var knockouts: int = 0
var alarms: int = 0
var alerts: int = 0
var bodies_found: int = 0
## Names of the objects the player broke (name -> true).
var broken: Dictionary[String, bool] = {}

## Ids of the player's stimuli (stimulus id -> true).
var _attributed: Dictionary[int, bool] = {}
## Names of the objects the player set alight (name -> true).
var _lit: Dictionary[String, bool] = {}


func _init(p_player_names: Array[String] = []) -> void:
	player_names = p_player_names


func is_player(entity_name: String) -> bool:
	return not entity_name.is_empty() and player_names.has(entity_name)


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
		EMITTED:
			_observe_stimulus(data)
		COMMAND:
			if is_player(str(data.get("by", ""))) and data.get("stimulus") is int:
				_attributed[int(data["stimulus"])] = true
		DIED:
			if not is_player(entry.target) and is_attributed(_id(data.get("by"))):
				kills += 1
		KNOCKED_OUT:
			if not is_player(entry.target) and is_attributed(_id(data.get("by"))):
				knockouts += 1
		ALARM:
			if not bool(data.get("again", false)):
				alarms += 1
		AWARENESS:
			if str(data.get("to", "")) == ALERTED:
				alerts += 1
		BODY_FOUND:
			bodies_found += 1
		DAMAGED:
			if float(data.get("health", 1.0)) <= 0.0 and is_attributed(_id(data.get("by"))):
				broken[str(data.get("object", entry.target))] = true
		EXPLODED:
			if is_attributed(_id(data.get("by"))):
				broken[str(data.get("object", entry.source))] = true
		IGNITED:
			if is_attributed(_id(data.get("by"))):
				_lit[str(data.get("object", entry.source))] = true
		BROKEN:
			var object := str(data.get("object", entry.source))
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


func _observe_stimulus(data: Dictionary) -> void:
	var id := _id(data.get("id"))
	if id == 0 or UNTRACKED_TYPES.has(str(data.get("type", ""))):
		return
	if is_player(str(data.get("source", ""))) or is_attributed(_id(data.get("cause_id"))):
		_attributed[id] = true


static func _id(value: Variant) -> int:
	return int(value) if value is int or value is float else 0
