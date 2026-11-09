extends GdUnitTestSuite
## Stairs kit part: equal risers no higher than `max_riser`, the flight's bounds, solid versus steel
## (open underneath) flights, the surface, warnings (narrow, steep) and clamping.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const SCENE: PackedScene = preload("res://levels/kit/stairs.tscn")


func _stairs() -> Stairs:
	return auto_free(SCENE.instantiate()) as Stairs


func test_flight_uses_equal_risers_within_the_limit() -> void:
	var part := _stairs()
	part.rise = 4.5
	part.max_riser = 0.18
	part.tread = 0.29

	assert_int(part.steps()).is_equal(25)
	assert_float(part.riser()).is_equal_approx(0.18, 0.0001)
	assert_float(part.run()).is_equal_approx(7.25, 0.0001)
	part.rise = 4.0
	part.max_riser = 0.182
	assert_int(part.steps()).is_equal(22)
	assert_float(part.riser()).is_less_equal(0.182)


func test_collision_spans_the_flight_up_to_the_top_step() -> void:
	var part := _stairs()
	part.rise = 1.8
	part.width = 1.4
	part.tread = 0.3
	part.max_riser = 0.18

	var expected := AABB(Vector3(-0.7, 0.0, -3.0), Vector3(1.4, 1.8, 3.0))
	var bounds := KitGeometry.collision_aabb(part)
	assert_bool(KitGeometry.aabb_matches(bounds, expected)).override_failure_message(str(bounds)).is_true()
	assert_bool(part.use_collision).is_true()


func test_steel_flight_is_open_underneath() -> void:
	var part := _stairs()
	part.rise = 3.6
	part.tread = 0.3
	part.solid = false
	part.thickness = 0.3

	# Step 20 (top 3.6) reaches down to 3.3 only; a solid flight fills down to the floor.
	var top_step := part.get_node("Step20") as CSGBox3D
	assert_float(top_step.position.y - top_step.size.y * 0.5).is_equal_approx(3.3, 0.001)
	part.solid = true
	top_step = part.get_node("Step20") as CSGBox3D
	assert_float(top_step.position.y - top_step.size.y * 0.5).is_equal_approx(0.0, 0.001)


func test_surface_metadata_and_material() -> void:
	var part := _stairs()
	part.surface = "metal"

	assert_str(part.get_meta(&"surface")).is_equal("metal")
	assert_object((part.get_node("Step1") as CSGBox3D).material).is_same(GrayboxMaterials.for_surface("metal"))


func test_narrow_or_steep_flights_warn_and_risers_are_clamped() -> void:
	var part := _stairs()
	part.rise = 2.0
	assert_array(part._get_configuration_warnings()).is_empty()

	part.width = 0.9
	assert_int(part._get_configuration_warnings().size()).is_equal(1)
	part.width = 1.2
	part.tread = 0.18
	part.max_riser = 0.2
	# 0.2 / 0.18: about 48 degrees, and a tread below 0.25 m.
	assert_int(part._get_configuration_warnings().size()).is_equal(2)
	part.tread = 0.3
	part.max_riser = 0.5
	# Clamped to 0.3 m risers (warned); 0.29 m risers on 0.3 m treads are also steeper than 40 degrees.
	assert_float(part.riser()).is_less_equal(Stairs.RISER_LIMIT)
	assert_int(part._get_configuration_warnings().size()).is_equal(2)
