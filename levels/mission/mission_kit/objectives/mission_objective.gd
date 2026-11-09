class_name MissionObjective
extends Resource
## One mission objective (ADR 0087), data in the mission's MissionData. What completes it is a
## subclass: a fact about component state checked every tick (check()) or an EventLog entry
## (observe()), never the identity of an entity. Main objectives (not `optional`) are needed to
## extract; optional ones are counted in the summary. Pure: an ObjectiveContext answers the
## questions about the world.

## Unique within its mission (saves and log entries use it).
@export var id: StringName = &""
## Short name: "Read the shipment manifest" (briefing, personal log, completion toast).
@export var title: String = ""
## The personal-log entry's text.
@export_multiline var description: String = ""
@export var optional: bool = false
## Shown when the player reaches the extraction while this main objective is not done ("Read the
## manifest first"). Empty: MissionData.extraction_hint.
@export var extraction_hint: String = ""


## True when the world state says it is done (called every tick until it is).
func check(_context: ObjectiveContext) -> bool:
	return false


## True when `entry` completes it (called for every EventLog entry until it is done).
func observe(_entry: EventLogEntry, _context: ObjectiveContext) -> bool:
	return false
