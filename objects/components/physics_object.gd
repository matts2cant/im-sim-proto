class_name PhysicsObject
extends RigidBody3D
## Root of a physics prop (crate, barrel, bottle): collision layer 4 (objects, ADR 0045), saveable
## body state. Behaviour lives in its component children (Flammable, Breakable, Explosive,
## ImpactNoise, Carryable) and its Tags, Attributes and StimulusReceiver, which save themselves.
## `scene_file_path` is saved so M6 can respawn objects spawned at runtime.
## Leaving the tree wakes the props resting on it (SupportWake, ADR 0055).
## Every prop is pushed by `force.*` stimuli (blasts, bullets; ADR 0057): _ready appends
## `force_receptron` to its StimulusReceiver, creating one at the body's origin when the scene has
## none (item pickups), so no prop scene repeats it.

const GROUP: StringName = &"physics_object"
const RECEIVER_NAME: String = "StimulusReceiver"

## Appended to the prop's StimulusReceiver; null: never pushed by force stimuli.
@export var force_receptron: Receptron = preload("res://objects/components/receptrons/pushed_by_force.tres")


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"saveable")
	# Props never scan the player's layer, whatever their scene says (ADR 0054).
	collision_mask &= ~PhysicsLayers.PLAYER
	if force_receptron != null:
		_add_receptron(force_receptron)


# Freed (broken, exploded, picked up into the inventory) or removed: whatever rested on it falls,
# even if asleep (ADR 0055).
func _exit_tree() -> void:
	SupportWake.wake_touching(self)


## Appends `receptron` to the prop's receiver (a new one when it has none) unless it is there.
func _add_receptron(receptron: Receptron) -> void:
	var receiver := get_node_or_null(RECEIVER_NAME) as StimulusReceiver
	if receiver == null:
		receiver = StimulusReceiver.new()
		receiver.name = RECEIVER_NAME
		add_child(receiver)
	if receiver.receptrons.has(receptron):
		return
	# A copy: instances of one scene may share the exported array.
	var list := receiver.receptrons.duplicate()
	list.append(receptron)
	receiver.receptrons = list


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
