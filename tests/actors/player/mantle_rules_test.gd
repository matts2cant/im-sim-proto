extends GdUnitTestSuite

var _config: PlayerConfig


func before_test() -> void:
	_config = PlayerConfig.new()
	_config.mantle_min_height = 1.0
	_config.mantle_max_height = 1.9
	_config.mantle_reach = 0.8
	_config.mantle_base_duration = 0.25
	_config.mantle_duration_per_metre = 0.15


func test_refuses_when_nothing_found() -> void:
	assert_object(MantleRules.evaluate(MantleRules.Probe.new(), Vector3.ZERO, _config)).is_null()
	assert_object(MantleRules.evaluate(null, Vector3.ZERO, _config)).is_null()


func test_height_limits() -> void:
	assert_object(MantleRules.evaluate(_probe(0.5), Vector3.ZERO, _config)).is_null()
	assert_object(MantleRules.evaluate(_probe(0.98), Vector3.ZERO, _config)).is_null()
	assert_object(MantleRules.evaluate(_probe(1.0), Vector3.ZERO, _config)).is_not_null()
	assert_object(MantleRules.evaluate(_probe(1.5), Vector3.ZERO, _config)).is_not_null()
	assert_object(MantleRules.evaluate(_probe(1.9), Vector3.ZERO, _config)).is_not_null()
	assert_object(MantleRules.evaluate(_probe(1.95), Vector3.ZERO, _config)).is_null()
	assert_object(MantleRules.evaluate(_probe(2.3), Vector3.ZERO, _config)).is_null()


func test_jump_does_not_extend_reach() -> void:
	# Feet 1 m up at the jump apex: the 2.3 m ledge is 1.3 m above the feet but 2.3 m above the ground.
	var probe := _probe(1.3)
	probe.rise = 2.3

	assert_object(MantleRules.evaluate(probe, Vector3.UP, _config)).is_null()


func test_falling_short_cannot_catch_a_same_level_ledge() -> void:
	# Fell into a gap: the far ledge is at take-off height (rise 0), 1 m above the feet.
	var probe := _probe(1.0)
	probe.rise = 0.0

	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_null()


func test_falling_short_can_catch_a_ledge_one_metre_above_take_off() -> void:
	var probe := _probe(1.2)
	probe.rise = 1.0

	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_not_null()


func test_jump_does_not_lower_the_minimum() -> void:
	# At the jump apex a 0.5 m ledge top is only just above the feet, 0.5 m above the ground.
	var probe := _probe(0.1)
	probe.rise = 0.5

	assert_object(MantleRules.evaluate(probe, Vector3.UP, _config)).is_null()


func test_ledge_top_must_be_above_the_feet() -> void:
	var probe := _probe(0.0)
	probe.rise = 1.5

	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_null()
	probe.height = -0.2
	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_null()


func test_reach_limit() -> void:
	var probe := _probe(1.0)
	probe.distance = 0.81

	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_null()


func test_ends_standing_when_standing_clearance() -> void:
	var plan := MantleRules.evaluate(_probe(1.0), Vector3.ZERO, _config)

	assert_bool(plan.end_crouched).is_false()
	assert_float(plan.height).is_equal(1.0)
	assert_vector(plan.end).is_equal(Vector3(0, 1.0, -1.0))


func test_ends_crouched_when_only_crouched_clearance() -> void:
	var probe := _probe(1.5)
	probe.standing_clear = false

	var plan := MantleRules.evaluate(probe, Vector3.ZERO, _config)

	assert_bool(plan.end_crouched).is_true()


func test_refuses_without_clearance() -> void:
	var probe := _probe(1.0)
	probe.standing_clear = false
	probe.crouched_clear = false

	assert_object(MantleRules.evaluate(probe, Vector3.ZERO, _config)).is_null()


func test_duration_grows_with_height() -> void:
	assert_float(MantleRules.duration(0.0, _config)).is_equal(0.25)
	assert_float(MantleRules.duration(1.9, _config)).is_equal_approx(0.535, 0.0001)
	assert_float(MantleRules.evaluate(_probe(1.0), Vector3.ZERO, _config).duration).is_equal_approx(0.4, 0.0001)


func test_path_rises_first_then_moves_over() -> void:
	var plan := MantleRules.evaluate(_probe(1.0), Vector3.ZERO, _config)

	assert_vector(MantleRules.position_at(plan, 0.0)).is_equal(Vector3.ZERO)
	assert_vector(MantleRules.position_at(plan, 1.0)).is_equal_approx(plan.end, Vector3.ONE * 0.0001)
	# Rise is 1 m of 2 m total path; smoothstep reaches half way at t = 0.5.
	assert_vector(MantleRules.position_at(plan, 0.5)).is_equal_approx(Vector3(0, 1.0, 0), Vector3.ONE * 0.0001)
	var early := MantleRules.position_at(plan, 0.3)
	assert_float(early.z).is_equal(0.0)
	assert_float(early.y).is_between(0.0, 1.0)


func _probe(height: float) -> MantleRules.Probe:
	var probe := MantleRules.Probe.new()
	probe.found = true
	probe.height = height
	probe.rise = height
	probe.distance = 0.5
	probe.end_position = Vector3(0, height, -1.0)
	probe.standing_clear = true
	probe.crouched_clear = true
	return probe
