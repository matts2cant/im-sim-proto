extends GdUnitTestSuite
## Integration: the player's StepClimber (ADR 0058) with simulated input on the flat floor fixture,
## geometry added in code (tests/actors/common/step_course.gd). Obstacle faces at z = -2; the
## player starts at rest facing -Z with a 0.3 m gap (surface to surface) to the face: feet at
## z = -2 + 0.35 + 0.3 = -1.35.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Course := preload("res://tests/actors/common/step_course.gd")
const FLAT_FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

const FACE_Z := -2.0
const START_Z := -1.35
const LOW_STEPS: Array[float] = [0.15, 0.2, 0.3]
const LANE: float = 3.0
const HALF_SECOND: int = 30
## Most ticks in a row the player may be off the floor on a stair.
const MAX_AIRBORNE: int = 2

var _driver: PlayerDriver
var _player: Player
var _step_height: float
## The player's shared step tuning: the debug tab edits it in memory, after_test restores it.
var _step_config: StepConfig = preload("res://actors/player/player_step.tres")


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	_step_height = _step_config.step_height


func after_test() -> void:
	_step_config.step_height = _step_height
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_walks_up_low_steps_without_jumping() -> void:
	await _assert_steps_up(false)


func test_sprints_up_low_steps_without_jumping() -> void:
	await _assert_steps_up(true)


func test_higher_block_stops_the_player() -> void:
	await _load()
	Course.block(_level(), 0.45, FACE_Z)
	await _driver.place(Vector3(0, 0, START_Z))

	await _driver.hold(&"move_forward", HALF_SECOND * 2)

	assert_float(_player.global_position.y).is_less(0.02)
	assert_float(_player.global_position.z).is_greater(FACE_Z + 0.3)
	assert_array(EventLog.find(&"player.mantled")).is_empty()


func test_step_height_is_tunable_in_the_debug_tab() -> void:
	await _load()
	Course.block(_level(), 0.45, FACE_Z)
	await _driver.place(Vector3(0, 0, START_Z))
	_player_tab().call(&"set_step_height", 0.5)

	await _driver.hold(&"move_forward", HALF_SECOND)

	assert_float(_step_config.step_height).is_equal_approx(0.5, 0.0001)
	assert_float(_player.global_position.y).is_equal_approx(0.45, 0.02)


func test_crouched_steps_up_under_a_low_ceiling() -> void:
	# Crouched (0.95 m) under 1.1 m of headroom above a 0.3 m step: 0.15 m to spare.
	await _load()
	Course.block(_level(), 0.3, FACE_Z)
	Course.slab(_level(), 0.3 + 1.1, 3.0, FACE_Z, 3.0)
	await _driver.place(Vector3(0, 0, START_Z))
	_driver.runner.simulate_action_press("crouch")

	await _driver.hold(&"move_forward", HALF_SECOND * 2)
	_driver.runner.simulate_action_release("crouch")

	assert_float(_player.global_position.y).is_equal_approx(0.3, 0.02)
	assert_float(_player.global_position.z).is_less(FACE_Z - 0.5)


func test_standing_does_not_step_up_under_a_low_ceiling() -> void:
	# Standing (1.8 m) under 1.4 m of headroom above a 0.3 m step: no room on top.
	await _load()
	Course.block(_level(), 0.3, FACE_Z)
	Course.slab(_level(), 0.3 + 1.4, 3.0, FACE_Z, 3.0)
	await _driver.place(Vector3(0, 0, START_Z))

	await _driver.hold(&"move_forward", HALF_SECOND * 2)

	assert_float(_player.global_position.y).is_less(0.02)
	assert_float(_player.global_position.z).is_greater(FACE_Z + 0.2)
	assert_bool(_player.crouched).is_false()


func test_walks_up_and_down_stairs_on_the_floor_without_landing() -> void:
	await _load()
	var top := Course.stair(_level(), FACE_Z)
	await _driver.place(Vector3(0, 0, START_Z))

	var up := await _walk_until(func() -> bool: return _player.global_position.z < Course.landing_face(FACE_Z) - 0.5)
	assert_float(_player.global_position.y).is_equal_approx(top, 0.02)
	await _driver.place(Vector3(0, top, Course.landing_face(FACE_Z) - 1.0), PI)
	var down := await _walk_until(func() -> bool: return _player.global_position.z > FACE_Z + 0.8)

	assert_float(_player.global_position.y).is_less(0.02)
	assert_int(up).is_less_equal(MAX_AIRBORNE)
	assert_int(down).is_less_equal(MAX_AIRBORNE)
	assert_array(EventLog.find(&"actor.landed")).is_empty()
	assert_array(_falls()).is_empty()
	assert_array(EventLog.find(&"actor.footstep")).is_not_empty()
	assert_array(EventLog.find(&"player.mantled")).is_empty()


