class_name SabotageObjective
extends MissionObjective
## Done once something tagged `tag` (`mission.shipment`) is destroyed (broken or exploded: gone from
## the level) or set on fire (`state.burning`, later `state.charred`), by any means.

@export var tag: StringName = &""


func check(context: ObjectiveContext) -> bool:
	return not tag.is_empty() and context.sabotaged(tag)
