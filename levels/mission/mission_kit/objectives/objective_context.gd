class_name ObjectiveContext
extends RefCounted
## What mission objectives may ask about the world (ADR 0087). The Mission answers from the player's
## components and tagged entities (MissionContext); unit tests use a stand-in. This base answers no
## to everything.


## The player's PersonalLog has the entry `entry_id` (PersonalLog.has()).
func has_log_entry(_entry_id: StringName) -> bool:
	return false


## `entity` (an EventLog entry's entity, EventLogEntry.entity()) is a player character (tagged as
## the mission's player). Never decided by name.
func is_player(_entity: Node) -> bool:
	return false


## Something tagged `tag` was destroyed (gone from the level: broken, exploded) or set on fire
## (`state.burning`, `state.charred`).
func sabotaged(_tag: StringName) -> bool:
	return false
