class_name DoorHardware
extends Node3D
## Component of a door (ADR 0098; the `Hardware` node of `objects/door/door.tscn`, at the entity's
## origin): the lock hardware, placed by DoorLayout from the door's settings and wall, never per
## level.
## - The leaf's handle (the entity's `Handle` shape and `HandleMesh`) on its leading edge, proud of
##   both faces; a leaf that slides into the wall carries it past its edge, so it stands out of the
##   jamb when open (E closes the door there). It follows the leaf (follow()).
## - Each leaf lock's fitting (Lock.Mount.LEAF: a keyhole) on both faces of the handle.
## - Wall boxes (its children) on both wall faces beside the frame: one per wall lock (Mount.WALL:
##   keypad, card reader), else the first indicator lock's (Mount.INDICATOR: an electronic lock's
##   status box), else a plain control box when the settings ask for one (`wall_control`: a roller
##   door). Each box is a StaticBody3D on the entity's layer with a DoorControl (E on it works the
##   door through its lock) and the lock light (its `Light` mesh, show_light()). The lock lights are
##   the door's lamp (the entity's DeviceLamp, ADR 0122 amendment 2): a door with them shows its
##   network state there and gets no LED on its leaf.
## Each lock is placed on its hardware (its noises come from there). A lock added later (in code) has
## its hardware built on the next frame.

## A plain control box (DoorSettings.wall_control) when no lock puts a box on the wall.
const CONTROL_BOX: PackedScene = preload("res://objects/door/door_control_box.tscn")
## Metadata on the hardware built here (wall boxes, leaf fittings).
const BUILT_META: StringName = &"door_hardware"

var door: Door
## The handle's box relative to the leaf's centre (DoorLayout.handle_box()).
var handle_box := AABB()

var _handle: CollisionShape3D
var _handle_mesh: Node3D
# The entity's DeviceLamp (the boxes' lock lights), or null.
var _lamp: DeviceLamp
# The wall boxes, front face first then back face.
var _boxes: Array[StaticBody3D] = []
var _pending: bool = false


static func of(node: Node) -> DoorHardware:
	if node == null:
		return null
	for child in node.get_children():
		if child is DoorHardware:
			return child as DoorHardware
	return null


## Builds the handle and the hardware of `p_door`'s locks (its entity's Lock components).
func build(p_door: Door) -> void:
	door = p_door
	_handle = door.entity.get_node_or_null(^"Handle") as CollisionShape3D
	_handle_mesh = door.entity.get_node_or_null(^"HandleMesh") as Node3D
	_lamp = DeviceLamp.of(door.entity)
	_fit_handle()
	_build_locks()
	if not door.entity.child_entered_tree.is_connected(_on_child_entered):
		door.entity.child_entered_tree.connect(_on_child_entered)


## Moves the handle with the leaf (the leaf's centre at `leaf`, door-local); hidden when broken.
func follow(leaf: Vector3, broken: bool) -> void:
	var at := leaf + handle_box.get_center()
	if _handle != null:
		_handle.position = at
		_handle.disabled = broken
	if _handle_mesh != null:
		_handle_mesh.position = at
		_handle_mesh.visible = not broken


## Lights every wall box's lock light in `colour` (dark when `lit` is false: dead), through the
## door's lamp (its network state comes first).
func show_light(colour: Color, lit: bool) -> void:
	if _lamp != null:
		_lamp.show_own(colour, lit)


## The wall boxes on the front (+Z) or back face, top first.
func controls(front: bool) -> Array[StaticBody3D]:
	var result: Array[StaticBody3D] = []
	for box in _boxes:
		if is_instance_valid(box) and bool(box.get_meta(&"front", true)) == front:
			result.append(box)
	return result


## Where to look to use the leaf from its front (+Z) or back side (world): the middle of the part of
## the handle's face that stands in the doorway now (out of the jamb when the leaf is in the wall).
func handle_point(front: bool) -> Vector3:
	var leaf := DoorLayout.closed_centre(door.settings) + door.openness * door.settings.travel
	var box := AABB(leaf + handle_box.position, handle_box.size)
	var half := door.settings.doorway.x * 0.5
	var x0 := clampf(box.position.x, -half, half)
	var x1 := clampf(box.end.x, -half, half)
	var z := box.end.z if front else box.position.z
	return door.entity.global_transform * Vector3((x0 + x1) * 0.5, box.get_center().y, z)