func test_sprints_down_stairs_on_the_floor_without_landing() -> void:
	await _load()
	var top := Course.stair(_level(), FACE_Z)
	await _driver.place(Vector3(0, top, Course.landing_face(FACE_Z) - 1.0), PI)
	_driver.runner.simulate_action_press("sprint")

	var down := await _walk_until(func() -> bool: return _player.global_position.z > FACE_Z + 0.8)
	_driver.runner.simulate_action_release("sprint")

	assert_float(_player.global_position.y).is_less(0.02)
	assert_int(down).is_less_equal(MAX_AIRBORNE)
	assert_array(EventLog.find(&"actor.landed")).is_empty()


func test_walking_off_a_high_ledge_still_falls_and_lands() -> void:
	await _load()
	Course.block(_level(), 1.2, FACE_Z)
	await _driver.place(Vector3(0, 1.2, FACE_Z - 1.0), PI)

	var airborne := await _walk_until(func() -> bool: return _player.global_position.z > 1.0)

	assert_int(airborne).is_greater(5)
	assert_float(_player.global_position.y).is_less(0.02)
	# 1.2 m under the player's 2 g lands at about 6.9 m/s.
	assert_array(EventLog.find(&"actor.landed")).has_size(1)
	assert_array(_falls()).has_size(1)


func test_steps_onto_heavy_debris() -> void:
	# Props pass through the player in the solver (ADR 0054): it stands on them like on the floor.
	await _load()
	var prop := RigidBody3D.new()
	prop.collision_layer = PhysicsLayers.OBJECTS
	prop.collision_mask = PhysicsLayers.OBJECT_MASK
	prop.mass = 200.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.2, 1.2)
	shape.shape = box
	prop.add_child(shape)
	prop.position = Vector3(0, 0.1, FACE_Z - 0.6)
	_level().add_child(prop)
	await _driver.place(Vector3(0, 0, START_Z))

	await _driver.hold(&"move_forward", 20)

	assert_float(_player.global_position.y).is_equal_approx(0.2, 0.03)
	assert_float(prop.global_position.y).is_equal_approx(0.1, 0.02)


func test_camera_eases_over_a_step() -> void:
	await _load()
	Course.block(_level(), 0.3, FACE_Z)
	await _driver.place(Vector3(0, 0, START_Z))
	var offsets: Array[float] = []
	_player.step.stepped.connect(func(_rise: float) -> void: offsets.append(_view_offset()))
	_driver.runner.simulate_action_press("move_forward")

	await _driver.frames(HALF_SECOND)
	_driver.runner.simulate_action_release("move_forward")
	await _driver.frames(10)

	assert_array(offsets).is_not_empty()
	# Right after a step the view is still below the eyes, then it catches up.
	assert_float(offsets[0]).is_less(-0.05)
	assert_float(_view_offset()).is_equal_approx(0.0, 0.01)


func _assert_steps_up(sprint: bool) -> void:
	await _load()
	for i in LOW_STEPS.size():
		Course.block(_level(), LOW_STEPS[i], FACE_Z, 4.0, (i - 1) * LANE)
	var mode_speed := CONFIG.sprint_speed if sprint else CONFIG.walk_speed
	var flat_distance := PlayerDriver.ramped_distance(mode_speed, CONFIG.ground_acceleration, HALF_SECOND)
	for i in LOW_STEPS.size():
		await _driver.place(Vector3((i - 1) * LANE, 0, START_Z))
		if sprint:
			_driver.runner.simulate_action_press("sprint")
		await _driver.hold(&"move_forward", HALF_SECOND)
		_driver.runner.simulate_action_release("sprint")

		var top := LOW_STEPS[i]
		var label := "%.2f m step, sprint %s: feet at %s" % [top, sprint, _player.global_position]
		assert_float(_player.global_position.y).override_failure_message(label).is_equal_approx(top, 0.02)
		assert_bool(_player.is_on_floor()).override_failure_message(label).is_true()
		# No noticeable speed loss: at most 0.25 m (about 4 ticks) short of the same walk on the flat.
		var travelled := START_Z - _player.global_position.z
		assert_float(travelled).override_failure_message(label).is_greater(flat_distance - 0.25)
	assert_array(EventLog.find(&"player.mantled")).is_empty()


# Holds move_forward until `arrived` is true (at most 3 s); returns the longest run of ticks the
# player spent off the floor.
func _walk_until(arrived: Callable) -> int:
	var longest := 0
	var run := 0
	_driver.runner.simulate_action_press("move_forward")
	for tick in 180:
		if arrived.call():
			break
		await _driver.frames(1)
		run = 0 if _player.is_on_floor() else run + 1
		longest = maxi(longest, run)
	_driver.runner.simulate_action_release("move_forward")
	# Let a fall finish.
	await _driver.frames(40)
	return longest


func _view_offset() -> float:
	return _player.eye_transform().origin.y - (_player.global_position.y + _player.eye_height())


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FLAT_FLOOR))
	_player = _driver.player
	await _driver.settle()


func _level() -> Node:
	return _driver.runner.scene()


func _player_tab() -> Control:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		var tab := tabs.get_tab_control(i)
		if tabs.get_tab_title(i) == "Player" and tab.get(&"player") == _player:
			return tab
	return null


func _falls() -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.fall"
	)
