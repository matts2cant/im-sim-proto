extends GdUnitTestSuite

const SURFACES: SurfaceTable = preload("res://actors/player/surface_table.tres")


func test_surface_of_reads_collider_metadata() -> void:
	var floor_node: Node3D = auto_free(Node3D.new())
	floor_node.set_meta(&"surface", &"metal")

	assert_str(SURFACES.surface_of(floor_node)).is_equal("metal")


func test_surface_of_defaults_to_concrete() -> void:
	var floor_node: Node3D = auto_free(Node3D.new())

	assert_str(SURFACES.surface_of(floor_node)).is_equal("concrete")
	assert_str(SURFACES.surface_of(null)).is_equal("concrete")


func test_shipped_multipliers() -> void:
	assert_float(SURFACES.multiplier(&"concrete")).is_equal(1.0)
	assert_float(SURFACES.multiplier(&"carpet")).is_equal(0.5)
	assert_float(SURFACES.multiplier(&"wood")).is_equal(1.2)
	assert_float(SURFACES.multiplier(&"metal")).is_equal(1.6)
	assert_float(SURFACES.multiplier(&"grass")).is_equal(0.7)
	assert_float(SURFACES.multiplier(&"unknown")).is_equal(1.0)


func test_metal_uses_plate_sounds_at_lower_pitch() -> void:
	var metal := SURFACES.sound(&"metal") as AudioStreamRandomizer

	for i in metal.streams_count:
		var path := metal.get_stream(i).resource_path
		assert_str(path).contains("impactPlate_light_00%d" % i)
	assert_float(SURFACES.pitch(&"metal")).is_equal(0.8)
	assert_float(SURFACES.pitch(&"concrete")).is_equal(1.0)
	assert_float(SURFACES.pitch(&"unknown")).is_equal(1.0)


func test_every_surface_has_a_randomised_sound() -> void:
	for surface: StringName in SURFACES.multipliers:
		var sound := SURFACES.sound(surface)
		assert_object(sound).is_instanceof(AudioStreamRandomizer)
		assert_int((sound as AudioStreamRandomizer).streams_count).is_equal(5)
