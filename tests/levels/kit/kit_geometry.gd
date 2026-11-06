extends RefCounted
## Test helper (not a suite): measures the collision geometry kit parts generate.

## Two faces closer than this to the same plane render on top of each other (z-fighting).
const COPLANAR_TOLERANCE := 0.001
## Overlaps smaller than this (m²) are rounding slivers along shared edges, not visible faces.
const MIN_OVERLAP_AREA := 0.0001


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


## Pairs of visible faces from different CSG roots under `level` that lie on the same plane,
## face the same way, overlap and have different materials: these z-fight (e.g. a ceiling slab
## ending flush with a neighbouring room's wall face). Same-material overlaps render identically
## and are allowed: neighbouring rooms share their wall. `level` must be in the tree and settled
## (CSG builds its meshes a frame after load).
## Returns one readable line per offending pair of roots and planes.
static func coplanar_material_overlaps(level: Node) -> PackedStringArray:
	var parts: Array[Dictionary] = []
	for node: Node in level.find_children("*", "CSGShape3D", true, false):
		var shape := node as CSGShape3D
		if shape.is_root_shape() and _visible_under(shape, level):
			parts.append(_baked_faces(shape, _transform_under(shape, level)))
	var found := {}
	for i in parts.size():
		for j in range(i + 1, parts.size()):
			if not (parts[i]["bounds"] as AABB).grow(COPLANAR_TOLERANCE).intersects(parts[j]["bounds"]):
				continue
			for a: Dictionary in parts[i]["faces"]:
				for b: Dictionary in parts[j]["faces"]:
					if a["material"] == b["material"] or not _same_plane(a, b):
						continue
					if _overlap_area(a, b) > MIN_OVERLAP_AREA:
						var plane := Plane(a["normal"], a["d"])
						found["%s / %s on %s" % [parts[i]["path"], parts[j]["path"], plane]] = true
	return PackedStringArray(found.keys())


static func _baked_faces(shape: CSGShape3D, xform: Transform3D) -> Dictionary:
	var faces: Array[Dictionary] = []
	var bounds := AABB()
	var mesh := shape.bake_static_mesh()
	for surface in mesh.get_surface_count() if mesh != null else 0:
		var material := mesh.surface_get_material(surface)
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for k in range(0, count, 3):
			var corners: Array[Vector3] = []
			for c in 3:
				var index := indices[k + c] if not indices.is_empty() else k + c
				corners.append(xform * vertices[index])
			# Godot front faces wind clockwise: this cross product points out of the visible side.
			var normal := (corners[2] - corners[0]).cross(corners[1] - corners[0])
			if normal.length() < 1e-9:
				continue
			normal = normal.normalized()
			var box := AABB(corners[0], Vector3.ZERO).expand(corners[1]).expand(corners[2])
			bounds = box if faces.is_empty() else bounds.merge(box)
			(
				faces
				. append(
					{
						"corners": corners,
						"normal": normal,
						"d": normal.dot(corners[0]),
						"material": material,
						"bounds": box,
					}
				)
			)
	return {"path": str(shape.name), "faces": faces, "bounds": bounds}


static func _same_plane(a: Dictionary, b: Dictionary) -> bool:
	if (a["normal"] as Vector3).dot(b["normal"]) < 0.9999:
		return false
	if absf((a["d"] as float) - (b["d"] as float)) > COPLANAR_TOLERANCE:
		return false
	return (a["bounds"] as AABB).grow(COPLANAR_TOLERANCE).intersects(b["bounds"])


## Area shared by two coplanar triangles (projected onto their common plane).
static func _overlap_area(a: Dictionary, b: Dictionary) -> float:
	var normal: Vector3 = a["normal"]
	var u := normal.cross(Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := normal.cross(u)
	var area := 0.0
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(_project(a, u, v), _project(b, u, v)):
		area += absf(_signed_area(polygon))
	return area


static func _project(face: Dictionary, u: Vector3, v: Vector3) -> PackedVector2Array:
	var result := PackedVector2Array()
	for corner: Vector3 in face["corners"]:
		result.append(Vector2(corner.dot(u), corner.dot(v)))
	return result


static func _signed_area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for k in polygon.size():
		sum += polygon[k].cross(polygon[(k + 1) % polygon.size()])
	return sum * 0.5


## Transform of `node` relative to `level`, without needing the scene tree.
static func _transform_under(node: Node3D, level: Node) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != null and parent != level:
		if parent is Node3D:
			result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result


static func _visible_under(node: Node3D, level: Node) -> bool:
	var current: Node = node
	while current != null and current != level:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true
