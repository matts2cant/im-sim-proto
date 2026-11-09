class_name ReadEntryObjective
extends MissionObjective
## Done once the player's personal log has the entry `entry_id` (a datapad read in place, ADR 0060):
## PersonalLog.has(entry_id).

@export var entry_id: StringName = &""


func check(context: ObjectiveContext) -> bool:
	return not entry_id.is_empty() and context.has_log_entry(entry_id)
