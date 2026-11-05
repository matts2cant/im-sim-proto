extends GdUnitTestSuite

var _config: PlayerConfig


func before_test() -> void:
	_config = PlayerConfig.new()
	_config.walk_speed = 4.0
	_config.sprint_speed = 6.0
	_config.crouch_speed = 2.0
	_config.sprint_max_angle_deg = 50.0
	_config.ground_acceleration = 40.0
	_config.ground_deceleration = 50.0
	_config.air_control = 0.3
	_config.standing_eye_height = 1.65
	_config.crouched_eye_height = 0.9
	_config.eye_transition_time = 0.15


func test_select_mode_airborne_wins() -> void:
	assert_int(PlayerMotion.select_mode(false, true, true, Vector2.UP, _config)).is_equal(PlayerMotion.Mode.AIR)


func test_select_mode_crouch_over_sprint() -> void:
	assert_int(PlayerMotion.select_mode(true, true, true, Vector2.UP, _config)).is_equal(PlayerMotion.Mode.CROUCH)
	assert_int(PlayerMotion.select_mode(true, true, false, Vector2.ZERO, _config)).is_equal(PlayerMotion.Mode.CROUCH)


func test_select_mode_idle_walk_sprint() -> void:
	assert_int(PlayerMotion.select_mode(true, false, true, Vector2.ZERO, _config)).is_equal(PlayerMotion.Mode.IDLE)
	assert_int(PlayerMotion.select_mode(true, false, false, Vector2.UP, _config)).is_equal(PlayerMotion.Mode.WALK)
	assert_int(PlayerMotion.select_mode(true, false, true, Vector2.UP, _config)).is_equal(PlayerMotion.Mode.SPRINT)


func test_sprint_only_forwardish() -> void:
	var diagonal := Vector2(1, -1).normalized()
	assert_int(PlayerMotion.select_mode(true, false, true, diagonal, _config)).is_equal(PlayerMotion.Mode.SPRINT)
	assert_int(PlayerMotion.select_mode(true, false, true, Vector2.RIGHT, _config)).is_equal(PlayerMotion.Mode.WALK)
	assert_int(PlayerMotion.select_mode(true, false, true, Vector2.DOWN, _config)).is_equal(PlayerMotion.Mode.WALK)


func test_max_speed_per_mode() -> void:
	assert_float(PlayerMotion.max_speed(PlayerMotion.Mode.WALK, _config)).is_equal(4.0)
	assert_float(PlayerMotion.max_speed(PlayerMotion.Mode.SPRINT, _config)).is_equal(6.0)
	assert_float(PlayerMotion.max_speed(PlayerMotion.Mode.CROUCH, _config)).is_equal(2.0)
	assert_float(PlayerMotion.max_speed(PlayerMotion.Mode.IDLE, _config)).is_equal(4.0)


func test_ground_acceleration_and_cap() -> void:
	var v := PlayerMotion.horizontal_velocity(Vector3.ZERO, Vector3.FORWARD, 4.0, true, 0.05, _config)
	assert_vector(v).is_equal_approx(Vector3(0, 0, -2), Vector3.ONE * 0.0001)

	v = PlayerMotion.horizontal_velocity(v, Vector3.FORWARD, 4.0, true, 1.0, _config)
	assert_vector(v).is_equal_approx(Vector3(0, 0, -4), Vector3.ONE * 0.0001)


func test_ground_deceleration_without_input() -> void:
	var v := PlayerMotion.horizontal_velocity(Vector3(0, -3, -4), Vector3.ZERO, 4.0, true, 0.02, _config)
	assert_vector(v).is_equal_approx(Vector3(0, 0, -3), Vector3.ONE * 0.0001)


func test_air_keeps_momentum_and_has_reduced_control() -> void:
	var kept := PlayerMotion.horizontal_velocity(Vector3(0, 0, -6), Vector3.ZERO, 6.0, false, 0.1, _config)
	assert_vector(kept).is_equal(Vector3(0, 0, -6))

	var steered := PlayerMotion.horizontal_velocity(Vector3.ZERO, Vector3.RIGHT, 4.0, false, 0.1, _config)
	assert_vector(steered).is_equal_approx(Vector3(40.0 * 0.3 * 0.1, 0, 0), Vector3.ONE * 0.0001)


func test_jump_speed_reaches_apex() -> void:
	var speed := PlayerMotion.jump_speed(1.0, 9.8)
	assert_float(speed).is_equal_approx(4.427, 0.001)
	assert_float(speed * speed / (2.0 * 9.8)).is_equal_approx(1.0, 0.0001)


func test_eye_transition_takes_configured_time() -> void:
	var eye := 1.65
	for i in 9:
		eye = PlayerMotion.step_eye(eye, 0.9, 1.0 / 60.0, _config)
	assert_float(eye).is_equal_approx(0.9, 0.0001)
	assert_float(PlayerMotion.step_eye(1.65, 0.9, 1.0 / 60.0, _config)).is_greater(0.9)


func test_mode_names() -> void:
	assert_str(PlayerMotion.mode_name(PlayerMotion.Mode.SPRINT)).is_equal("sprint")
	assert_str(PlayerMotion.mode_name(PlayerMotion.Mode.MANTLE)).is_equal("mantle")
