extends GdUnitTestSuite
## Integration: walking, sprinting, crouching and jumping in fixture scenes with simulated input.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const FLAT_FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
const OBSTACLES := "res://tests/actors/player/fixtures/obstacles.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_walk_covers_expected_distance() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	await _driver.hold(&"move_forward", 120)

	assert_float(_player.global_position.z).is_equal_approx(-_distance(CONFIG.walk_speed, 120), 0.15)
	assert_float(_player.global_position.x).is_equal_approx(0.0, 0.01)


func test_sprint_is_faster_than_walk() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	_driver.runner.simulate_action_press("sprint")
	await _driver.hold(&"move_forward", 120)
	_driver.runner.simulate_action_release("sprint")

	assert_float(-_player.global_position.z).is_equal_approx(_distance(CONFIG.sprint_speed, 120), 0.15)
	assert_float(-_player.global_position.z).is_greater(_distance(CONFIG.walk_speed, 120) + 3.0)


func test_sprint_does_not_apply_sideways() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	_driver.runner.simulate_action_press("sprint")
	await _driver.hold(&"move_right", 120)
	_driver.runner.simulate_action_release("sprint")

	assert_float(_player.global_position.x).is_equal_approx(_distance(CONFIG.walk_speed, 120), 0.15)


func test_crouch_shrinks_capsule_and_fits_under_one_metre() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(20, 0, 0))

	_driver.runner.simulate_action_press("crouch")
	await _driver.frames(15)
	assert_bool(_player.crouched).is_true()
	assert_float(_player.capsule_height()).is_equal_approx(CONFIG.crouched_height, 0.0001)
	assert_float(_player.eye_height()).is_equal_approx(CONFIG.crouched_eye_height, 0.001)

	await _driver.hold(&"move_forward", 150)
	_driver.runner.simulate_action_release("crouch")

	assert_float(_player.global_position.z).is_less(-3.5)
	assert_float(_player.global_position.y).is_less(0.05)


func test_standing_player_is_blocked_by_one_metre_ceiling() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(20, 0, 0))

	await _driver.hold(&"move_forward", 90)

	assert_float(_player.global_position.z).is_greater(-2.0)


func test_cannot_uncrouch_under_low_ceiling() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(25, 0, 0))
	_driver.runner.simulate_action_press("crouch")
	await _driver.hold(&"move_forward", 120)
	assert_float(_player.global_position.z).is_less(-3.0)

	_driver.runner.simulate_action_release("crouch")
	await _driver.frames(30)
	assert_bool(_player.crouched).is_true()
	assert_float(_player.capsule_height()).is_equal_approx(CONFIG.crouched_height, 0.0001)

	await _driver.hold(&"move_forward", 150)
	await _driver.frames(15)
	assert_float(_player.global_position.z).is_less(-6.5)
	assert_bool(_player.crouched).is_false()
	assert_float(_player.capsule_height()).is_equal_approx(CONFIG.standing_height, 0.0001)
	assert_float(_player.eye_height()).is_equal_approx(CONFIG.standing_eye_height, 0.001)


func test_jump_apex_matches_config() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)
	var ground := _player.global_position.y

	_driver.runner.simulate_action_press("jump")
	var apex := ground
	for i in 80:
		await get_tree().physics_frame
		apex = maxf(apex, _player.global_position.y)
		if i == 3:
			_driver.runner.simulate_action_release("jump")

	assert_float(apex - ground).is_equal_approx(CONFIG.jump_apex_height, 0.06)
	assert_float(_player.global_position.y).is_equal_approx(ground, 0.01)


func test_jump_launch_speed_uses_scaled_gravity() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	_driver.runner.simulate_action_press("jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_driver.runner.simulate_action_release("jump")

	var expected := PlayerMotion.jump_speed(CONFIG.jump_apex_height, 9.8 * CONFIG.gravity_scale)
	assert_float(expected).is_equal_approx(6.26, 0.01)
	assert_float(_player.velocity.y).is_equal_approx(expected - 9.8 * CONFIG.gravity_scale / 60.0, 0.3)


func test_flat_jump_air_time() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	var airborne := await _jump_flight(false)

	assert_float(airborne.x).is_equal_approx(0.64, 0.04)


func test_walk_jump_distance() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	var flight := await _jump_flight(true, false)

	assert_float(flight.y).is_equal_approx(2.5, 0.2)


func test_sprint_jump_distance() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	var flight := await _jump_flight(true, true)

	assert_float(flight.y).is_equal_approx(3.8, 0.25)


func test_look_clamps_pitch() -> void:
	await _load(FLAT_FLOOR)

	_player.look(Vector2(100, -1e6))

	assert_float(_player.pitch).is_equal_approx(deg_to_rad(CONFIG.max_pitch_deg), 0.0001)
	assert_float(_player.rotation.y).is_equal_approx(-100 * CONFIG.mouse_sensitivity, 0.0001)


func test_ignores_movement_while_debug_panel_open() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	DebugPanel.set_open(true)
	await _driver.hold(&"move_forward", 30)
	DebugPanel.set_open(false)

	assert_float(_player.global_position.z).is_equal_approx(0.0, 0.001)


# Optionally runs up (walk or sprint), jumps and returns Vector2(air time in s, ground distance in m).
func _jump_flight(run: bool, sprint: bool = false) -> Vector2:
	if run:
		if sprint:
			_driver.runner.simulate_action_press("sprint")
		_driver.runner.simulate_action_press("move_forward")
		await _driver.frames(60)
	var takeoff := _player.global_position
	_driver.runner.simulate_action_press("jump")
	await _driver.frames(2)
	_driver.runner.simulate_action_release("jump")
	var frames := 2
	while not _player.is_on_floor() and frames < 200:
		await _driver.frames(1)
		frames += 1
	_driver.runner.simulate_action_release("move_forward")
	_driver.runner.simulate_action_release("sprint")
	var flat := Vector3(_player.global_position.x - takeoff.x, 0.0, _player.global_position.z - takeoff.z)
	return Vector2(frames / 60.0, flat.length())


func _distance(speed: float, frames: int) -> float:
	return PlayerDriver.ramped_distance(speed, CONFIG.ground_acceleration, frames)


func _load(path: String) -> void:
	_driver = PlayerDriver.new(scene_runner(path))
	_player = _driver.player
	await _driver.settle()
