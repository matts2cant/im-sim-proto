class_name Debris
extends RigidBody3D
## A short-lived piece of a broken object: a small box that only collides with the world and is on
## no layer itself, so it never blocks the player (who has no step-up), objects or queries.
## Despawns after its lifetime. Transient: not saveable.

const GROUP: StringName = &"debris"

var lifetime: float = 10.0
var _age: float = 0.0


## Builds the shape and mesh; call before adding it to the tree.
func setup(piece_size: float, color: Color, p_lifetime: float, p_mass: float) -> void:
	name = "Debris"
	lifetime = p_lifetime
	collision_layer = 0
	collision_mask = PhysicsLayers.WORLD
	mass = p_mass
	var size := Vector3(piece_size, piece_size * 0.4, piece_size * 0.7)
	var box := BoxShape3D.new()
	box.size = size
	var collision := CollisionShape3D.new()
	collision.shape = box
	add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	add_child(visual)
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
