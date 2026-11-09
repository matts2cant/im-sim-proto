class_name ExtractionZone
extends Area3D
## A mission's extraction area (ADR 0087; `extraction_zone.tscn`, placed by the level as
## `Extraction`): an invisible box of `size`, centred on the node in x and z, standing on its
## origin. The Mission ends the mission while an entity with
## `required_tag` (the player) that can act stands in it and every main objective is done; on
## entering before that it shows the extraction hint (`entered`).

signal entered(body: Node3D)

const GROUP: StringName = &"extraction_zone"

@export var required_tag: StringName = &"actor.player"
## The box, metres (x, y, z), standing on the node's origin.
@export var size: Vector3 = Vector3(4.0, 3.0, 4.0)


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER | PhysicsLayers.ACTORS
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Box"
	collision.shape = shape
	collision.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(collision)
	body_entered.connect(_on_body_entered)


## True while an entity with `required_tag` that can act (ActorState.can_act) stands inside: among
## the overlapping bodies, with its origin (the feet) inside the box now (the overlap list is a
## physics step old).
func holds_required() -> bool:
	for body in get_overlapping_bodies():
		if ActorState.has(body, required_tag) and ActorState.can_act(body) and contains(body.global_position):
			return true
	return false


## True when `point` (world) is inside the box.
func contains(point: Vector3) -> bool:
	var local := global_transform.affine_inverse() * point
	var half := size * 0.5
	return absf(local.x) <= half.x and absf(local.z) <= half.z and local.y >= -0.1 and local.y <= size.y


func _on_body_entered(body: Node3D) -> void:
	if ActorState.has(body, required_tag):
		entered.emit(body)
