extends GdUnitTestSuite
## Integration: footstep and landing events (EventLog) from the real player on CSG floors.

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


func test_footsteps_report_csg_floor_surface() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	await _driver.hold(&"move_forward", 120)

	var steps := EventLog.find(&"player.footstep")
	assert_int(steps.size()).is_equal(floori(_distance(CONFIG.walk_speed, 120) / CONFIG.walk_stride))
	for step: EventLogEntry in steps:
		assert_str(step.source).is_equal("Player")
		assert_str(step.data["mode"]).is_equal("walk")
		assert_str(step.data["surface"]).is_equal("wood")
		assert_float(step.data["loudness"]).is_equal_approx(CONFIG.walk_loudness * 1.2, 0.001)
	assert_float(_player.noise.last_footstep_loudness).is_equal_approx(CONFIG.walk_loudness * 1.2, 0.001)


func test_footsteps_default_to_concrete_without_metadata() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(-10, 0, 5))

	await _driver.hold(&"move_forward", 90)

	var steps := EventLog.find(&"player.footstep")
	assert_int(steps.size()).is_greater(0)
	assert_str(steps[0].data["surface"]).is_equal("concrete")
	assert_float(steps[0].data["loudness"]).is_equal_approx(CONFIG.walk_loudness, 0.001)


func test_crouched_footsteps_are_quieter_and_more_frequent() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	_driver.runner.simulate_action_press("crouch")
	await _driver.hold(&"move_forward", 120)
	_driver.runner.simulate_action_release("crouch")

	var steps := EventLog.find(&"player.footstep")
	assert_int(steps.size()).is_equal(floori(_distance(CONFIG.crouch_speed, 120) / CONFIG.crouch_stride))
	assert_str(steps[0].data["mode"]).is_equal("crouch")
	assert_float(steps[0].data["loudness"]).is_equal_approx(CONFIG.crouch_loudness * 1.2, 0.001)


func test_landing_after_two_metre_drop_is_logged() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(30, 2, 1))

	await _driver.hold(&"move_forward", 40)
	await _driver.frames(60)

	var landings := EventLog.find(&"player.landed")
	assert_int(landings.size()).is_equal(1)
	var impact: float = landings[0].data["impact_speed"]
	assert_float(impact).is_equal_approx(sqrt(2.0 * 9.8 * 2.0), 0.4)
	assert_str(landings[0].data["surface"]).is_equal("concrete")
	var expected := CONFIG.walk_loudness * clampf(impact / CONFIG.landing_reference_speed, 1.0, 4.0)
	assert_float(landings[0].data["loudness"]).is_equal_approx(expected, 0.001)


func test_csg_floor_collider_is_the_csg_node_with_metadata() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)
	var floor_node := _driver.runner.find_child("WoodFloor")

	var collision := _player.move_and_collide(Vector3.DOWN * 0.5, true)
	var ray: RayCast3D = _player.get_node("FloorRay")
	ray.force_raycast_update()

	assert_object(collision).is_not_null()
	assert_object(collision.get_collider()).is_same(floor_node)
	assert_object(ray.get_collider()).is_same(floor_node)
	assert_str(CONFIG.surfaces.surface_of(collision.get_collider())).is_equal("wood")


func _distance(speed: float, frames: int) -> float:
	return PlayerDriver.ramped_distance(speed, CONFIG.ground_acceleration, frames)


func _load(path: String) -> void:
	_driver = PlayerDriver.new(scene_runner(path))
	_player = _driver.player
	await _driver.settle()
