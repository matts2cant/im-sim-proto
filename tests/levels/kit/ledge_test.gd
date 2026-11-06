extends GdUnitTestSuite
## Ledge kit part: block geometry, metric bands, clamping, warnings and rebuilds.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/ledge.tscn")


func _ledge() -> Ledge:
	return auto_free(SCENE.instantiate()) as Ledge


func test_collision_is_a_block_behind_the_lip() -> void:
	var part := _ledge()
	part.height = 1.9
	part.width = 2.0
	part.depth = 3.0

	var expected := AABB(Vector3(-1.0, 0.0, -3.0), Vector3(2.0, 1.9, 3.0))
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(part.use_collision).is_true()
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()


func test_surface_metadata_and_material() -> void:
	var part := _ledge()
	part.surface = "wood"

	assert_str(part.get_meta(&"surface")).is_equal("wood")
	assert_object((part.get_node("Block") as CSGBox3D).material).is_same(GrayboxMaterials.for_surface("wood"))


func test_band_labels_follow_the_metrics() -> void:
	var expected: Dictionary[float, String] = {
		0.15: "step up",
		0.3: "step up",
		0.32: "between bands",
		0.35: "jump up",
		0.5: "jump up",
		0.99: "jump up",
		1.0: "mantle",
		1.9: "mantle",
		1.95: "between bands",
		2.0: "deliberate no",
		2.2: "deliberate no",
		2.25: "between bands",
		2.3: "out of reach",
		5.0: "out of reach",
	}
	var part := _ledge()
	for height: float in expected:
		part.height = height

		assert_str(part.band).override_failure_message("height %s" % height).is_equal(expected[height])


func test_heights_between_bands_warn_but_are_built() -> void:
	var part := _ledge()
	for height: float in [0.5, 1.5, 2.1, 2.3]:
		part.height = height
		assert_array(part._get_configuration_warnings()).override_failure_message("height %s" % height).is_empty()

	part.height = 1.95

	assert_int(part._get_configuration_warnings().size()).is_equal(1)
	assert_float(KitGeometry.collision_aabb(part).end.y).is_equal_approx(1.95, 0.001)
	# Between a walk-up step and a jump.
	part.height = 0.32
	assert_int(part._get_configuration_warnings().size()).is_equal(1)


func test_illegal_values_are_clamped_and_warned() -> void:
	var part := _ledge()
	part.height = 0.0
	part.width = -1.0

	var block := part.get_node("Block") as CSGBox3D
	assert_float(block.size.y).is_equal_approx(0.05, 0.0001)
	assert_float(block.size.x).is_equal_approx(0.1, 0.0001)
	assert_int(part._get_configuration_warnings().size()).is_equal(2)


func test_rebuilds_on_property_change() -> void:
	var part := _ledge()
	part.height = 1.0
	assert_float(KitGeometry.collision_aabb(part).end.y).is_equal_approx(1.0, 0.001)

	part.height = 1.5
	part.depth = 1.0

	assert_int(KitGeometry.generated_children(part).size()).is_equal(1)
	assert_float(KitGeometry.collision_aabb(part).end.y).is_equal_approx(1.5, 0.001)
	assert_float(KitGeometry.collision_aabb(part).position.z).is_equal_approx(-1.0, 0.001)
