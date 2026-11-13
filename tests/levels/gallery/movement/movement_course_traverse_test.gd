extends GdUnitTestSuite
## Movement course walkthroughs, traversal: the real player on the course (loaded alone with a
## player, see course_driver.gd) crawls through the vent and jumps the gap track (2 m with a walk
## jump, 3.3 m only with a sprint jump).

const CourseDriver := preload("res://tests/levels/gallery/movement/course_driver.gd")

var _driver: CourseDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	_driver = CourseDriver.new(scene_runner(CourseDriver.FIXTURE))
	await _driver.settle()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_crawls_through_vent_from_floor_exit_to_ledge_mouth() -> void:
	await _driver.place_local(Vector3(-12.5, 0, -29), -PI / 2)
	_driver.runner.simulate_action_press("crouch")

	await _driver.hold(&"move_forward", 300)
	assert_float(_driver.local().x).is_greater(-4.3)
	assert_float(_driver.local().y).is_equal_approx(1.5, 0.05)
	var steps := _driver.player_steps()
	assert_str(steps[-1].data["surface"]).is_equal("metal")

	_driver.player.rotation.y = PI
	await _driver.hold(&"move_forward", 200)
	_driver.runner.simulate_action_release("crouch")
	await _driver.frames(30)

	assert_float(_driver.local().z).is_greater(-23.5)
	assert_float(_driver.local().y).is_less(0.05)
	assert_bool(_driver.player.crouched).is_false()


func test_two_metre_gap_clears_with_walk_jump() -> void:
	await _assert_gap_jump(-35.0, -38.5, false, true)


func test_three_point_three_metre_gap_needs_sprint_jump() -> void:
	await _assert_gap_jump(-41.0, -44.5, false, false)
	await _assert_gap_jump(-41.0, -44.5, true, true)


# Runs along the gap walkway (top at 2 m) from local z `start_z`, jumps just before `edge_z`.
func _assert_gap_jump(start_z: float, edge_z: float, sprint: bool, expect_across: bool) -> void:
	await _driver.place_local(Vector3(-15, 2, start_z))
	if sprint:
		_driver.runner.simulate_action_press("sprint")
	_driver.runner.simulate_action_press("move_forward")
	for i in 120:
		await get_tree().physics_frame
		if _driver.local().z <= edge_z + 0.15:
			break
	await _driver.hold(&"jump", 2)
	# Momentum carries the jump; without input the player stops on landing.
	_driver.runner.simulate_action_release("move_forward")
	_driver.runner.simulate_action_release("sprint")
	await _driver.frames(90)

	var landed_on_top := _driver.local().y > 1.9
	(
		assert_bool(landed_on_top)
		. override_failure_message(
			"sprint=%s gap at %.1f: across=%s, local=%s" % [sprint, edge_z, landed_on_top, _driver.local()]
		)
		. is_equal(expect_across)
	)
