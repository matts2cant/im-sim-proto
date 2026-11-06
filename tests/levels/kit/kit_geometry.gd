extends RefCounted
## Test helper (not a suite): measures the collision geometry kit parts generate.


## Bounds of a CSG root's collision faces in its local space (computed out of the tree).
static func collision_aabb(part: CSGShape3D) -> AABB:
	var shape := part.bake_collision_shape()
	if shape == null or shape.get_faces().is_empty():
		return AABB()
	var faces := shape.get_faces()
	var bounds := AABB(faces[0], Vector3.ZERO)
	for point: Vector3 in faces:
		bounds = bounds.expand(point)
	return bounds


## True when `a` and `b` match to within `tolerance` metres on every face of the box.
static func aabb_matches(a: AABB, b: AABB, tolerance: float = 0.001) -> bool:
	return a.position.distance_to(b.position) <= tolerance and a.end.distance_to(b.end) <= tolerance


## Generated (internal) CSG children of a kit part.
static func generated_children(part: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in part.get_children(true):
		if child.owner == null:
			result.append(child)
	return result


## Waits for CSG to build its deferred collision.
static func settle(tree: SceneTree, frames: int = 3) -> void:
	for i in frames:
		await tree.physics_frame


## First hit of a ray between two global points ({} when nothing is hit): collider, position...
static func ray(world: World3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return world.direct_space_state.intersect_ray(query)


## Waits until the navigation map has synced a navmesh under `probe` (a point known to be on it).
## Returns false after `frames` physics frames without one.
static func wait_for_navigation(tree: SceneTree, map: RID, probe: Vector3, frames: int = 120) -> bool:
	for i in frames:
		var synced := NavigationServer3D.map_get_iteration_id(map) > 0
		if synced and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 0.2:
			return true
		await tree.physics_frame
	return false
