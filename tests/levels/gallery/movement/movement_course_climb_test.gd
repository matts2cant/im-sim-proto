extends GdUnitTestSuite
## Movement course walkthroughs, climbing: the real player on the course (loaded alone with a player,
## see course_driver.gd) jumps and mantles onto the ledges, walks up the low steps and over the stair,
## mantles into the vent mouth, and each surface strip reports its surface.

const CourseDriver := preload("res://tests/levels/gallery/movement/course_driver.gd")
const SURFACES: Array[StringName] = [&"concrete", &"carpet", &"wood", &"metal", &"grass"]
const LEDGE_HEIGHTS: Dictionary[String, float] = {
	"Ledge050": 0.5,
	"Ledge100": 1.0,
	"Ledge150": 1.5,
	"Ledge190": 1.9,
	"Ledge230": 2.3,
}
## Steps strip (ADR 0058): single steps and their lanes (course-local x), lips at z -9.
const STEP_HEIGHTS: Dictionary[String, float] = {"Step015": 0.15, "Step030": 0.3, "Step045": 0.45}
const STEP_X: Dictionary[String, float] = {"Step015": -16.5, "Step030": -14.0, "Step045": -11.5}
const STEP_LIP_Z := -9.0
const STAIR_X := -9.0

var _driver: CourseDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	_driver = CourseDriver.new(scene_runner(CourseDriver.FIXTURE))
	await _driver.settle()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_each_strip_reports_its_surface() -> void:
	for i in SURFACES.size():
		await _driver.place_local(Vector3(-6 + 3 * i, 0.02, -5.5))

		await _driver.hold(&"move_forward", 60)

		var steps := _driver.player_steps()
		assert_int(steps.size()).is_greater(0)
		assert_str(steps[-1].data["surface"]).is_equal(SURFACES[i])


func test_ledges_mantle_from_one_metre_and_jump_onto_half_metre() -> void:
	var x_by_ledge: Dictionary[String, float] = {
		"Ledge050": -11.75, "Ledge100": -8.75, "Ledge150": -6.0, "Ledge190": -1.25, "Ledge230": 1.75
	}
	for ledge_name: String in x_by_ledge:
		await _driver.place_local(Vector3(x_by_ledge[ledge_name], 0, -23.4))

		# Below the mantle minimum the jump is a normal one: steer onto the ledge.
		var steer: bool = LEDGE_HEIGHTS[ledge_name] < 1.0
		if steer:
			_driver.runner.simulate_action_press("move_forward")
		await _driver.hold(&"jump", 3)
		await _driver.frames(17)
		_driver.runner.simulate_action_release("move_forward")
		await _driver.frames(60)

		var height: float = LEDGE_HEIGHTS[ledge_name]
		var mantled := not EventLog.find(&"player.mantled").is_empty()
		var expect_mantle := height >= 1.0 and height <= 1.9
		assert_bool(mantled).override_failure_message("%s mantled: %s" % [ledge_name, mantled]).is_equal(expect_mantle)
		# The 0.5 m ledge is jumped onto (not mantled); the 2.3 m ledge cannot be climbed.
		var expected_y := 0.0 if height > 1.9 else height
		assert_float(_driver.local().y).is_equal_approx(expected_y, 0.03)


func test_walks_up_the_low_steps_but_not_the_jump_step() -> void:
	for step_name: String in STEP_HEIGHTS:
		# Feet 1.5 m in front of the lip; 0.6 s of walking ends about 0.7 m onto a 1 m deep top.
		await _driver.place_local(Vector3(STEP_X[step_name], 0, STEP_LIP_Z + 1.5))

		await _driver.hold(&"move_forward", 36)

		var height: float = STEP_HEIGHTS[step_name]
		var expected_y := height if height < 0.35 else 0.0
		var label := "%s: local %s" % [step_name, _driver.local()]
		assert_float(_driver.local().y).override_failure_message(label).is_equal_approx(expected_y, 0.03)


func test_walks_over_the_stair_without_landing() -> void:
	await _driver.place_local(Vector3(STAIR_X, 0, STEP_LIP_Z + 3.0))
	var highest := 0.0
	var airborne := 0
	var longest := 0

	# Up the six risers, over the landing and down the far side.
	_driver.runner.simulate_action_press("move_forward")
	for i in 150:
		await get_tree().physics_frame
		highest = maxf(highest, _driver.local().y)
		airborne = 0 if _driver.player.is_on_floor() else airborne + 1
		longest = maxi(longest, airborne)
		if _driver.local().z < STEP_LIP_Z - 5.5:
			break
	_driver.runner.simulate_action_release("move_forward")

	assert_float(highest).is_equal_approx(1.02, 0.03)
	assert_float(_driver.local().y).is_less(0.03)
	assert_int(longest).is_less_equal(2)
	assert_array(EventLog.find(&"actor.landed")).is_empty()


func test_mantles_into_vent_mouth_crouched() -> void:
	await _driver.place_local(Vector3(-4, 0, -23.4))

	await _driver.hold(&"jump", 3)
	await _driver.frames(60)

	assert_float(_driver.local().y).is_equal_approx(1.5, 0.03)
	assert_float(_driver.local().z).is_less(-24.0)
	assert_bool(_driver.player.crouched).is_true()
