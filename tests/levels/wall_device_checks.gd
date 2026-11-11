extends RefCounted
## Test helper (not a suite): checks that what a level hangs on its walls keeps clear of its doors and
## signs. problems() lists every overlap, empty when none:
## - devices: every entity with a Device that is not a door (sirens, cameras, laser arrays, alarm
##   controllers, panic buttons, switches, terminals, turrets), boxed by its visible geometry;
## - wall locks: every entity with a Lock that is not a door (the practice locks), boxed the same way;
## - wall boxes: every door's keypads, card readers and control panels (DoorHardware), boxed by their
##   collision shape (their own door is door_hardware_checks.gd's business);
## against
## - every doorway's opening, from the floor to the leaf's top and OPENING_DEPTH m out of both wall
##   faces (a siren hanging in front of a door leaf);
## - every door leaf's sweep, closed to open, with its handle (DoorLayout.sweep);
## - every sign's text (a camera drawn over FIRE EXIT), grown by SIGN_MARGIN.
## Rules are about components (Device, Lock, Door, Sign), never about names (AGENTS.md "Systemic design").

## How far in front of each wall face a doorway's opening counts (m): a device closer than this to
## the wall, over the opening, hangs in front of the door.
const OPENING_DEPTH := 0.6
## Clearance kept around a sign's text (m).
const SIGN_MARGIN := 0.03


## Overlaps between the wall devices and boxes under `root` and its doorways, door sweeps and signs.
static func problems(root: Node) -> PackedStringArray:
	var doors: Array[Door] = []
	var signs: Array[Sign] = []
	# Each item: {"name": String, "box": AABB (world), "door": the Door it belongs to, or null}.
	var items: Array[Dictionary] = []
	# Entities already boxed (one entity may have several devices or locks).
	var boxed: Dictionary[Node, bool] = {}
	for node in root.find_children("*", "", true, false):
		if node is Door:
			doors.append(node as Door)
		elif node is Sign:
			signs.append(node as Sign)
		elif node is Device or node is Lock:
			var entity: Node3D = null
			if node is Device:
				entity = (node as Device).entity
			else:
				entity = (node as Lock).entity as Node3D
			if entity != null and Door.of(entity) == null and not boxed.has(entity):
				boxed[entity] = true
				items.append({"name": _label(root, entity), "box": visual_box(entity), "door": null})
	for door in doors:
		for box: StaticBody3D in door.hardware.controls(true) + door.hardware.controls(false):
			items.append({"name": _label(root, box), "box": _wall_box(box), "door": door})
	var found := PackedStringArray()
	for item in items:
		var box: AABB = item["box"]
		if not box.has_volume():
			found.append("%s: no visible geometry to check" % item["name"])
			continue
		for door in doors:
			if door == item["door"]:
				continue
			var to_door := door.entity.global_transform.affine_inverse()
			var local: AABB = to_door * box
			if local.intersects(opening(door)):
				found.append("%s: in front of doorway %s" % [item["name"], _label(root, door.entity)])
			elif local.intersects(DoorLayout.sweep(door.settings, door.wall_thickness)):
				found.append("%s: in the leaf's sweep of %s" % [item["name"], _label(root, door.entity)])
		for sign in signs:
			if box.intersects(sign_box(sign)):
				found.append('%s: over the sign "%s" (%s)' % [item["name"], sign.text, _label(root, sign)])
	return found


## A doorway's opening in its door's local frame (origin on the floor at the doorway's centre, X
## along the wall, Z out of its faces): the doorway's width, up to the leaf's top, through the wall
## and OPENING_DEPTH out of both faces.
static func opening(door: Door) -> AABB:
	var size := DoorLayout.panel_size(door.settings)
	var half_depth := door.wall_thickness * 0.5 + OPENING_DEPTH
	return AABB(
		Vector3(-door.settings.doorway.x * 0.5, 0.0, -half_depth),
		Vector3(door.settings.doorway.x, size.y, half_depth * 2.0)
	)


## The world box of a sign's text, grown by SIGN_MARGIN.
static func sign_box(sign: Sign) -> AABB:
	return (sign.global_transform * sign.get_aabb()).grow(SIGN_MARGIN)


## The world box of an entity's visible geometry (meshes, labels), hidden parts left out.
static func visual_box(entity: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var parts: Array[Node] = [entity]
	parts.append_array(entity.find_children("*", "GeometryInstance3D", true, false))
	for node in parts:
		var part := node as GeometryInstance3D
		if part == null or not part.is_visible_in_tree():
			continue
		var box := part.global_transform * part.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## A door's wall box (origin on its back face, +Z out) from its collision shape.
static func _wall_box(box: StaticBody3D) -> AABB:
	var size := ((box.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
	return box.global_transform * AABB(Vector3(-size.x * 0.5, -size.y * 0.5, 0.0), size)


static func _label(root: Node, node: Node) -> String:
	return String(root.get_path_to(node))
