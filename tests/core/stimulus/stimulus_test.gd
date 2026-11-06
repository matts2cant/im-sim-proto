extends GdUnitTestSuite
## Unit: stimulus constructors and linear falloff.


func test_noise_uses_loudness_as_intensity_and_radius_with_path_propagation() -> void:
	var noise := Stimulus.make_noise(6.0, Vector3(1, 0, 2))

	assert_str(noise.type).is_equal("noise")
	assert_float(noise.intensity).is_equal(6.0)
	assert_float(noise.radius).is_equal(6.0)
	assert_int(noise.shape).is_equal(Stimulus.Shape.RADIUS)
	assert_int(noise.propagation).is_equal(Stimulus.Propagation.PATH)
	assert_vector(noise.origin).is_equal(Vector3(1, 0, 2))


func test_noise_perceived_is_metres_of_margin_left() -> void:
	var noise := Stimulus.make_noise(6.0, Vector3.ZERO)

	assert_float(noise.perceived_at(0.0)).is_equal(6.0)
	assert_float(noise.perceived_at(2.5)).is_equal_approx(3.5, 0.0001)
	assert_float(noise.perceived_at(6.0)).is_equal(0.0)
	assert_float(noise.perceived_at(6.01)).is_less(0.0)


func test_radius_falloff_is_linear_to_zero_at_radius() -> void:
	var fire := Stimulus.make_radius(&"fire", 2.0, Vector3.ZERO, 4.0)

	assert_float(fire.perceived_at(0.0)).is_equal(2.0)
	assert_float(fire.perceived_at(1.0)).is_equal_approx(1.5, 0.0001)
	assert_float(fire.perceived_at(3.0)).is_equal_approx(0.5, 0.0001)
	assert_float(fire.perceived_at(4.5)).is_less(0.0)


func test_zero_radius_reaches_nothing() -> void:
	assert_float(StimulusPropagation.falloff(5.0, 0.0, 0.0)).is_less(0.0)


func test_contact_and_ray_perceive_full_intensity() -> void:
	var target: Node = auto_free(Node.new())
	var contact := Stimulus.make_contact(&"damage.blunt", 30.0, target)
	var ray := Stimulus.make_ray(&"damage.ballistic", 20.0, Vector3.ZERO, Vector3.FORWARD, 50.0)

	assert_float(contact.perceived_at(100.0)).is_equal(30.0)
	assert_object(contact.target).is_same(target)
	assert_float(ray.perceived_at(49.0)).is_equal(20.0)
	assert_int(ray.shape).is_equal(Stimulus.Shape.RAY)


func test_source_name_handles_missing_source() -> void:
	var source: Node = auto_free(Node.new())
	source.name = "Barrel"

	assert_str(Stimulus.make_noise(1.0, Vector3.ZERO).source_name()).is_empty()
	assert_str(Stimulus.make_noise(1.0, Vector3.ZERO, source).source_name()).is_equal("Barrel")


func test_shape_and_propagation_names() -> void:
	assert_str(Stimulus.shape_name(Stimulus.Shape.RAY)).is_equal("ray")
	assert_str(Stimulus.propagation_name(Stimulus.Propagation.PATH)).is_equal("path")
