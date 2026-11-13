extends GdUnitTestSuite
## Movement course: static layout checks on the course scene, and the real player walking into it
## from the hub (the course is instanced behind doorway "1 Movement"). The walkthroughs on the course
## itself: movement_course_climb_test.gd, movement_course_traverse_test.gd.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
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


func before_test() -> void:
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
	var driver := PlayerDriver.new(scene_runner(HUB))
	var course := driver.runner.find_child("MovementCourse") as Node3D
	await driver.settle()
	await driver.place(Vector3(-7.5, 0, -12))

	await driver.hold(&"move_forward", 150)

	assert_float(driver.player.global_position.z).is_less(course.global_position.z - 3.0)
	assert_float(driver.player.global_position.y).is_between(-0.05, 0.1)


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


# Course-space z extent (min, max) of a generated platform box with its top at 2 m; ZERO if absent.
func _platform_z(course: Node3D, path: String) -> Vector2:
	var box := course.get_node_or_null(path) as CSGBox3D
	if box == null:
		return Vector2.ZERO
	var part := box.get_parent() as Node3D
	var center := part.transform * box.position
	assert_float(center.y + box.size.y * 0.5).is_equal_approx(2.0, 0.001)
	return Vector2(center.z - box.size.z * 0.5, center.z + box.size.z * 0.5)
