extends RefCounted
## Test helper (not a suite): measures the collision geometry kit parts generate.

## Two faces closer than this to the same plane render on top of each other (z-fighting).
const COPLANAR_TOLERANCE := 0.001
## Overlaps smaller than this (m²) are rounding slivers along shared edges, not visible faces.
const MIN_OVERLAP_AREA := 0.0001
## The same for small mesh parts (device models): 1 mm².
const MIN_MESH_OVERLAP_AREA := 0.000001
## Mesh parts printed on a surface sit 0.5 mm proud on purpose (reverse-Z depth keeps them apart):
## closer than this counts as the same plane.
const MESH_COPLANAR_TOLERANCE := 0.0002


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
## Returns false after `timeout_ms` of real time without one: an asynchronous map syncs on a worker
## thread, which takes real time, not frames (a frame cap is a few ms at the runner's fixed fps).
static func wait_for_navigation(tree: SceneTree, map: RID, probe: Vector3, timeout_ms: int = 5000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while true:
		var synced := NavigationServer3D.map_get_iteration_id(map) > 0
		if synced and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) < 0.2:
			return true
		if Time.get_ticks_msec() > deadline:
			return false
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


## The mesh counterpart of coplanar_material_overlaps() (device models, ADR 0130): pairs of visible
## faces of different MeshInstance3D nodes under `root` that lie on the same plane, face the same
## way, overlap by more than MIN_MESH_OVERLAP_AREA (small parts: a port light is 2 x 5 mm) and have
## different materials. Faces are bucketed by plane, so a few hundred meshes stay cheap. Meshes
## built in _ready need `root` in the tree. Returns one readable line per offending pair and plane.
static func coplanar_mesh_overlaps(root: Node) -> PackedStringArray:
	var names: Array[String] = []
	var buckets: Dictionary[String, Array] = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or not _visible_under(instance, root):
			continue
		var index := names.size()
		names.append(str(root.get_path_to(instance)))
		var xform := _transform_under(instance, root)
		for surface in instance.mesh.get_surface_count():
			for face in _surface_faces(instance.mesh, surface, xform, _material_of(instance, surface)):
				var key := _plane_key(face)
				if not buckets.has(key):
					buckets[key] = []
				buckets[key].append([index, face])
	var found := {}
	for key: String in buckets:
		var here: Array = buckets[key]
		var next: Array = buckets.get(_next_key(key), [])
		for i in here.size():
			for j in range(i + 1, here.size() + next.size()):
				var other: Array = here[j] if j < here.size() else next[j - here.size()]
				_check_mesh_pair(here[i], other, names, found)
	return PackedStringArray(found.keys())


static func _check_mesh_pair(a: Array, b: Array, names: Array[String], found: Dictionary) -> void:
	if a[0] == b[0]:
		return
	var face_a: Dictionary = a[1]
	var face_b: Dictionary = b[1]
	if face_a["material"] == face_b["material"] or not _same_plane(face_a, face_b, MESH_COPLANAR_TOLERANCE):
		return
	if _overlap_area(face_a, face_b) > MIN_MESH_OVERLAP_AREA:
		var plane := Plane(face_a["normal"], face_a["d"])
		found["%s / %s on %s" % [names[a[0]], names[b[0]], plane]] = true


static func _material_of(instance: MeshInstance3D, surface: int) -> Material:
	if instance.material_override != null:
		return instance.material_override
	var material := instance.get_surface_override_material(surface)
	return material if material != null else instance.mesh.surface_get_material(surface)


# The plane bucket of a face: its normal in hundredths and its distance in steps of
# MESH_COPLANAR_TOLERANCE; faces that close to each other fall in the same or the next bucket.
static func _plane_key(face: Dictionary) -> String:
	var n: Vector3 = face["normal"]
	var d := floori((face["d"] as float) / MESH_COPLANAR_TOLERANCE)
	return "%d,%d,%d|%d" % [roundi(n.x * 100.0), roundi(n.y * 100.0), roundi(n.z * 100.0), d]


static func _next_key(key: String) -> String:
	var parts := key.split("|")
	return "%s|%d" % [parts[0], parts[1].to_int() + 1]


static func _surface_faces(mesh: Mesh, surface: int, xform: Transform3D, material: Material) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for k in range(0, count, 3):
		var corners: Array[Vector3] = []
		for c in 3:
			corners.append(xform * vertices[indices[k + c] if not indices.is_empty() else k + c])
		var normal := (corners[2] - corners[0]).cross(corners[1] - corners[0])
		if normal.length() < 1e-12:
			continue
		normal = normal.normalized()
		var box := AABB(corners[0], Vector3.ZERO).expand(corners[1]).expand(corners[2])
		faces.append(
			{"corners": corners, "normal": normal, "d": normal.dot(corners[0]), "material": material, "bounds": box}
		)
	return faces


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


static func _same_plane(a: Dictionary, b: Dictionary, tolerance: float = COPLANAR_TOLERANCE) -> bool:
	if (a["normal"] as Vector3).dot(b["normal"]) < 0.9999:
		return false
	if absf((a["d"] as float) - (b["d"] as float)) > tolerance:
		return false
	return (a["bounds"] as AABB).grow(tolerance).intersects(b["bounds"])


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
