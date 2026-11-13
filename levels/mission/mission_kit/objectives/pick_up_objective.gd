class_name PickUpObjective
extends MissionObjective
## Done once the player picks up an item with the id `item_id` (EventLog `item.picked_up` whose
## source entity is a player character), wherever it lies; dropping it again does not undo it.

@export var item_id: StringName = &""


func observe(entry: EventLogEntry, context: ObjectiveContext) -> bool:
	return (
		entry.kind == EventKinds.ITEM_PICKED_UP
		and not item_id.is_empty()
		and str(entry.data.get("item", "")) == String(item_id)
		and context.is_player(entry.source_entity())
	)
