extends GdUnitTestSuite
## Ramp kit part: wedge geometry, 40 degree limit, surface and rebuilds.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/ramp.tscn")


func _ramp() -> Ramp:
	return auto_free(SCENE.instantiate()) as Ramp


func test_collision_is_a_wedge_rising_towards_minus_z() -> void:
	var part := _ramp()
	part.rise = 2.0
	part.run = 3.464102
	part.width = 4.0

	var expected := AABB(Vector3(-2.0, 0.0, -3.464102), Vector3(4.0, 2.0, 3.464102))
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(part.use_collision).is_true()
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()
	assert_float(part.angle_deg()).is_equal_approx(30.0, 0.01)
	assert_array(part._get_configuration_warnings()).is_empty()


func test_surface_is_on_top_halfway_up() -> void:
	var part := _ramp()
	part.rise = 1.0
	part.run = 2.0
	part.surface = "metal"
	add_child(part)
	await KitGeometry.settle(get_tree())

	var hit := KitGeometry.ray(part.get_world_3d(), Vector3(0, 3, -1), Vector3(0, -1, -1))

	assert_object(hit.get("collider")).is_same(part)
	assert_float((hit["position"] as Vector3).y).is_equal_approx(0.5, 0.01)
	assert_str(part.get_meta(&"surface")).is_equal("metal")
	assert_object((part.get_node("Wedge") as CSGPolygon3D).material).is_same(GrayboxMaterials.for_surface("metal"))


func test_slope_above_forty_degrees_is_clamped_and_warned() -> void:
	var part := _ramp()
	part.run = 2.0
	part.rise = 3.0

	assert_float(part.angle_deg()).is_equal_approx(40.0, 0.01)
	assert_float(KitGeometry.collision_aabb(part).size.y).is_equal_approx(2.0 * tan(deg_to_rad(40.0)), 0.001)
	assert_int(part._get_configuration_warnings().size()).is_equal(1)

	part.rise = 1.6

	assert_array(part._get_configuration_warnings()).is_empty()


func test_rebuilds_on_property_change() -> void:
	var part := _ramp()
	part.rise = 0.5
	part.width = 1.0

	assert_int(KitGeometry.generated_children(part).size()).is_equal(1)
	assert_float(KitGeometry.collision_aabb(part).size.y).is_equal_approx(0.5, 0.001)
	assert_float(KitGeometry.collision_aabb(part).size.x).is_equal_approx(1.0, 0.001)
