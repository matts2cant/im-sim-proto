extends GdUnitTestSuite
## Gap kit part: platform and pit geometry, difficulty from the jump metrics, warnings.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/gap.tscn")


func _gap() -> Gap:
	return auto_free(SCENE.instantiate()) as Gap


func _box(part: Gap, box_name: String) -> AABB:
	var box := part.get_node(box_name) as CSGBox3D
	return AABB(box.position - box.size * 0.5, box.size)


func test_platforms_and_gap_have_the_set_dimensions() -> void:
	var part := _gap()
	part.gap_width = 3.3
	part.length = 4.0
	part.width = 4.0
	part.platform_height = 2.0
	part.pit_depth = 2.0

	var near := _box(part, "NearPlatform")
	var far := _box(part, "FarPlatform")
	assert_bool(KitGeometry.aabb_matches(near, AABB(Vector3(-2, 0, -4), Vector3(4, 2, 4)))).is_true()
	assert_bool(KitGeometry.aabb_matches(far, AABB(Vector3(-2, 0, -11.3), Vector3(4, 2, 4)))).is_true()
	assert_float(near.position.z - far.end.z).is_equal_approx(3.3, 0.001)
	assert_object(part.get_node_or_null("PitFloor")).is_null()  # The ground is the pit floor.
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, AABB(Vector3(-2, 0, -11.3), Vector3(4, 2, 11.3)))).is_true()
	assert_bool(part.use_collision).is_true()
	assert_str(part.get_meta(&"surface")).is_equal("concrete")


func test_difficulty_comes_from_the_jump_metrics() -> void:
	var expected: Dictionary[float, String] = {
		1.5: "1.5 m: walk-jump",
		2.0: "2 m: walk-jump",
		2.5: "2.5 m: between walk and sprint",
		3.0: "3 m: sprint-jump",
		3.3: "3.3 m: sprint-jump",
		3.5: "3.5 m: sprint-jump",
		3.8: "3.8 m: between sprint and impassable",
		4.2: "4.2 m: impassable",
	}
	var part := _gap()
	for width: float in expected:
		part.gap_width = width

		assert_str(part.difficulty_label).is_equal(expected[width])
	part.gap_width = 3.3
	assert_int(part.get_difficulty()).is_equal(Gap.Difficulty.SPRINT_JUMP)


func test_ambiguous_widths_warn() -> void:
	var part := _gap()
	for width: float in [2.0, 3.3, 4.5]:
		part.gap_width = width
		assert_array(part._get_configuration_warnings()).override_failure_message("gap %s" % width).is_empty()
	for width: float in [2.6, 3.8]:
		part.gap_width = width
		assert_int(part._get_configuration_warnings().size()).override_failure_message("gap %s" % width).is_equal(1)


func test_shallow_pit_gets_a_raised_floor_and_sunken_pit_a_slab_below() -> void:
	var part := _gap()
	part.platform_height = 2.0
	part.pit_depth = 1.5

	var raised := _box(part, "PitFloor")
	assert_float(raised.end.y).is_equal_approx(0.5, 0.001)
	assert_float(raised.position.y).is_equal_approx(0.0, 0.001)

	part.platform_height = 0.0
	part.pit_depth = 3.0

	var sunken := _box(part, "PitFloor")
	assert_float(sunken.end.y).is_equal_approx(-3.0, 0.001)
	assert_float(_box(part, "NearPlatform").position.y).is_equal_approx(-3.0, 0.001)
	assert_float(_box(part, "NearPlatform").end.y).is_equal_approx(0.0, 0.001)


func test_chained_gap_without_near_platform() -> void:
	var part := _gap()
	part.near_platform = false

	assert_object(part.get_node_or_null("NearPlatform")).is_null()
	assert_object(part.get_node_or_null("FarPlatform")).is_not_null()
	assert_int(KitGeometry.generated_children(part).size()).is_equal(1)


func test_illegal_values_are_clamped_and_warned() -> void:
	var part := _gap()
	part.gap_width = 0.1

	assert_float(_box(part, "NearPlatform").position.z - _box(part, "FarPlatform").end.z).is_equal_approx(0.5, 0.001)
	assert_int(part._get_configuration_warnings().size()).is_equal(1)
