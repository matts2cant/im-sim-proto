extends RefCounted
## Test helper (not a suite): how a level mounts a device (ADR 0130 step 3), by property only: a rack
## unit in a linking bay (a LinkingBay above it in the tree), desk gear standing on something (its
## visible box rests on a surface below it, not the floor), else wall gear. Also the checks every bay
## in a level passes: on the floor, its back against a wall, and room in front of it.

enum Mount { WALL, BAY, DESK }

const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
## How far desk gear may float over its desk (m).
const DESK_GAP := 0.01
## How far a bay's back may stand off its wall (m).
const BAY_WALL_GAP := 0.02
## Room kept clear in front of a bay (m): AGENTS.md / the step 3 brief.
const BAY_CLEARANCE := 1.0


## The linking bay `entity` is mounted in, or null.
static func bay_of(entity: Node) -> LinkingBay:
	var node := entity.get_parent() if entity != null else null
	while node != null:
		if node is LinkingBay:
			return node as LinkingBay
		node = node.get_parent()
	return null


## The gap (m) between the bottom of `entity`'s visible box and the surface under its centre (a ray
## down from 5 cm above the bottom, its own body ignored); INF when nothing is within 0.3 m.
static func support_gap(entity: Node3D) -> float:
	var box := WallDeviceChecks.visual_box(entity)
	var centre := box.get_center()
	var from := Vector3(centre.x, box.position.y + 0.05, centre.z)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 0.35, PhysicsLayers.WORLD)
	if entity is CollisionObject3D:
		query.exclude = [(entity as CollisionObject3D).get_rid()]
	var hit := entity.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return INF
	return box.position.y - (hit["position"] as Vector3).y


## How `entity` is mounted.
static func mount(entity: Node3D) -> Mount:
	if bay_of(entity) != null:
		return Mount.BAY
	if absf(support_gap(entity)) <= DESK_GAP:
		return Mount.DESK
	return Mount.WALL


## Every LinkingBay under `root`.
static func bays(root: Node) -> Array[LinkingBay]:
	var found: Array[LinkingBay] = []
	for node in root.find_children("*", "LinkingBay", true, false):
		found.append(node as LinkingBay)
	return found


## What is wrong with `bay`'s placement, empty when nothing: it stands on the floor (its origin at
## `floor_y`), its back within BAY_WALL_GAP of a wall, and a box as wide and as high as the bay reaches
## BAY_CLEARANCE m out of its front without meeting anything solid (its own door excluded).
static func bay_problems(bay: LinkingBay, floor_y: float) -> PackedStringArray:
	var found := PackedStringArray()
	var space := bay.get_world_3d().direct_space_state
	var xform := bay.global_transform
	if absf(xform.origin.y - floor_y) > 0.005:
		found.append("%s: not on the floor (%.3f)" % [bay.name, xform.origin.y])
	var mine: Array[RID] = []
	for node in bay.find_children("*", "CollisionObject3D", true, false):
		mine.append((node as CollisionObject3D).get_rid())
	# The wall behind: a ray back from just inside the bay's back at 1 m height.
	var back := xform * Vector3(0.0, 1.0, -LinkingBay.DEPTH * 0.5 + 0.01)
	var behind := PhysicsRayQueryParameters3D.create(
		back, xform * Vector3(0.0, 1.0, -LinkingBay.DEPTH * 0.5 - 0.5), PhysicsLayers.WORLD
	)
	behind.exclude = mine
	var wall := space.intersect_ray(behind)
	if wall.is_empty() or back.distance_to(wall["position"]) > BAY_WALL_GAP + 0.01:
		found.append("%s: its back is not against a wall" % bay.name)
	# Room in front: the bay's width, from 5 cm over the floor to its top, BAY_CLEARANCE m deep.
	var shape := BoxShape3D.new()
	shape.size = Vector3(LinkingBay.WIDTH, LinkingBay.HEIGHT - 0.05, BAY_CLEARANCE)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = PhysicsLayers.WORLD
	query.exclude = mine
	query.transform = (
		xform
		* Transform3D(
			Basis.IDENTITY, Vector3(0.0, 0.05 + shape.size.y * 0.5, LinkingBay.DEPTH * 0.5 + 0.05 + BAY_CLEARANCE * 0.5)
		)
	)
	for hit in space.intersect_shape(query, 8):
		found.append("%s: %s stands within %.1f m of its front" % [bay.name, hit["collider"], BAY_CLEARANCE])
	return found
