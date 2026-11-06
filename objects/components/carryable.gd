class_name Carryable
extends Node
## Component of a RigidBody3D: the player can pick it up if its mass is within the carry limit
## (CarryRules). `carrier` is set by the carrying actor (PlayerCarry) while it is held.

signal picked_up(by: Node3D)
signal released

## Off: never offered for pick-up.
@export var enabled: bool = true

var carrier: Node3D = null


static func of(node: Node) -> Carryable:
	for child in node.get_children():
		if child is Carryable:
			return child as Carryable
	return null


func body() -> RigidBody3D:
	return get_parent() as RigidBody3D


func is_carried() -> bool:
	return is_instance_valid(carrier)


func set_carrier(by: Node3D) -> void:
	carrier = by
	if by != null:
		picked_up.emit(by)
	else:
		released.emit()
