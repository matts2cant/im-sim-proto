extends GdUnitTestSuite
## Room kit part: shell geometry, materials, openings, clamping, warnings and rebuilds.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/room.tscn")


func _room() -> Room:
	return auto_free(SCENE.instantiate()) as Room


func test_shell_surrounds_the_interior() -> void:
	var part := _room()
	part.size = Vector3(6, 3, 4)
	part.wall_thickness = 0.5

	var expected := AABB(Vector3(-3.5, -0.5, -2.5), Vector3(7, 4, 5))
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()
	assert_bool(part.use_collision).is_true()
	assert_array(part._get_configuration_warnings()).is_empty()


func test_floor_wall_and_ceiling_materials() -> void:
	var part := _room()
	part.floor_surface = "carpet"

	assert_str(part.get_meta(&"surface")).is_equal("carpet")
	assert_object(_material(part, "Floor")).is_same(GrayboxMaterials.for_surface("carpet"))
	assert_object(_material(part, "Ceiling")).is_same(GrayboxMaterials.named("ceiling"))
	for wall: String in ["WallNorth", "WallEast", "WallSouth", "WallWest"]:
		assert_object(_material(part, wall)).is_same(GrayboxMaterials.named("wall"))

	part.wall_material = GrayboxMaterials.named("hazard")

	assert_object(_material(part, "WallNorth")).is_same(GrayboxMaterials.named("hazard"))


func test_interior_is_hollow_with_the_floor_at_the_origin() -> void:
	var part := _room()
	add_child(part)
	await KitGeometry.settle(get_tree())
	var world := part.get_world_3d()

	var down := KitGeometry.ray(world, Vector3(0, 1.5, 0), Vector3(0, -2, 0))
	var up := KitGeometry.ray(world, Vector3(0, 1.5, 0), Vector3(0, 5, 0))
	var north := KitGeometry.ray(world, Vector3(0, 1.5, 0), Vector3(0, 1.5, -5))

	assert_float((down["position"] as Vector3).y).is_equal_approx(0.0, 0.001)
	assert_float((up["position"] as Vector3).y).is_equal_approx(3.0, 0.001)
	assert_float((north["position"] as Vector3).z).is_equal_approx(-2.0, 0.001)


func test_openings_cut_named_holes_in_their_walls() -> void:
	var part := _room()
	var door := RoomOpening.create(RoomOpening.Wall.EAST, 0.5)
	door.node_name = &"Door"
	var window := RoomOpening.create(RoomOpening.Wall.NORTH, -1.0, 1.0, 1.0, 1.2)
	part.openings = [door, window]
	add_child(part)
	await KitGeometry.settle(get_tree())
	var world := part.get_world_3d()

	var cut := part.get_node("Door") as CSGBox3D
	assert_int(cut.operation).is_equal(CSGShape3D.OPERATION_SUBTRACTION)
	assert_object(part.get_node_or_null("Opening1")).is_not_null()
	# Through the door (1.2 x 2.2) at z = 0.5, but not above it or beside it.
	assert_dict(KitGeometry.ray(world, Vector3(0, 1.0, 0.5), Vector3(5, 1.0, 0.5))).is_empty()
	assert_dict(KitGeometry.ray(world, Vector3(0, 2.4, 0.5), Vector3(5, 2.4, 0.5))).is_not_empty()
	assert_dict(KitGeometry.ray(world, Vector3(0, 1.0, -0.3), Vector3(5, 1.0, -0.3))).is_not_empty()
	# Through the window (sill 1.2, 1 m high) but not below the sill.
	assert_dict(KitGeometry.ray(world, Vector3(-1, 1.7, 0), Vector3(-1, 1.7, -5))).is_empty()
	assert_dict(KitGeometry.ray(world, Vector3(-1, 1.0, 0), Vector3(-1, 1.0, -5))).is_not_empty()
	assert_array(part._get_configuration_warnings()).is_empty()


func test_rooms_sharing_a_wall_do_not_z_fight() -> void:
	# A tall room and a low corridor joined the documented way: the corridor's south wall
	# overlaps the room's north wall exactly and their doors line up.
	var hall := SCENE.instantiate() as Room
	hall.name = "Hall"
	hall.size = Vector3(4, 5, 4)
	hall.wall_thickness = 0.5
	hall.openings = [RoomOpening.create(RoomOpening.Wall.NORTH, 0.0, 2.0, 3.0)]
	var corridor := SCENE.instantiate() as Room
	corridor.name = "Corridor"
	corridor.size = Vector3(2, 3, 3)
	corridor.wall_thickness = 0.5
	corridor.position = Vector3(0, 0, -4)
	corridor.openings = [RoomOpening.create(RoomOpening.Wall.SOUTH, 0.0, 2.0, 3.0)]
	var level: Node3D = auto_free(Node3D.new())
	level.add_child(hall)
	level.add_child(corridor)
	add_child(level)
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(level)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


func test_editing_an_opening_rebuilds_the_room() -> void:
	var part := _room()
	var door := RoomOpening.create(RoomOpening.Wall.SOUTH)
	part.openings = [door]

	door.width = 2.0

	assert_float((part.get_node("Opening0") as CSGBox3D).size.x).is_equal_approx(2.0, 0.0001)
	assert_int(KitGeometry.generated_children(part).size()).is_equal(7)


func test_illegal_values_are_clamped_and_warned() -> void:
	var part := _room()
	part.size = Vector3(4, 1.5, 4)
	var too_wide := RoomOpening.create(RoomOpening.Wall.WEST, 0.0, 6.0)
	var narrow_door := RoomOpening.create(RoomOpening.Wall.NORTH, 0.0, 0.6, 1.4)
	part.openings = [too_wide, narrow_door]

	assert_float((part.get_node("Opening0") as CSGBox3D).size.z).is_equal_approx(4.0, 0.0001)
	assert_float((part.get_node("Opening0") as CSGBox3D).size.y).is_equal_approx(1.5, 0.0001)
	var warnings := "\n".join(part._get_configuration_warnings())
	assert_str(warnings).contains("forces crouch")
	assert_str(warnings).contains("width 6.0")
	assert_str(warnings).contains("cannot pass")


func _material(part: Room, child: String) -> Material:
	return (part.get_node(child) as CSGBox3D).material
