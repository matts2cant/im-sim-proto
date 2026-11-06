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
## Steps strip (ADR 0058): single steps and their lanes (course-local x), lips at z -9.
const STEP_HEIGHTS: Dictionary[String, float] = {"Step015": 0.15, "Step030": 0.3, "Step045": 0.45}
const STEP_X: Dictionary[String, float] = {"Step015": -16.5, "Step030": -14.0, "Step045": -11.5}
const STEP_LIP_Z := -9.0
const STAIR_X := -9.0
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
		var strip := course.get_node("Surfaces/Strip" + String(surface).capitalize()) as SurfaceFloor
		assert_bool(strip.use_collision).is_true()
		assert_str(strip.get_meta(&"surface")).is_equal(surface)
		var material := (strip.get_node("Slab") as CSGBox3D).material as ShaderMaterial
		assert_object(material).is_same(GrayboxMaterials.for_surface(surface))
		var colour: Color = material.get_shader_parameter(&"color_a")
		assert_array(colours).not_contains([colour])
		colours.append(colour)


func test_ledge_heights() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	for ledge_name: String in LEDGE_HEIGHTS:
		var ledge := course.get_node("Ledges/" + ledge_name) as Ledge
		var block := ledge.get_node("Block") as CSGBox3D
		var top := ledge.position.y + block.position.y + block.size.y * 0.5
		assert_float(top).is_equal_approx(LEDGE_HEIGHTS[ledge_name], 0.001)
		assert_bool(ledge.use_collision).is_true()


func test_steps_strip_heights_and_labels() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	for step_name: String in STEP_HEIGHTS:
		var step := course.get_node("Steps/" + step_name) as Ledge
		assert_float(step.height).is_equal_approx(STEP_HEIGHTS[step_name], 0.0001)
		assert_float(step.depth).is_greater_equal(0.8)
		assert_float(step.position.z).is_equal_approx(STEP_LIP_Z, 0.0001)
		assert_float(step.position.x).is_equal_approx(STEP_X[step_name], 0.0001)
	assert_str((course.get_node("Steps/Step030") as Ledge).band).is_equal("step up")
	assert_str((course.get_node("Steps/Step045") as Ledge).band).is_equal("jump up")
	assert_str((course.get_node("Labels/Step045") as Label3D).text).is_equal("0.45 m: jump")
	# Six 0.17 m tiers, treads 0.3 m, at least 1.2 m wide; the top tier is the 1.2 m landing.
	var tiers := course.get_node("Steps/Stair").get_children()
	assert_int(tiers.size()).is_equal(6)
	for i in tiers.size():
		var tier := tiers[i] as Ledge
		assert_float(tier.height).is_equal_approx(0.17, 0.0001)
		assert_float(tier.position.y).is_equal_approx(0.17 * i, 0.0001)
		assert_float(tier.position.z).is_equal_approx(-0.3 * i, 0.0001)
		assert_float(tier.width).is_greater_equal(1.2)
		assert_str(tier.band).is_equal("step up")
	assert_float((tiers[5] as Ledge).depth).is_greater_equal(0.8)


func test_vent_is_metal_and_segments_connect() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())

	var segments := course.get_node("Vent").get_children()
	assert_int(segments.size()).is_equal(4)
	for i in segments.size():
		var segment := segments[i] as VentSegment
		assert_str(segment.get_meta(&"surface")).is_equal("metal")
		assert_bool(segment.use_collision).is_true()
		if i > 0:
			var previous := segments[i - 1] as VentSegment
			var snapped := previous.transform * previous.exit_transform()
			assert_bool(snapped.is_equal_approx(segment.transform)).override_failure_message(segment.name).is_true()


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

		var steps := EventLog.find(&"actor.footstep")
		assert_int(steps.size()).is_greater(0)
		assert_str(steps[-1].data["surface"]).is_equal(SURFACES[i])


func test_gap_widths_and_labels() -> void:
	var course: Node3D = auto_free(COURSE_SCENE.instantiate())
	var runway := _platform_z(course, "GapTrack/Gap2/NearPlatform")
	var platform2 := _platform_z(course, "GapTrack/Gap2/FarPlatform")
	var platform2_again := _platform_z(course, "GapTrack/Gap33/NearPlatform")
	var platform3 := _platform_z(course, "GapTrack/Gap33/FarPlatform")

	assert_vector(platform2_again).is_equal(Vector2.ZERO)  # Gap33 reuses Gap2's far platform.
	assert_float(runway.x - platform2.y).is_equal_approx(2.0, 0.001)
	assert_float(platform2.x - platform3.y).is_equal_approx(3.3, 0.001)
	assert_float(runway.y - runway.x).is_equal_approx(4.0, 0.001)
	assert_float(platform3.y - platform3.x).is_equal_approx(4.0, 0.001)
	var gap2 := course.get_node("GapTrack/Gap2") as Gap
	var gap33 := course.get_node("GapTrack/Gap33") as Gap
	assert_str((course.get_node("Labels/Gap2") as Label3D).text).is_equal("2 m: walk-jump")
	assert_str((course.get_node("Labels/Gap33") as Label3D).text).is_equal("3.3 m: sprint-jump")
	assert_str(gap2.difficulty_label).is_equal("2 m: walk-jump")
	assert_str(gap33.difficulty_label).is_equal("3.3 m: sprint-jump")
	assert_str((course.get_node("Labels/Ledge050") as Label3D).text).is_equal("0.5 m: jump up")


