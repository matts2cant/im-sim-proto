class_name DeviceSurface
extends RefCounted
## Pure geometry (M13 playtest fix, ADR 0122 amendment): the surfaces of an entity's visible meshes
## (MeshInstance3D) seen from its front (+Z, as wall-mounted devices are built), and the spots on
## them where a small part (StatusLight's LED and port lights) sits flat. A ray along -Z from in front
## of the entity finds the surface; a spot is good when the part's whole square footprint lands on
## one mesh, on a face turned to the front (normal z >= MIN_FACING) and within FLAT_DEPTH of the
## plane through its centre. Each spot names the mesh it sits on (its carrier) so the part can ride
## on it when that piece of the device moves (a door's leaf, a camera's head).


## A place on the surface: `transform` is in the entity's frame, its origin on the surface and its
## +Z out of it (the surface normal); `carrier` is the node the part goes under.
class Spot:
	extends RefCounted
	var carrier: Node3D
	var transform: Transform3D

	func _init(p_carrier: Node3D, p_transform: Transform3D) -> void:
		carrier = p_carrier
		transform = p_transform

	## The surface normal (entity frame).
	func normal() -> Vector3:
		return transform.basis.z


## Lowest normal z of a face a part may sit on (about 45 degrees off the front).
const MIN_FACING: float = 0.7
## How far (m) a footprint corner may lie off the plane through the part's centre.
const FLAT_DEPTH: float = 0.004
## Finest scan step (m); coarser on big entities so a scan casts at most MAX_SCAN centre rays.
const SCAN_STEP: float = 0.005
const MAX_SCAN: int = 2500
const CORNERS: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]

## The visible faces' bounds in the entity's frame (empty without a visible mesh).
var bounds: AABB = AABB()
var _mesh: TriangleMesh
var _carriers: Array[MeshInstance3D] = []
## Per carrier: the number of faces up to and including its own.
var _ends: PackedInt32Array = PackedInt32Array()


## The visible meshes of `entity` (in the tree), leaving out those under `skip`.
func _init(entity: Node3D, skip: Node = null) -> void:
	var to_local := entity.global_transform.affine_inverse()
	var faces := PackedVector3Array()
	for node in entity.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		if skip != null and skip.is_ancestor_of(part):
			continue
		var own := part.mesh.get_faces()
		if own.is_empty():
			continue
		var place := to_local * part.global_transform
		for vertex in own:
			faces.append(place * vertex)
		_carriers.append(part)
		_ends.append(faces.size() / 3)
	if faces.is_empty():
		return
	bounds = AABB(faces[0], Vector3.ZERO)
	for vertex in faces:
		bounds = bounds.expand(vertex)
	_mesh = TriangleMesh.new()
	_mesh.create_from_faces(faces)


## True without any visible mesh.
func is_empty() -> bool:
	return _mesh == null


## Where a ray along -Z through (x, y) (entity frame) first meets the surface, or null.
func project(x: float, y: float) -> Spot:
	if _mesh == null:
		return null
	var hit := _mesh.intersect_ray(Vector3(x, y, bounds.end.z + 0.05), Vector3.FORWARD)
	if hit.is_empty():
		return null
	var normal: Vector3 = (hit["normal"] as Vector3).normalized()
	if normal.z < 0.0:
		normal = -normal
	return Spot.new(_carrier_of(hit["face_index"] as int), Transform3D(facing(normal), hit["position"] as Vector3))


## The top-left-most spot (rows from the top, each row from the left) where a square part of
## half-size `half` (m) sits flat on a front-facing face, or null.
func find_spot(half: float) -> Spot:
	if _mesh == null:
		return null
	var step := maxf(SCAN_STEP, sqrt(bounds.size.x * bounds.size.y / float(MAX_SCAN)))
	var y := bounds.end.y - half
	while y >= bounds.position.y + half - 0.0001:
		var x := bounds.position.x + half
		while x <= bounds.end.x - half + 0.0001:
			var spot := flat_spot(x, y, half)
			if spot != null:
				return spot
			x += step
		y -= step
	return null


## The spot at (x, y) when a square part of half-size `half` sits flat there, else null.
func flat_spot(x: float, y: float, half: float) -> Spot:
	var centre := project(x, y)
	if centre == null or centre.normal().z < MIN_FACING:
		return null
	var n := centre.normal()
	var origin := centre.transform.origin
	for corner in CORNERS:
		var offset := corner * half
		var other := project(x + offset.x, y + offset.y)
		if other == null or other.carrier != centre.carrier or other.normal().z < MIN_FACING:
			return null
		# The depth the centre's plane has at this corner.
		var expected := origin.z - (n.x * offset.x + n.y * offset.y) / n.z
		if absf(other.transform.origin.z - expected) > FLAT_DEPTH:
			return null
	return centre


## A basis whose +Z is `normal` (identity for the plain front).
static func facing(normal: Vector3) -> Basis:
	if normal.is_equal_approx(Vector3.BACK) or absf(normal.y) > 0.99:
		return Basis.IDENTITY
	return Basis.looking_at(normal, Vector3.UP, true)


func _carrier_of(face: int) -> MeshInstance3D:
	for i in _ends.size():
		if face < _ends[i]:
			return _carriers[i]
	return _carriers[_carriers.size() - 1]
