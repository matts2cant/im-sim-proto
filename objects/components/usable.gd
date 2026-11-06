class_name Usable
extends Node
## Component: something the player can `use` (E) while looking at it, before trying to pick it up.
## Subclasses override use(); the base only emits `used` (a training dummy resets on it).

signal used(user: Node)

## What the HUD / log calls the action.
@export var verb: String = "use"


static func of(node: Node) -> Usable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Usable:
			return child as Usable
	return null


## What the prompt calls the target ("E: read Storage access"); empty: the entity's own name.
func target_name() -> String:
	return ""


## Returns true when the use did something (the player then does not try to pick the object up).
func use(user: Node) -> bool:
	used.emit(user)
	return true
