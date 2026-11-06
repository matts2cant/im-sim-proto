extends GdUnitTestSuite
## VentSegment kit part: duct geometry, hollow interior, connection points, clamping, rebuilds.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/vent_segment.tscn")


func _vent() -> VentSegment:
	return auto_free(SCENE.instantiate()) as VentSegment


func test_straight_housing_dimensions_and_metal_surface() -> void:
	var part := _vent()
	part.length = 3.0

	var expected := AABB(Vector3(-0.8, -0.2, -3.0), Vector3(1.6, 1.5, 3.0))  # 1.1 m inside + 0.2 m walls.
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()
	assert_bool(part.use_collision).is_true()
	assert_float(part.interior_height).is_equal(1.1)
	assert_str(part.get_meta(&"surface")).is_equal("metal")
	assert_object((part.get_node("Housing") as CSGBox3D).material).is_same(GrayboxMaterials.for_surface("metal"))


func test_interior_is_hollow_with_floor_at_the_origin() -> void:
	var part := _vent()
	part.length = 3.0
	add_child(part)
	await KitGeometry.settle(get_tree())
	var world := part.get_world_3d()

	var along := KitGeometry.ray(world, Vector3(0, 0.5, 1.0), Vector3(0, 0.5, -4.0))
	var down := KitGeometry.ray(world, Vector3(0, 0.9, -1.5), Vector3(0, -1.0, -1.5))
	var up := KitGeometry.ray(world, Vector3(0, 0.2, -1.5), Vector3(0, 3.0, -1.5))

	assert_dict(along).is_empty()
	assert_float((down["position"] as Vector3).y).is_equal_approx(0.0, 0.001)
	assert_float((up["position"] as Vector3).y).is_equal_approx(1.1, 0.001)


func test_corner_exits_to_the_side() -> void:
	var part := _vent()
	part.kind = VentSegment.Kind.CORNER_LEFT

	var exit := part.exit_transform()
	assert_vector(exit.origin).is_equal_approx(Vector3(-0.6, 0, -0.6), Vector3.ONE * 0.001)
	assert_vector(exit.basis * Vector3.FORWARD).is_equal_approx(Vector3.LEFT, Vector3.ONE * 0.001)
	# Closed on the far and right sides, open towards the exit (-X).
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, AABB(Vector3(-0.6, -0.2, -1.4), Vector3(1.4, 1.5, 1.4)))).is_true()

	part.kind = VentSegment.Kind.CORNER_RIGHT

	assert_vector(part.exit_transform().origin).is_equal_approx(Vector3(0.6, 0, -0.6), Vector3.ONE * 0.001)
	assert_vector(part.exit_transform().basis * Vector3.FORWARD).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)


func test_corner_interior_is_open_through_entry_and_exit() -> void:
	var part := _vent()
	part.kind = VentSegment.Kind.CORNER_RIGHT
	add_child(part)
	await KitGeometry.settle(get_tree())
	var world := part.get_world_3d()

	assert_dict(KitGeometry.ray(world, Vector3(0, 0.5, 1.0), Vector3(0, 0.5, -0.6))).is_empty()
	assert_dict(KitGeometry.ray(world, Vector3(0, 0.5, -0.6), Vector3(2.0, 0.5, -0.6))).is_empty()
	assert_dict(KitGeometry.ray(world, Vector3(0, 0.5, -0.6), Vector3(-2.0, 0.5, -0.6))).is_not_empty()


func test_sloped_segment_exit_is_lower_by_the_drop() -> void:
	var part := _vent()
	part.length = 4.0
	part.drop = 1.45

	assert_vector(part.exit_transform().origin).is_equal_approx(Vector3(0, -1.45, -4.0), Vector3.ONE * 0.001)
	var bounds := KitGeometry.collision_aabb(part)
	assert_float(bounds.position.z).is_equal_approx(-4.0, 0.001)
	assert_float(bounds.end.z).is_equal_approx(0.0, 0.001)
	assert_array(part._get_configuration_warnings()).is_empty()


func test_illegal_values_are_clamped_and_warned() -> void:
	var part := _vent()
	part.interior_height = 2.0

	assert_float((part.get_node("Interior") as CSGBox3D).size.y).is_equal_approx(1.2, 0.0001)
	assert_int(part._get_configuration_warnings().size()).is_equal(1)

	part.interior_height = 0.5

	assert_float((part.get_node("Interior") as CSGBox3D).size.y).is_equal_approx(1.0, 0.0001)

	part.interior_height = 1.1
	part.length = 1.0
	part.drop = 5.0

	assert_float(part.exit_transform().origin.y).is_equal_approx(-tan(deg_to_rad(40.0)), 0.001)
	assert_int(part._get_configuration_warnings().size()).is_equal(1)


func test_rebuilds_on_property_change() -> void:
	var part := _vent()
	part.length = 2.0
	part.kind = VentSegment.Kind.CORNER_LEFT

	assert_object(part.get_node_or_null("Exit")).is_not_null()

	part.kind = VentSegment.Kind.STRAIGHT
	part.fill_below = 1.5

	assert_object(part.get_node_or_null("Exit")).is_null()
	assert_float(KitGeometry.collision_aabb(part).position.y).is_equal_approx(-1.5, 0.001)
	assert_int(KitGeometry.generated_children(part).size()).is_equal(2)
