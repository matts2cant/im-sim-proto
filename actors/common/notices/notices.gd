class_name Notices
extends Node
## Component of an entity that is told short notices ("No room in inventory", "Energy depleted",
## "Cracked kbrandt: added to the Journal"): the one path from any system to whatever shows them to
## that entity (ADR 0133). A system calls Notices.send(entity, text) (or notify() on the component);
## an entity without a Notices child is simply not told. The Player's HUD shows them above the belt;
## the deck's screen shows them in its toast while it is raised.

## A notice for this entity.
signal posted(text: String)


## The Notices child of `entity`, or null.
static func of(entity: Node) -> Notices:
	if entity == null or not is_instance_valid(entity):
		return null
	for child in entity.get_children():
		if child is Notices:
			return child as Notices
	return null


## Tells `entity` `text` (nothing when it has no Notices).
static func send(entity: Node, text: String) -> void:
	var notices := of(entity)
	if notices != null:
		notices.notify(text)


func notify(text: String) -> void:
	posted.emit(text)
