extends GdUnitTestSuite
## Movement course: static layout checks on the course scene, and walkthroughs with the real
## player in the hub (the course is instanced behind doorway "1 Movement").

const COURSE_SCENE: PackedScene = preload("res://levels/gallery/movement/movement_course.tscn")
const HUB := "res://levels/hub/hub.tscn"
const SURFACES: Array[StringName] = [&"concrete", &"carpet", &"wood", &"metal", &"grass"]
const LEDGE_HEIGHTS: Dictionary[String, float] = {
	"Ledge050": 0.5,
	"Ledge100": 1.0,
	"Ledge150": 1.5,
	"Ledge190": 1.9,
	"Ledge230": 2.3,
}
const TIME_FACTOR := 4.0

var _runner: GdUnitSceneRunner
var _player: Player
var _course: Node3D


func before_test() -> void:
	_runner = null
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_surface_strips_have_metadata_collision_and_distinct_colours() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	var colours: Array[Color] = []
	for surface: StringName in SURFACES:
		var strip := course.get_node("Surfaces/Strip" + String(surface).capitalize()) as CSGBox3D
		assert_bool(strip.use_collision).is_true()
		assert_str(strip.get_meta(&"surface")).is_equal(surface)
		var colour := (strip.material as StandardMaterial3D).albedo_color
		assert_array(colours).not_contains([colour])
		colours.append(colour)


func test_ledge_heights() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	for ledge_name: String in LEDGE_HEIGHTS:
		var ledge := course.get_node("Ledges/" + ledge_name) as CSGBox3D
		assert_float(ledge.position.y + ledge.size.y * 0.5).is_equal_approx(LEDGE_HEIGHTS[ledge_name], 0.001)
		assert_bool(ledge.use_collision).is_true()


func test_vent_is_metal() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	assert_str(course.get_node("Vent").get_meta(&"surface")).is_equal("metal")


func test_walks_from_hub_into_course() -> void:
	await _load_hub()
	_player.load_state(_state(Vector3(-7.5, 0, -12), 0.0))
	await _frames(5)

	await _hold(&"move_forward", 150)

	assert_float(_player.global_position.z).is_less(_course.global_position.z - 3.0)
	assert_float(_player.global_position.y).is_between(-0.05, 0.1)


func test_each_strip_reports_its_surface() -> void:
	await _load_hub()
	for i in SURFACES.size():
		_place(Vector3(-6 + 3 * i, 0.02, -5.5), 0.0)
		await _frames(5)
		EventLog.clear()

		await _hold(&"move_forward", 60)

		var steps := EventLog.find(&"player.footstep")
		assert_int(steps.size()).is_greater(0)
		assert_str(steps[-1].data["surface"]).is_equal(SURFACES[i])


func test_ledges_mantle_up_to_one_point_nine() -> void:
	await _load_hub()
	var x_by_ledge: Dictionary[String, float] = {
		"Ledge050": -11.75, "Ledge100": -8.75, "Ledge150": -6.0, "Ledge190": -1.25, "Ledge230": 1.75
	}
	for ledge_name: String in x_by_ledge:
		_place(Vector3(x_by_ledge[ledge_name], 0, -23.4), 0.0)
		await _frames(5)
		EventLog.clear()

		await _hold(&"jump", 3)
		await _frames(60)

		var height: float = LEDGE_HEIGHTS[ledge_name]
		var mantled := not EventLog.find(&"player.mantled").is_empty()
		assert_bool(mantled).override_failure_message("%s mantled: %s" % [ledge_name, mantled]).is_equal(height <= 1.9)
		var expected_y := height if height <= 1.9 else 0.0
		assert_float(_local().y).is_equal_approx(expected_y, 0.03)


func test_crawls_through_vent_from_floor_exit_to_ledge_mouth() -> void:
	await _load_hub()
	_place(Vector3(-12.5, 0, -29), -PI / 2)
	await _frames(5)
	EventLog.clear()
	_runner.simulate_action_press("crouch")

	await _hold(&"move_forward", 300)
	assert_float(_local().x).is_greater(-4.3)
	assert_float(_local().y).is_equal_approx(1.5, 0.05)
	var steps := EventLog.find(&"player.footstep")
	assert_str(steps[-1].data["surface"]).is_equal("metal")

	_player.rotation.y = PI
	await _hold(&"move_forward", 200)
	_runner.simulate_action_release("crouch")
	await _frames(30)

	assert_float(_local().z).is_greater(-23.5)
	assert_float(_local().y).is_less(0.05)
	assert_bool(_player.crouched).is_false()


func test_mantles_into_vent_mouth_crouched() -> void:
	await _load_hub()
	_place(Vector3(-4, 0, -23.4), 0.0)
	await _frames(5)

	await _hold(&"jump", 3)
	await _frames(60)

	assert_float(_local().y).is_equal_approx(1.5, 0.03)
	assert_float(_local().z).is_less(-24.0)
	assert_bool(_player.crouched).is_true()


func test_two_metre_gap_clears_with_walk_jump() -> void:
	await _assert_gap_jump(-35.0, -38.5, false, true)


func test_four_metre_gap_needs_sprint_jump() -> void:
	await _assert_gap_jump(-41.0, -44.5, false, false)
	await _assert_gap_jump(-41.0, -44.5, true, true)


# Runs along the gap walkway (top at 2 m) from local z `start_z`, jumps just before `edge_z`.
func _assert_gap_jump(start_z: float, edge_z: float, sprint: bool, expect_across: bool) -> void:
	if _runner == null:
		await _load_hub()
	_place(Vector3(-15, 2, start_z), 0.0)
	await _frames(5)
	if sprint:
		_runner.simulate_action_press("sprint")
	_runner.simulate_action_press("move_forward")
	for i in 120:
		await get_tree().physics_frame
		if _local().z <= edge_z + 0.15:
			break
	await _hold(&"jump", 2)
	# Momentum carries the jump; without input the player stops on landing.
	_runner.simulate_action_release("move_forward")
	_runner.simulate_action_release("sprint")
	await _frames(90)

	var landed_on_top := _local().y > 1.9
	(
		assert_bool(landed_on_top)
		. override_failure_message(
			"sprint=%s gap at %.1f: across=%s, local=%s" % [sprint, edge_z, landed_on_top, _local()]
		)
		. is_equal(expect_across)
	)


func _load_hub() -> void:
	_runner = scene_runner(HUB)
	_runner.set_time_factor(TIME_FACTOR)
	_player = _runner.find_child("Player") as Player
	_course = _runner.find_child("MovementCourse") as Node3D
	await _frames(5)


# Places the player at a course-local position, at rest, facing `yaw`.
func _place(local_position: Vector3, yaw: float) -> void:
	_player.load_state(_state(_course.to_global(local_position), yaw))


func _local() -> Vector3:
	return _course.to_local(_player.global_position)


func _state(position: Vector3, yaw: float) -> Dictionary:
	return {"position": position, "yaw": yaw, "pitch": 0.0, "crouched": false, "velocity": Vector3.ZERO}


func _hold(action: StringName, frames: int) -> void:
	_runner.simulate_action_press(action)
	await _frames(frames)
	_runner.simulate_action_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
