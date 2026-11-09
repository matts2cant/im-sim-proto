class_name ObjectiveTracker
extends RefCounted
## Pure: a mission's objectives and which are done (ADR 0087). update() checks the world state,
## observe() an EventLog entry; both return the objectives they completed just now (never twice).
## Main objectives gate extraction; optional ones are counted. Saved as the ids done.

var objectives: Array[MissionObjective] = []
var done: Array[StringName] = []


func _init(p_objectives: Array[MissionObjective] = []) -> void:
	objectives = p_objectives


func is_done(id: StringName) -> bool:
	return done.has(id)


## Checks every objective not done yet against the world state; returns the newly done ones.
func update(context: ObjectiveContext) -> Array[MissionObjective]:
	var completed: Array[MissionObjective] = []
	for objective in objectives:
		if not is_done(objective.id) and objective.check(context):
			_complete(objective, completed)
	return completed


## Offers `entry` to every objective not done yet; returns the newly done ones.
func observe(entry: EventLogEntry, context: ObjectiveContext) -> Array[MissionObjective]:
	var completed: Array[MissionObjective] = []
	for objective in objectives:
		if not is_done(objective.id) and objective.observe(entry, context):
			_complete(objective, completed)
	return completed


## Every main (not optional) objective is done.
func main_done() -> bool:
	for objective in objectives:
		if not objective.optional and not is_done(objective.id):
			return false
	return true


## The first main objective not done yet, or null.
func first_missing() -> MissionObjective:
	for objective in objectives:
		if not objective.optional and not is_done(objective.id):
			return objective
	return null


func optional_total() -> int:
	return objectives.filter(func(objective: MissionObjective) -> bool: return objective.optional).size()


func optional_done() -> int:
	return (
		objectives
		. filter(func(objective: MissionObjective) -> bool: return objective.optional and is_done(objective.id))
		. size()
	)


func to_dict() -> Dictionary:
	var ids: Array[String] = []
	for id in done:
		ids.append(String(id))
	return {"done": ids}


func from_dict(data: Dictionary) -> void:
	done.clear()
	for id: Variant in data.get("done", []):
		done.append(StringName(str(id)))


func _complete(objective: MissionObjective, completed: Array[MissionObjective]) -> void:
	done.append(objective.id)
	completed.append(objective)
