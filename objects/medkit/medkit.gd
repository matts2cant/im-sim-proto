class_name Medkit
extends Usable
## Usable world medkit: heals the user's BodyParts by `heal_amount` (split over the damaged parts)
## and is used up. Refused (and kept) when the user is unhurt or dead. Becomes a 1 x 1 inventory
## item in M5; the Medicine skill scales the amount in M6.

@export var heal_amount: float = 30.0
@export var entity_path: NodePath = ^".."


func use(user: Node) -> bool:
	var entity := get_node(entity_path)
	var body := BodyParts.of(user)
	var restored := body.heal(heal_amount, String(entity.name)) if body != null else 0.0
	if restored <= 0.0:
		var data := {"object": String(entity.name), "reason": "nothing_to_heal"}
		EventLog.record(&"item.use_refused", String(user.name), String(entity.name), data)
		return true
	used.emit(user)
	entity.queue_free()
	return true