# Sizes the handle for the settings and the wall (the scene's shape and mesh are shared: copied).
func _fit_handle() -> void:
	handle_box = DoorLayout.handle_box(door.settings, door.wall_thickness)
	if _handle != null and _handle.shape is BoxShape3D:
		var shape := _handle.shape.duplicate() as BoxShape3D
		shape.size = handle_box.size
		_handle.shape = shape
	var mesh_instance := _handle_mesh as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh is BoxMesh:
		var mesh := mesh_instance.mesh.duplicate() as BoxMesh
		mesh.size = handle_box.size
		mesh_instance.mesh = mesh


func _build_locks() -> void:
	_clear()
	var wall: Array[Lock] = []
	var indicator: Lock = null
	for each in Lock.locks_of(door.entity):
		if each.hardware() == null:
			continue
		match each.mount():
			Lock.Mount.LEAF:
				_fit_leaf_lock(each)
			Lock.Mount.WALL:
				wall.append(each)
			_:
				if indicator == null:
					indicator = each
	if wall.is_empty() and indicator != null:
		wall.append(indicator)
	var scenes: Array[PackedScene] = []
	for each in wall:
		scenes.append(each.hardware())
	if scenes.is_empty() and door.settings.wall_control:
		scenes.append(CONTROL_BOX)
		wall.append(null)
	for front: bool in [true, false]:
		_build_boxes(scenes, wall, front)
	if _lamp != null:
		var lights: Array[MeshInstance3D] = []
		for box in _boxes:
			var light := box.get_node_or_null(^"Light") as MeshInstance3D
			if light != null:
				lights.append(light)
		_lamp.set_meshes(lights)
	if indicator != null and not _boxes.is_empty():
		indicator.position = _boxes[0].position


# The wall boxes of one face: `scenes[i]` for lock `locks[i]` (null: a plain control box).
func _build_boxes(scenes: Array[PackedScene], locks: Array[Lock], front: bool) -> void:
	var boxes: Array[StaticBody3D] = []
	var heights: Array[float] = []
	for scene in scenes:
		var box := scene.instantiate() as StaticBody3D
		boxes.append(box)
		heights.append(_box_size(box).y)
	var ys := DoorLayout.box_heights(heights)
	var side_wall := door.front_side_wall if front else door.back_side_wall
	for i in boxes.size():
		var box := boxes[i]
		box.name = "%s%s" % [box.name, "Front" if front else "Back"]
		box.set_meta(BUILT_META, true)
		box.set_meta(&"front", front)
		box.collision_layer = door.entity.collision_layer
		box.transform = DoorLayout.box_transform(door.settings, door.wall_thickness, side_wall, front, ys[i])
		var control := DoorControl.new()
		control.name = "DoorControl"
		control.door = door
		control.lock = locks[i]
		box.add_child(control)
		add_child(box)
		_boxes.append(box)
		if front and locks[i] != null:
			# The lock sits on its front box's face (its noises come from there).
			locks[i].position = position + box.position + box.basis.z * _box_size(box).z


# Removes the hardware built earlier (wall boxes, leaf fittings).
func _clear() -> void:
	var built: Array[Node] = get_children()
	if _handle_mesh != null:
		built.append_array(_handle_mesh.get_children())
	for node in built:
		if node.has_meta(BUILT_META):
			node.get_parent().remove_child(node)
			node.queue_free()
	_boxes.clear()


# A leaf lock's fitting on both faces of the handle; the lock sits at the front one.
func _fit_leaf_lock(each: Lock) -> void:
	if _handle_mesh == null:
		return
	for front: bool in [true, false]:
		var fitting := each.hardware().instantiate() as Node3D
		fitting.name = "%s%s" % [each.name, "Front" if front else "Back"]
		fitting.set_meta(BUILT_META, true)
		# The handle mesh sits at the handle box's centre: fittings are placed relative to it.
		var place := DoorLayout.keyhole(door.settings, front)
		place.origin -= handle_box.get_center()
		fitting.transform = place
		_handle_mesh.add_child(fitting)
	each.position = DoorLayout.closed_centre(door.settings) + DoorLayout.keyhole(door.settings, true).origin


# The size of a wall box (its `Shape` box).
static func _box_size(box: Node) -> Vector3:
	var shape := box.get_node_or_null(^"Shape") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		return (shape.shape as BoxShape3D).size
	return Vector3(0.1, 0.1, 0.04)


func _on_child_entered(node: Node) -> void:
	# A lock added after the door was ready (built in code): rebuild the hardware next frame.
	if node is Lock and not _pending:
		_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	if is_inside_tree() and door != null:
		_build_locks()
