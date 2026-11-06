class_name SupportWake
extends RefCounted
## Wakes the physics props resting on or touching a body that stops supporting them (ADR 0055).
## Jolt never wakes a sleeping body when the body under it is removed or loses its collision, so a
## settled stack would hang in the air when its bottom crate breaks or is picked up.
## Found by a box query (the body's shapes' bounds grown by MARGIN) on the objects layer; every
## body found is woken and searched in turn, so a whole column above wakes, not only the first.
## Callers: PhysicsObject (leaving the tree), Carryable (picked up), Breakable (non-prop entities).

## How far beyond a body's shapes a neighbour still counts as touching (gap, surface to surface).
## Resting contacts sit within Jolt's few-centimetre contact distance.
const MARGIN: float = 0.05
## Most bodies one call wakes (a large pile stays a bounded amount of work).
const MAX_BODIES: int = 64


## Wakes every rigid body touching `body` (and those touching them); returns how many were woken.
## Safe to call from `_exit_tree`: `body` itself is never woken and need not stay in the space.
static func wake_touching(body: CollisionObject3D) -> int:
	if body == null or not body.is_inside_tree():
		return 0
	var world := body.get_world_3d()
	if world == null:
		return 0
	var space := world.direct_space_state
	var seen: Array[RID] = [body.get_rid()]
	var queue: Array[CollisionObject3D] = [body]
	var woken := 0
	while not queue.is_empty() and woken < MAX_BODIES:
		var query := grown_query(queue.pop_front() as CollisionObject3D, seen)
		if query == null:
			continue
		for hit in space.intersect_shape(query, MAX_BODIES):
			var other := hit["collider"] as RigidBody3D
			if other == null or seen.has(other.get_rid()):
				continue
			seen.append(other.get_rid())
			other.sleeping = false
			woken += 1
			queue.append(other)
	return woken


## Box query around `body`: its shapes' local bounds grown by MARGIN on every side, placed at the
## body (scale ignored), objects layer, excluding `exclude`. Null when it has no enabled shape.
static func grown_query(body: CollisionObject3D, exclude: Array[RID]) -> PhysicsShapeQueryParameters3D:
	var bounds := shapes_bounds(body)
	if bounds.size == Vector3.ZERO:
		return null
	var box := BoxShape3D.new()
	box.size = bounds.size + Vector3.ONE * MARGIN * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = body.global_transform.orthonormalized() * Transform3D(Basis(), bounds.get_center())
	query.collision_mask = PhysicsLayers.OBJECTS
	query.exclude = exclude
	return query


## Local-space bounds of `body`'s enabled CollisionShape3D children (zero size when none).
static func shapes_bounds(body: CollisionObject3D) -> AABB:
	var bounds := AABB()
	var first := true
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null or collision.disabled:
			continue
		var local := collision.transform * collision.shape.get_debug_mesh().get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds
