class_name Awareness
extends Node
## Component: whether the character has noticed a threat. M4 only needs the question for the
## knockout rule (ADR 0049); M7 guard perception implements it properly. Until then it is the
## exported flag (training dummies: false, so a baton hit from behind knocks them out).

@export var aware: bool = false


static func of(node: Node) -> Awareness:
	if node == null:
		return null
	for child in node.get_children():
		if child is Awareness:
			return child as Awareness
	return null


func is_aware() -> bool:
	return aware
