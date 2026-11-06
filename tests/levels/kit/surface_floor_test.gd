extends GdUnitTestSuite
## SurfaceFloor kit part: slab geometry, surface metadata/material, clamping and rebuilds.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/surface_floor.tscn")


func _floor() -> SurfaceFloor:
	return auto_free(SCENE.instantiate()) as SurfaceFloor


func test_collision_is_the_slab_with_its_top_at_the_origin() -> void:
	var part := _floor()
	part.size = Vector2(3, 5)
	part.thickness = 0.3

	assert_bool(part.use_collision).is_true()
	var expected := AABB(Vector3(-1.5, -0.3, -2.5), Vector3(3, 0.3, 5))
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()


func test_each_surface_sets_metadata_and_material() -> void:
	var part := _floor()
	for surface: String in GrayboxMaterials.SURFACES:
		part.surface = surface

		assert_str(part.get_meta(&"surface")).is_equal(surface)
		assert_int(typeof(part.get_meta(&"surface"))).is_equal(TYPE_STRING_NAME)
		assert_object((part.get_node("Slab") as CSGBox3D).material).is_same(GrayboxMaterials.for_surface(surface))
		assert_array(part._get_configuration_warnings()).is_empty()


func test_collider_hit_by_a_ray_reports_the_surface() -> void:
	var part := _floor()
	part.surface = "carpet"
	add_child(part)
	await KitGeometry.settle(get_tree())

	var hit := KitGeometry.ray(part.get_world_3d(), Vector3(0, 1, 0), Vector3(0, -1, 0))

	assert_object(hit.get("collider")).is_same(part)
	assert_float((hit["position"] as Vector3).y).is_equal_approx(0.0, 0.001)
	assert_str((hit["collider"] as Node).get_meta(&"surface")).is_equal("carpet")


func test_illegal_values_are_clamped_and_warned() -> void:
	var part := _floor()
	part.thickness = 0.0
	part.size = Vector2(0.0, 2.0)

	var slab := part.get_node("Slab") as CSGBox3D
	assert_float(slab.size.y).is_equal_approx(0.02, 0.0001)
	assert_float(slab.size.x).is_equal_approx(0.1, 0.0001)
	assert_int(part._get_configuration_warnings().size()).is_equal(2)


func test_unknown_surface_falls_back_to_concrete_with_a_warning() -> void:
	var part := _floor()
	part.surface = "lava"

	assert_str(part.get_meta(&"surface")).is_equal("concrete")
	assert_object((part.get_node("Slab") as CSGBox3D).material).is_same(GrayboxMaterials.for_surface("concrete"))
	assert_int(part._get_configuration_warnings().size()).is_equal(1)


func test_rebuilds_on_property_change() -> void:
	var part := _floor()
	part.size = Vector2(2, 2)
	var before := part.get_node("Slab")

	part.size = Vector2(6, 1)

	assert_bool(is_instance_valid(before)).is_false()
	assert_int(KitGeometry.generated_children(part).size()).is_equal(1)
	assert_float(KitGeometry.collision_aabb(part).size.x).is_equal_approx(6.0, 0.001)
	assert_float(KitGeometry.collision_aabb(part).size.z).is_equal_approx(1.0, 0.001)
