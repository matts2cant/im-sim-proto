extends GdUnitTestSuite
## Integration: footstep and landing events (EventLog) from the real player on CSG floors.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const FLAT_FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
const OBSTACLES := "res://tests/actors/player/fixtures/obstacles.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const NOISE: MovementNoiseConfig = preload("res://actors/player/player_movement_noise.tres")

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

	var steps := EventLog.find(&"actor.footstep")
	assert_int(steps.size()).is_equal(floori(_distance(CONFIG.walk_speed, 120) / NOISE.walk_stride))
	for step: EventLogEntry in steps:
		assert_str(step.source).is_equal("Player")
		assert_str(step.data["mode"]).is_equal("walk")
		assert_str(step.data["surface"]).is_equal("wood")
		assert_float(step.data["loudness"]).is_equal_approx(NOISE.walk_loudness * 1.2, 0.001)
	assert_float(_player.noise.last_footstep_loudness).is_equal_approx(NOISE.walk_loudness * 1.2, 0.001)


func test_footsteps_default_to_concrete_without_metadata() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(-10, 0, 5))

	await _driver.hold(&"move_forward", 90)

	var steps := EventLog.find(&"actor.footstep")
	assert_int(steps.size()).is_greater(0)
	assert_str(steps[0].data["surface"]).is_equal("concrete")
	assert_float(steps[0].data["loudness"]).is_equal_approx(NOISE.walk_loudness, 0.001)


func test_crouched_footsteps_are_quieter_and_more_frequent() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)

	_driver.runner.simulate_action_press("crouch")
	await _driver.hold(&"move_forward", 120)
	_driver.runner.simulate_action_release("crouch")

	var steps := EventLog.find(&"actor.footstep")
	assert_int(steps.size()).is_equal(floori(_distance(CONFIG.crouch_speed, 120) / NOISE.crouch_stride))
	assert_str(steps[0].data["mode"]).is_equal("crouch")
	assert_float(steps[0].data["loudness"]).is_equal_approx(NOISE.crouch_loudness * 1.2, 0.001)


func test_landing_after_two_metre_drop_is_logged() -> void:
	await _load(OBSTACLES)
	await _driver.place(Vector3(30, 2, 1))

	await _driver.hold(&"move_forward", 40)
	await _driver.frames(60)

	var landings := EventLog.find(&"actor.landed")
	assert_int(landings.size()).is_equal(1)
	var impact: float = landings[0].data["impact_speed"]
	assert_float(impact).is_equal_approx(sqrt(2.0 * 9.8 * CONFIG.gravity_scale * 2.0), 0.5)
	assert_str(landings[0].data["surface"]).is_equal("concrete")
	var expected := NOISE.landing_loudness * clampf(impact / NOISE.landing_reference_speed, 1.0, 4.0)
	assert_float(landings[0].data["loudness"]).is_equal_approx(expected, 0.001)


func test_csg_floor_collider_is_the_csg_node_with_metadata() -> void:
	await _load(FLAT_FLOOR)
	await _driver.place(Vector3.ZERO)
	var floor_node := _driver.runner.find_child("WoodFloor")

	var collision := _player.move_and_collide(Vector3.DOWN * 0.5, true)
	var feet := _player.global_position
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.1, feet + Vector3.DOWN * 0.3)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)

	assert_object(collision).is_not_null()
	assert_object(collision.get_collider()).is_same(floor_node)
	assert_object(hit["collider"]).is_same(floor_node)
	assert_str(NOISE.surfaces.surface_of(collision.get_collider())).is_equal("wood")
	assert_str(_player.noise.surface).is_equal("wood")


func test_footstep_emits_noise_stimulus_heard_by_a_receiver() -> void:
	await _load(FLAT_FLOOR)
	StimulusSystem.clear()
	var listener_position := Vector3(2, 1.6, -2)
	var listener := Fixtures.entity(
		_driver.runner.scene(), "Listener", listener_position, [Fixtures.receptron(&"noise")]
	)
	await _driver.place(Vector3.ZERO)

	await _driver.hold(&"move_forward", 60)
	await _driver.frames(2)

	var step := EventLog.find(&"actor.footstep")[0]
	var noise := EventLog.find(&"stimulus.emitted")[0]
	assert_str(noise.source).is_equal("Player")
	assert_str(noise.data["type"]).is_equal("noise")
	assert_float(noise.data["intensity"]).is_equal_approx(step.data["loudness"], 0.0001)
	assert_int(noise.tick).is_equal(step.tick + 1)
	var origin: Vector3 = noise.data["origin"]
	assert_float(origin.y).is_equal_approx(0.0, 0.05)
	var heard := Fixtures.entries(&"stimulus.received", noise.data["id"])
	assert_int(heard.size()).is_equal(1)
	assert_str(heard[0].target).is_equal(listener.name)
	# No navmesh in this fixture: straight-line distance; perceived = loudness - distance.
	var distance := origin.distance_to(listener_position)
	assert_str(heard[0].data["propagation"]).is_equal("straight_fallback")
	assert_float(heard[0].data["distance"]).is_equal_approx(distance, 0.0001)
	assert_float(heard[0].data["perceived"]).is_equal_approx(NOISE.walk_loudness * 1.2 - distance, 0.001)


func _distance(speed: float, frames: int) -> float:
	return PlayerDriver.ramped_distance(speed, CONFIG.ground_acceleration, frames)


func _load(path: String) -> void:
	_driver = PlayerDriver.new(scene_runner(path))
	_player = _driver.player
	await _driver.settle()
