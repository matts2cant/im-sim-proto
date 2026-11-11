extends GdUnitTestSuite
## Integration (ADR 0098): every DoorSettings preset in the wall it is made for (CSG built here: a
## 0.25 m wall for the pocket door, a pocket door between two short corridors' side walls, 0.3 m posts
## for the fence gate, 0.4 m posts for the vehicle gate, a 0.5 m wall for the roller door). Its wall
## boxes sit flush on a wall surface beside the frame on both faces, inside no wall and clear of the
## leaf's sweep (DoorHardwareChecks); a door with a pin lock has its keyhole on both faces of the
## leaf's handle; the walls have no coplanar faces of different materials.

const Checks := preload("res://tests/objects/door/door_hardware_checks.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const PLAIN: DoorSettings = preload("res://objects/door/door_settings.tres")
const FENCE_GATE: DoorSettings = preload("res://objects/door/fence_gate_settings.tres")
const ROLLER: DoorSettings = preload("res://objects/door/roller_door_settings.tres")
const VEHICLE_GATE: DoorSettings = preload("res://objects/door/vehicle_gate_settings.tres")
## Far from the origin and from other suites' fixtures (no navigation here).
const ORIGIN := Vector3(420, 0, -420)

var _root: Node3D


func before_test() -> void:
	_root = auto_free(Node3D.new())
	_root.position = ORIGIN
	add_child(_root)


func test_a_pocket_door_with_every_lock_type() -> void:
	_wall(Vector3.ZERO, 0.25, Vector2(8, 3), PLAIN.doorway)
	var door := _door(PLAIN, Vector3.ZERO, 0.25, [&"keypad", &"keycard", &"mechanical", &"electronic"])
	await KitGeometry.settle(get_tree(), 4)
	# A keypad and a card reader on each face (the electronic lock's light is on them), stacked.
	assert_int(door.hardware.controls(true).size()).is_equal(2)
	assert_array(Checks.problems(door)).is_empty()
	# The pin lock's keyhole on both faces of the handle.
	var keyholes := door.entity.get_node("HandleMesh").get_children()
	assert_int(keyholes.size()).is_equal(2)
	assert_array(KitGeometry.coplanar_material_overlaps(_root)).is_empty()


func test_the_checks_catch_boxes_off_or_inside_the_wall() -> void:
	# A door told its wall is 0.45 m thick in a 0.25 m wall: its boxes float 0.1 m off each face. One
	# told 0.05 m: its boxes sit inside the wall.
	_wall(Vector3.ZERO, 0.25, Vector2(4, 3), PLAIN.doorway)
	_wall(Vector3(6, 0, 0), 0.25, Vector2(4, 3), PLAIN.doorway)
	var floating := _door(PLAIN, Vector3.ZERO, 0.45, [&"keypad"])
	var buried := _door(PLAIN, Vector3(6, 0, 0), 0.05, [&"keypad"])
	await KitGeometry.settle(get_tree(), 4)
	assert_str(" ".join(Checks.problems(floating))).contains("floating")
	assert_str(" ".join(Checks.problems(buried))).contains("inside a wall")


func test_a_pocket_door_between_two_short_corridors() -> void:
	# A 1.5 m corridor on each face: its side wall 0.75 m from the doorway's centre line on the -X
	# side, 0.2 m thick, 2 m long.
	_wall(Vector3.ZERO, 0.25, Vector2(8, 3), PLAIN.doorway)
	for side: float in [1.0, -1.0]:
		_block(Vector3(-0.85, 1.5, side * (0.125 + 1.0)), Vector3(0.2, 3, 2.0))
	var entity := DOOR.instantiate() as StaticBody3D
	var door := entity.get_node("Door") as Door
	door.settings = PLAIN
	door.front_side_wall = 0.75
	door.back_side_wall = 0.75
	_add_locks(entity, [&"keypad"])
	_root.add_child(entity)
	await KitGeometry.settle(get_tree(), 4)
	assert_int(door.hardware.controls(true).size()).is_equal(1)
	assert_array(Checks.problems(door)).is_empty()


func test_an_electronic_door_gets_a_status_box() -> void:
	_wall(Vector3.ZERO, 0.25, Vector2(8, 3), PLAIN.doorway)
	var door := _door(PLAIN, Vector3.ZERO, 0.25, [&"electronic"])
	await KitGeometry.settle(get_tree(), 4)
	var boxes := door.hardware.controls(false)
	assert_int(boxes.size()).is_equal(1)
	assert_object((Usable.of(boxes[0]) as DoorControl).lock).is_instanceof(ElectronicLock)
	assert_array(Checks.problems(door)).is_empty()


func test_a_fence_gate_on_its_posts() -> void:
	# 0.3 m posts either side of the 1.2 m gate opening (the warehouse's back gate), 3.2 m high.
	for side: float in [1.0, -1.0]:
		_block(Vector3(side * 0.75, 1.6, 0), Vector3(0.3, 3.2, 0.3))
	var door := _door(FENCE_GATE, Vector3.ZERO, 0.3, [&"keypad", &"mechanical"])
	await KitGeometry.settle(get_tree(), 4)
	assert_int(door.hardware.controls(true).size()).is_equal(1)
	assert_array(Checks.problems(door)).is_empty()


func test_a_vehicle_gate_on_its_posts() -> void:
	# 0.4 m posts either side of the 6 m gate opening (the warehouse's front gate), 3.4 m high.
	for side: float in [1.0, -1.0]:
		_block(Vector3(side * 3.2, 1.7, 0), Vector3(0.4, 3.4, 0.4))
	var door := _door(VEHICLE_GATE, Vector3.ZERO, 0.4, [&"electronic"])
	await KitGeometry.settle(get_tree(), 4)
	assert_int(door.hardware.controls(true).size()).is_equal(1)
	assert_array(Checks.problems(door)).is_empty()


func test_a_roller_door_gets_a_plain_control_box() -> void:
	# A 0.5 m wall with 4.1 m of wall above the 4 x 4 m doorway for the rising leaf.
	_wall(Vector3.ZERO, 0.5, Vector2(12, 8.5), ROLLER.doorway)
	var door := _door(ROLLER, Vector3.ZERO, 0.5, [])
	await KitGeometry.settle(get_tree(), 4)
	var boxes := door.hardware.controls(true)
	assert_int(boxes.size()).is_equal(1)
	assert_object((Usable.of(boxes[0]) as DoorControl).lock).is_null()
	assert_array(Checks.problems(door)).is_empty()


# A wall `thickness` thick, `size` (width, height) centred on x = 0 at `at`, with `doorway` cut out.
func _wall(at: Vector3, thickness: float, size: Vector2, doorway: Vector2) -> void:
	var wall := _block(at + Vector3(0, size.y * 0.5, 0), Vector3(size.x, size.y, thickness))
	var hole := CSGBox3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.size = Vector3(doorway.x, doorway.y, thickness + 1.0)
	hole.position = Vector3(0, doorway.y * 0.5 - size.y * 0.5, 0)
	wall.add_child(hole)


func _block(at: Vector3, size: Vector3) -> CSGBox3D:
	var block := CSGBox3D.new()
	block.size = size
	block.position = at
	block.use_collision = true
	_root.add_child(block)
	return block


func _door(settings: DoorSettings, at: Vector3, wall: float, locks: Array[StringName]) -> Door:
	var entity := DOOR.instantiate() as StaticBody3D
	var door := entity.get_node("Door") as Door
	door.settings = settings
	door.wall_thickness = wall
	entity.position = at
	_add_locks(entity, locks)
	_root.add_child(entity)
	return door


# Lock components of `kinds` on `entity`, before it enters the tree (as a level scene has them).
func _add_locks(entity: Node, kinds: Array[StringName]) -> void:
	for kind in kinds:
		var lock: Lock = null
		match kind:
			&"keypad":
				lock = KeypadLock.new()
			&"keycard":
				lock = KeycardLock.new()
			&"mechanical":
				lock = MechanicalLock.new()
			_:
				lock = ElectronicLock.new()
		lock.name = String(kind).capitalize() + "Lock"
		entity.add_child(lock)
