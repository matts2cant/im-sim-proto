extends RefCounted
## Test helper (not a suite, ADR 0098): checks a door's wall boxes against the world they hang in.
## problems() returns what is wrong with each box, empty when every box
## - is flush on a wall surface: a ray from 2 cm inside the box, near each corner of its back face,
##   meets the world (not the door) 2 cm behind, so no corner floats or overhangs an edge;
## - is not inside a wall: the box shrunk by 4 mm overlaps nothing on the world layer;
## - is clear of the leaf's sweep (closed to open, with its handle);
## and the door has the same number of boxes on both faces.

## How far (m) the wall may be from a box's back face and still count as flush.
const FLUSH_TOLERANCE := 0.004


## What is wrong with the wall boxes of `door` (a door in a level whose collision is built).
static func problems(door: Door) -> PackedStringArray:
	var found := PackedStringArray()
	var front := door.hardware.controls(true)
	var back := door.hardware.controls(false)
	var label := String(door.entity.name)
	if front.size() != back.size():
		found.append("%s: %d boxes on its front, %d on its back" % [label, front.size(), back.size()])
	var sweep := DoorLayout.sweep(door.settings, door.wall_thickness)
	for box: StaticBody3D in front + back:
		var where := "%s/%s" % [label, box.name]
		var size := ((box.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
		found.append_array(_flush(door, box, size, where))
		if _inside_wall(door, box, size):
			found.append("%s: inside a wall" % where)
		var local := box.transform * AABB(Vector3(-size.x * 0.5, -size.y * 0.5, 0.0), size)
		if local.intersects(sweep):
			found.append("%s: in the leaf's sweep %s" % [where, sweep])
	return found


# Rays from 2 cm inside the box near its back face's corners, straight back: each must meet the
# world 2 cm away.
static func _flush(door: Door, box: StaticBody3D, size: Vector3, where: String) -> PackedStringArray:
	var found := PackedStringArray()
	var space := box.get_world_3d().direct_space_state
	var inset := Vector2(size.x * 0.5 - 0.01, size.y * 0.5 - 0.01)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var from := box.global_transform * Vector3(corner.x * inset.x, corner.y * inset.y, 0.02)
		var to := box.global_transform * Vector3(corner.x * inset.x, corner.y * inset.y, -0.03)
		var query := PhysicsRayQueryParameters3D.create(
			from, to, PhysicsLayers.WORLD, [box.get_rid(), door.entity.get_rid()]
		)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			found.append("%s: nothing behind its corner %s (floating)" % [where, corner])
			continue
		var gap := from.distance_to(hit["position"] as Vector3) - 0.02
		if absf(gap) > FLUSH_TOLERANCE:
			found.append("%s: its corner %s is %.3f m off the wall" % [where, corner, gap])
	return found


# True when the box, shrunk by 4 mm, overlaps anything on the world layer but itself and the door.
static func _inside_wall(door: Door, box: StaticBody3D, size: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = size - Vector3.ONE * 0.008
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = box.global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, size.z * 0.5))
	query.collision_mask = PhysicsLayers.WORLD
	query.exclude = [box.get_rid(), door.entity.get_rid()]
	return not box.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