func test_ledges_mantle_from_one_metre_and_jump_onto_half_metre() -> void:
	await _load_hub()
	var x_by_ledge: Dictionary[String, float] = {
		"Ledge050": -11.75, "Ledge100": -8.75, "Ledge150": -6.0, "Ledge190": -1.25, "Ledge230": 1.75
	}
	for ledge_name: String in x_by_ledge:
		_place(Vector3(x_by_ledge[ledge_name], 0, -23.4), 0.0)
		await _frames(5)
		EventLog.clear()

		# Below the mantle minimum the jump is a normal one: steer onto the ledge.
		var steer: bool = LEDGE_HEIGHTS[ledge_name] < 1.0
		if steer:
			_runner.simulate_action_press("move_forward")
		await _hold(&"jump", 3)
		await _frames(17)
		_runner.simulate_action_release("move_forward")
		await _frames(60)

		var height: float = LEDGE_HEIGHTS[ledge_name]
		var mantled := not EventLog.find(&"player.mantled").is_empty()
		var expect_mantle := height >= 1.0 and height <= 1.9
		assert_bool(mantled).override_failure_message("%s mantled: %s" % [ledge_name, mantled]).is_equal(expect_mantle)
		# The 0.5 m ledge is jumped onto (not mantled); the 2.3 m ledge cannot be climbed.
		var expected_y := 0.0 if height > 1.9 else height
		assert_float(_local().y).is_equal_approx(expected_y, 0.03)


func test_walks_up_the_low_steps_but_not_the_jump_step() -> void:
	await _load_hub()
	for step_name: String in STEP_HEIGHTS:
		# Feet 1.5 m in front of the lip; 0.6 s of walking ends about 0.7 m onto a 1 m deep top.
		_place(Vector3(STEP_X[step_name], 0, STEP_LIP_Z + 1.5), 0.0)
		await _frames(5)

		await _hold(&"move_forward", 36)

		var height: float = STEP_HEIGHTS[step_name]
		var expected_y := height if height < 0.35 else 0.0
		var label := "%s: local %s" % [step_name, _local()]
		assert_float(_local().y).override_failure_message(label).is_equal_approx(expected_y, 0.03)


func test_walks_over_the_stair_without_landing() -> void:
	await _load_hub()
	_place(Vector3(STAIR_X, 0, STEP_LIP_Z + 3.0), 0.0)
	await _frames(5)
	EventLog.clear()
	var highest := 0.0
	var airborne := 0
	var longest := 0

	# Up the six risers, over the landing and down the far side.
	_runner.simulate_action_press("move_forward")
	for i in 150:
		await get_tree().physics_frame
		highest = maxf(highest, _local().y)
		airborne = 0 if _player.is_on_floor() else airborne + 1
		longest = maxi(longest, airborne)
		if _local().z < STEP_LIP_Z - 5.5:
			break
	_runner.simulate_action_release("move_forward")

	assert_float(highest).is_equal_approx(1.02, 0.03)
	assert_float(_local().y).is_less(0.03)
	assert_int(longest).is_less_equal(2)
	assert_array(EventLog.find(&"actor.landed")).is_empty()


func test_crawls_through_vent_from_floor_exit_to_ledge_mouth() -> void:
	await _load_hub()
	_place(Vector3(-12.5, 0, -29), -PI / 2)
	await _frames(5)
	EventLog.clear()
	_runner.simulate_action_press("crouch")

	await _hold(&"move_forward", 300)
	assert_float(_local().x).is_greater(-4.3)
	assert_float(_local().y).is_equal_approx(1.5, 0.05)
	var steps := EventLog.find(&"actor.footstep")
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


func test_three_point_three_metre_gap_needs_sprint_jump() -> void:
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


# Course-space z extent (min, max) of a generated platform box with its top at 2 m; ZERO if absent.
func _platform_z(course: Node3D, path: String) -> Vector2:
	var box := course.get_node_or_null(path) as CSGBox3D
	if box == null:
		return Vector2.ZERO
	var part := box.get_parent() as Node3D
	var center := part.transform * box.position
	assert_float(center.y + box.size.y * 0.5).is_equal_approx(2.0, 0.001)
	return Vector2(center.z - box.size.z * 0.5, center.z + box.size.z * 0.5)


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
