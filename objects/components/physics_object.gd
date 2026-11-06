class_name PhysicsObject
extends RigidBody3D
## Root of a physics prop (crate, barrel, bottle): collision layer 4 (objects, ADR 0045), saveable
## body state. Behaviour lives in its component children (Flammable, Breakable, Explosive,
## ImpactNoise, Carryable) and its Tags, Attributes and StimulusReceiver, which save themselves.
## `scene_file_path` is saved so M6 can respawn objects spawned at runtime.

const GROUP: StringName = &"physics_object"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	# Props never scan the player's layer, whatever their scene says (ADR 0054).
	collision_mask &= ~PhysicsLayers.PLAYER


func save_state() -> Dictionary:
	return {
		"scene_file_path": scene_file_path,
		"transform": global_transform,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity,
	}


func load_state(data: Dictionary) -> void:
	global_transform = data.get("transform", global_transform)
	linear_velocity = data.get("linear_velocity", linear_velocity)
	angular_velocity = data.get("angular_velocity", angular_velocity)
