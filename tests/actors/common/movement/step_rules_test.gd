extends GdUnitTestSuite
## Unit: StepRules, the pure step rules (ADR 0058).

const MAX_FLOOR := deg_to_rad(45.0)

var _config: StepConfig


func before_test() -> void:
	_config = StepConfig.new()
	_config.step_height = 0.35
	_config.step_reach = 0.13
	_config.smooth_time = 0.1


func test_walkable_up_to_the_max_floor_angle() -> void:
	assert_bool(StepRules.is_walkable(Vector3.UP, MAX_FLOOR)).is_true()
	assert_bool(StepRules.is_walkable(_normal_at(40.0), MAX_FLOOR)).is_true()
	assert_bool(StepRules.is_walkable(_normal_at(50.0), MAX_FLOOR)).is_false()


func test_walls_and_edges_are_walls_ceilings_are_not() -> void:
	assert_bool(StepRules.is_wall(Vector3.BACK, MAX_FLOOR)).is_true()
	# A step's edge against the rounded capsule bottom: tilted up, steeper than 45 degrees.
	assert_bool(StepRules.is_wall(_normal_at(60.0), MAX_FLOOR)).is_true()
	assert_bool(StepRules.is_wall(Vector3.UP, MAX_FLOOR)).is_false()
	assert_bool(StepRules.is_wall(Vector3.DOWN, MAX_FLOOR)).is_false()
	assert_bool(StepRules.is_wall(_normal_at(120.0), MAX_FLOOR)).is_false()


func test_steps_up_to_the_step_height() -> void:
	for top: float in [0.15, 0.2, 0.3]:
		assert_bool(StepRules.can_step_up(top, top, 0.35, Vector3.UP, MAX_FLOOR, _config)).is_true()
	# Landing on the step's edge (lower than its top) is a step too: the capsule rides up from there.
	assert_bool(StepRules.can_step_up(0.1, 0.3, 0.35, _normal_at(40.0), MAX_FLOOR, _config)).is_true()


func test_too_high_top_is_not_a_step() -> void:
	assert_bool(StepRules.can_step_up(0.3, 0.45, 0.35, Vector3.UP, MAX_FLOOR, _config)).is_false()


func test_no_rise_is_not_a_step() -> void:
	assert_bool(StepRules.can_step_up(0.002, 0.2, 0.35, Vector3.UP, MAX_FLOOR, _config)).is_false()


func test_steep_landing_is_not_a_step() -> void:
	assert_bool(StepRules.can_step_up(0.2, 0.2, 0.35, _normal_at(55.0), MAX_FLOOR, _config)).is_false()


func test_no_headroom_to_rise_over_the_top_is_not_a_step() -> void:
	# The head hit a ceiling after 0.2 m: a 0.3 m top cannot be cleared.
	assert_bool(StepRules.can_step_up(0.2, 0.3, 0.2, _normal_at(40.0), MAX_FLOOR, _config)).is_false()


func test_step_height_is_tunable() -> void:
	_config.step_height = 0.5
	assert_bool(StepRules.can_step_up(0.45, 0.45, 0.5, Vector3.UP, MAX_FLOOR, _config)).is_true()


func test_reaches_try_the_motion_first_then_step_reach() -> void:
	var short := StepRules.reaches(0.05, _config)
	assert_int(short.size()).is_equal(2)
	assert_float(short[0]).is_equal_approx(0.05, 0.0001)
	assert_float(short[1]).is_equal_approx(0.13, 0.0001)
	var long := StepRules.reaches(0.2, _config)
	assert_int(long.size()).is_equal(1)
	assert_float(long[0]).is_equal_approx(0.2, 0.0001)


func test_may_step_only_from_the_floor_and_not_when_launched() -> void:
	assert_bool(StepRules.may_step(true, 0.0)).is_true()
	assert_bool(StepRules.may_step(true, -3.0)).is_true()
	assert_bool(StepRules.may_step(false, 0.0)).is_false()
	assert_bool(StepRules.may_step(true, 6.0)).is_false()


func test_view_offset_eases_out_over_smooth_time() -> void:
	var offset := -0.3
	var elapsed := 0.0
	while elapsed < 0.1 - 0.001:
		offset = StepRules.ease_offset(offset, 1.0 / 60.0, _config)
		elapsed += 1.0 / 60.0
	# exp(-3) = 5 % left after smooth_time.
	assert_float(offset).is_between(-0.3 * 0.06, -0.3 * 0.04)


func test_view_offset_is_limited_to_the_step_height() -> void:
	var offset := StepRules.ease_offset(-1.0, 0.0, _config)
	assert_float(offset).is_equal_approx(-0.35, 0.0001)


func test_no_easing_without_smooth_time() -> void:
	_config.smooth_time = 0.0
	assert_float(StepRules.ease_offset(-0.3, 1.0 / 60.0, _config)).is_equal(0.0)


# A unit normal tilted `degrees` from straight up toward +Z.
func _normal_at(degrees: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(0.0, cos(angle), sin(angle))
