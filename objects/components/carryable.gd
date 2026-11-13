class_name Carryable
extends Node
## Component of a physics body (a RigidBody3D prop, or a character's body: ADR 0071): the player can
## pick it up if its carry mass is within the carry limit (CarryRules). `carrier` is set by the
## carrying actor (Carrier) while it is held; being picked up wakes the bodies resting on it
## (SupportWake).
## - `enabled_tags`: offered only while the entity has one of these tags (a character only while
##   `state.unconscious` or `state.dead`); empty: always.
## - `carry_mass`: the mass the carry rules use (> 0); 0 uses a RigidBody3D's own mass. Characters
##   have no physics mass: a downed guard counts as 15 kg (carried over the shoulder), within the
##   unaugmented 20 kg limit.
## - `carry_speed_factor`: the carrier's speed multiplier while holding it (on top of the heavy-load
##   factor).
## While carried it is in group `carried` (CARRIED_GROUP): a held body is a ghost that no physics
## query finds, so sensors that should still notice it (a laser tripwire, ADR 0096) look there.

signal picked_up(by: Node3D)
signal released

const CARRIED_GROUP: StringName = &"carried"

## Off: never offered for pick-up.
@export var enabled: bool = true
@export var enabled_tags: Array[StringName] = []
@export var carry_mass: float = 0.0
@export var carry_speed_factor: float = 1.0

var carrier: Node3D = null


static func of(node: Node) -> Carryable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Carryable:
			return child as Carryable
	return null


## The mass the carry rules use for `body` (its Carryable's carry_mass, else a rigid body's mass,
## else 0: not carryable).
static func mass_of(body: Node) -> float:
	var carryable := of(body)
	if carryable != null and carryable.carry_mass > 0.0:
		return carryable.carry_mass
	if body is RigidBody3D:
		return (body as RigidBody3D).mass
	return 0.0


func body() -> PhysicsBody3D:
	return get_parent() as PhysicsBody3D


## Enabled, and the entity has one of `enabled_tags` (when there are any).
func is_offered() -> bool:
	if not enabled:
		return false
	if enabled_tags.is_empty():
		return true
	var tags := Tags.of(get_parent())
	return tags != null and tags.container.has_any(enabled_tags)


func is_carried() -> bool:
	return is_instance_valid(carrier)


func set_carrier(by: Node3D) -> void:
	carrier = by
	if by != null:
		add_to_group(CARRIED_GROUP)
		# A held body is a ghost (no collision): what rested on it falls (ADR 0055).
		SupportWake.wake_touching(body())
		picked_up.emit(by)
	else:
		remove_from_group(CARRIED_GROUP)
		released.emit()
