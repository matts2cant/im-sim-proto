class_name DoorHardware
extends Node3D
## Component of a door (ADR 0098; the `Hardware` node of `objects/door/door.tscn`, at the entity's
## origin): the lock hardware, placed by DoorLayout from the door's settings and wall, never per
## level.
## - The leaf's handle (the entity's `Handle` shape and `HandleMesh`) on its leading edge, proud of
##   both faces; a leaf that slides into the wall carries it past its edge, so it stands out of the
##   jamb when open (E closes the door there). It follows the leaf (follow()).
## - Each leaf lock's fitting (Lock.Mount.LEAF: a keyhole) on both faces of the handle.
## - The door controller (ADR 0130): its wall boxes on both wall faces beside the frame, one per wall
##   lock (Mount.WALL: keypad, card reader), else the first indicator lock's (Mount.INDICATOR: an
##   electronic lock's status box), else a plain control box when the settings ask for one
##   (`wall_control`: a roller door) or the door has a controller (a door on a network). The
##   controller is the entity under this node with a DoorController (`Controller`): a level places
##   one there to network the door; a door with boxes and none gets a default one
##   (`door_controller.tscn`, built here). The boxes are the controller's children, each a
##   StaticBody3D on the door's layer with the approved model (`objects/devices/models/`), a
##   DoorControl (E on it works the door through its lock) and a DevicePanel (the controller's
##   Device from either box); the controller sits at the front face's first box. Every box's light
##   (the model's StatusLed) is the controller's lamp (DeviceLamp): the lock light, which also shows
##   the controller's network state. A door without boxes has no controller: it is mechanical.
## Each lock is placed on its hardware (its noises come from there). A lock added later (in code) has
## its hardware built on the next frame.

## A plain control box (DoorSettings.wall_control, or a controller without a lock's box).
const CONTROL_BOX: PackedScene = preload("res://objects/door/door_control_box.tscn")
## The default controller of a door whose locks put a box on the wall.
const CONTROLLER: PackedScene = preload("res://objects/door/door_controller.tscn")
## Metadata on the hardware built here (wall boxes, leaf fittings).
const BUILT_META: StringName = &"door_hardware"
## Metadata on the default controller built here.
const DEFAULT_META: StringName = &"door_hardware_default"

var door: Door
## The handle's box relative to the leaf's centre (DoorLayout.handle_box()).
var handle_box := AABB()
## The door's controller (DoorController), or null: a mechanical door.
var controller: DoorController

var _handle: CollisionShape3D
var _handle_mesh: Node3D
# The controller's DeviceLamp (the boxes' lock lights), or null.
var _lamp: DeviceLamp
# The wall boxes, front face first then back face.
var _boxes: Array[StaticBody3D] = []
var _pending: bool = false
# True while the default controller is being added (it needs no rebuild).
var _building: bool = false


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
	_fit_handle()
	_build_locks()
	if not door.entity.child_entered_tree.is_connected(_on_child_entered):
		door.entity.child_entered_tree.connect(_on_child_entered)
	if not child_entered_tree.is_connected(_on_own_child_entered):
		child_entered_tree.connect(_on_own_child_entered)


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
## controller's lamp (its network state comes first).
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


# The controller entity under this node (a child with a DoorController), or null; one placed by the
# level (or added in code) wins over the default one built here, which then goes.
func _find_controller() -> DoorController:
	var built: DoorController = null
	var placed: DoorController = null
	for child in get_children():
		var found := DoorController.of(child)
		if found == null or child.is_queued_for_deletion():
			continue
		if child.has_meta(DEFAULT_META):
			built = found
		elif placed == null:
			placed = found
	if placed != null and built != null:
		var old := built.get_parent()
		remove_child(old)
		old.queue_free()
	return placed if placed != null else built


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
	controller = _find_controller()
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
	if scenes.is_empty() and (door.settings.wall_control or controller != null):
		scenes.append(CONTROL_BOX)
		wall.append(null)
	if scenes.is_empty():
		_lamp = null
		return
	if controller == null:
		controller = _build_controller()
	controller.bind(door)
	_lamp = DeviceLamp.of(controller.entity)
	var boxes: Array[StaticBody3D] = []
	var heights: Array[float] = []
	for scene: PackedScene in scenes + scenes:
		boxes.append(scene.instantiate() as StaticBody3D)
		heights.append(_box_size(boxes[-1]).y)
	var ys := DoorLayout.box_heights(heights.slice(0, scenes.size()))
	var places: Array[Transform3D] = []
	for front: bool in [true, false]:
		var side_wall := door.front_side_wall if front else door.back_side_wall
		for y in ys:
			places.append(DoorLayout.box_transform(door.settings, door.wall_thickness, side_wall, front, y))
	controller.entity.transform = places[0]
	var device := Device.of(controller.entity)
	for i in boxes.size():
		_add_box(boxes[i], wall[i % scenes.size()], places[i], i < scenes.size(), device)
	if _lamp != null:
		var lights: Array[MeshInstance3D] = []
		for box in _boxes:
			var light := _light_of(box)
			if light != null:
				lights.append(light)
		_lamp.set_meshes(lights)
	if indicator != null:
		indicator.position = position + places[0].origin


# The default controller (door_controller.tscn) under this node.
func _build_controller() -> DoorController:
	var entity := CONTROLLER.instantiate() as Node3D
	entity.name = String(DoorController.NODE_NAME)
	entity.set_meta(DEFAULT_META, true)
	_building = true
	add_child(entity)
	_building = false
	return DoorController.of(entity)


# Adds wall box `box` for `lock` (null: a plain control box) at `place` (door-local) under the
# controller.
func _add_box(box: StaticBody3D, lock: Lock, place: Transform3D, front: bool, device: Device) -> void:
	box.name = "%s%s" % [box.name, "Front" if front else "Back"]
	box.set_meta(BUILT_META, true)
	box.set_meta(&"front", front)
	box.collision_layer = door.entity.collision_layer
	box.transform = controller.entity.transform.affine_inverse() * place
	var control := DoorControl.new()
	control.name = "DoorControl"
	control.door = door
	control.lock = lock
	box.add_child(control)
	var panel := DevicePanel.new()
	panel.name = "DevicePanel"
	panel.device = device
	box.add_child(panel)
	controller.entity.add_child(box)
	_boxes.append(box)
	if front and lock != null:
		# The lock sits on its front box's face (its noises come from there).
		lock.position = position + place.origin + place.basis.z * _box_size(box).z


# Removes the hardware built earlier (wall boxes, leaf fittings).
func _clear() -> void:
	var built: Array[Node] = []
	var found := _find_controller()
	if found != null and is_instance_valid(found.entity):
		built.append_array(found.entity.get_children())
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


# A box's lock light: its model's StatusLed's LED (built when the model entered the tree), or null.
static func _light_of(box: Node) -> MeshInstance3D:
	for node in box.find_children("*", "", true, false):
		if node is StatusLed:
			return (node as StatusLed).led
	return null


func _on_child_entered(node: Node) -> void:
	# A lock added after the door was ready (built in code): rebuild the hardware next frame.
	if node is Lock:
		_rebuild_later()


func _on_own_child_entered(node: Node) -> void:
	# A controller added after the door was ready (in code), not the default one built here.
	if not _building and DoorController.of(node) != null:
		_rebuild_later()


func _rebuild_later() -> void:
	if not _pending:
		_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	if is_inside_tree() and door != null:
		_build_locks()
