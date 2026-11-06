extends CharacterBody3D
## Test fixture: the smallest character controller. Falls under gravity x `gravity_scale` when off
## the floor, moves at `drive` horizontally, then move_and_slide(). Knows nothing about noise,
## falls, knockback or impacts: the generic components must work on it as they are.

var drive: Vector3 = Vector3.ZERO
var gravity_scale: float = 1.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * gravity_scale * delta
	velocity.x = drive.x
	velocity.z = drive.z
	move_and_slide()
