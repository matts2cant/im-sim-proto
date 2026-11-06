class_name SoundAttenuator
extends Area3D
## A volume that makes noise paths through it longer by `extra_metres` (once per path), e.g. a closed
## door in a doorway (M8 toggles `enabled`). Only its CollisionShape3D children's volumes count;
## no physics monitoring is needed (ADR 0039).

const GROUP := &"sound_attenuator"

@export var extra_metres: float = 6.0
@export var enabled: bool = true


func _init() -> void:
	add_to_group(GROUP)
	monitoring = false
	monitorable = false


## True when any straight segment of the polyline passes through one of the collision shapes.
## Boxes and spheres are exact; other shapes use their local bounding box.
func crosses(points: PackedVector3Array) -> bool:
	for child in get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.disabled or collision.shape == null:
			continue
		var to_local := collision.global_transform.affine_inverse()
		var local := to_local * points
		if _polyline_hits_shape(local, collision.shape):
			return true
	return false


static func _polyline_hits_shape(local: PackedVector3Array, shape: Shape3D) -> bool:
	if shape is SphereShape3D:
		var sphere_radius := (shape as SphereShape3D).radius
		for i in range(1, local.size()):
			if StimulusPropagation.segment_intersects_sphere(local[i - 1], local[i], Vector3.ZERO, sphere_radius):
				return true
		return false
	var box: AABB
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		box = AABB(-size * 0.5, size)
	else:
		box = shape.get_debug_mesh().get_aabb()
	return StimulusPropagation.polyline_intersects_aabb(local, box)
