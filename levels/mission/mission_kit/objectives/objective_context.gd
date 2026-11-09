class_name ObjectiveContext
extends RefCounted
## What mission objectives may ask about the world (ADR 0087). The Mission answers from the player's
## components and tagged entities (MissionContext); unit tests use a stand-in. This base answers no
## to everything.


## The player's PersonalLog has the entry `entry_id` (PersonalLog.has()).
func has_log_entry(_entry_id: StringName) -> bool:
	return false


## `entity_name` (an EventLog source) is a player character (an entity tagged as the mission's
## player).
func is_player(_entity_name: String) -> bool:
	return false


## Something tagged `tag` was destroyed (gone from the level: broken, exploded) or set on fire
## (`state.burning`, `state.charred`).
func sabotaged(_tag: StringName) -> bool:
	return false
