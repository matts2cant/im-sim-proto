class_name Computer
extends Node
## STUB (M12a-net): the contract with the computers' branch (Halcyon OS). The owner's file replaces
## this one at merge; only the signature below is relied on by the deck.

## Emitted when a desktop opened with `remote` closes.
signal desktop_closed


## Opens this computer's desktop for `viewer` logged in as `user`; `remote` when used from a deck.
func open_desktop(_viewer: Node, _user: String, _remote: bool) -> void:
	pass


## The Computer component on `entity`, or null.
static func of(entity: Node) -> Computer:
	if entity == null:
		return null
	if entity is Computer:
		return entity as Computer
	for child in entity.get_children():
		if child is Computer:
			return child as Computer
	return null
