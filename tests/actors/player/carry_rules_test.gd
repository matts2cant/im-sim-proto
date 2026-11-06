extends GdUnitTestSuite
## Unit: carry eligibility, throw speed, carry speed factor, hold point and follow velocity.

const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")


func test_carry_eligibility_against_limit() -> void:
	assert_bool(CarryRules.can_carry(10.0, 20.0)).is_true()
	assert_bool(CarryRules.can_carry(20.0, 20.0)).is_true()
	assert_bool(CarryRules.can_carry(25.0, 20.0)).is_false()
	assert_bool(CarryRules.can_carry(60.0, 70.0)).is_true()
	assert_bool(CarryRules.can_carry(0.0, 20.0)).is_false()


func test_throw_speed_is_impulse_over_mass_capped() -> void:
	# 40 N s: small crate 10 kg -> 4 m/s, 20 kg -> 2 m/s, cardboard 2 kg -> 20 capped to 12, bottle 12.
	assert_float(CarryRules.throw_speed(10.0, CONFIG)).is_equal_approx(4.0, 0.0001)
	assert_float(CarryRules.throw_speed(20.0, CONFIG)).is_equal_approx(2.0, 0.0001)
	assert_float(CarryRules.throw_speed(2.0, CONFIG)).is_equal_approx(12.0, 0.0001)
	assert_float(CarryRules.throw_speed(0.5, CONFIG)).is_equal_approx(12.0, 0.0001)


func test_heavy_load_slows_the_player() -> void:
	assert_float(CarryRules.speed_factor(0.0, CONFIG)).is_equal(1.0)
	assert_float(CarryRules.speed_factor(9.9, CONFIG)).is_equal(1.0)
	assert_float(CarryRules.speed_factor(10.0, CONFIG)).is_equal(0.8)


func test_hold_point_is_ahead_along_the_view_and_lower() -> void:
	var eye := Transform3D(Basis.IDENTITY, Vector3(0, 1.65, 0))

	assert_vector(CarryRules.hold_point(eye, CONFIG)).is_equal_approx(Vector3(0, 1.35, -1.2), Vector3.ONE * 0.0001)


func test_follow_velocity_is_proportional_and_capped() -> void:
	var near := CarryRules.follow_velocity(Vector3.ZERO, Vector3(0.1, 0, 0), CONFIG)
	var far := CarryRules.follow_velocity(Vector3.ZERO, Vector3(10, 0, 0), CONFIG)

	assert_vector(near).is_equal_approx(Vector3(2, 0, 0), Vector3.ONE * 0.0001)
	assert_float(far.length()).is_equal_approx(CONFIG.hold_max_speed, 0.0001)
