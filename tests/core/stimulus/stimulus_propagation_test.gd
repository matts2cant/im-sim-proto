extends GdUnitTestSuite
## Unit: propagation math (polyline length, segment vs box and sphere).

const BOX := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))


func test_polyline_length_sums_segments() -> void:
	var points := PackedVector3Array([Vector3.ZERO, Vector3(3, 0, 0), Vector3(3, 0, 4)])

	assert_float(StimulusPropagation.polyline_length(points)).is_equal_approx(7.0, 0.0001)
	assert_float(StimulusPropagation.polyline_length(PackedVector3Array([Vector3.ONE]))).is_equal(0.0)


func test_segment_through_box_intersects() -> void:
	assert_bool(StimulusPropagation.segment_intersects_aabb(Vector3(-5, 0, 0), Vector3(5, 0, 0), BOX)).is_true()


func test_segment_starting_inside_box_intersects() -> void:
	assert_bool(StimulusPropagation.segment_intersects_aabb(Vector3(0, 0, 0), Vector3(5, 5, 5), BOX)).is_true()


func test_segment_stopping_short_of_box_misses() -> void:
	assert_bool(StimulusPropagation.segment_intersects_aabb(Vector3(-5, 0, 0), Vector3(-2, 0, 0), BOX)).is_false()


func test_segment_passing_beside_box_misses() -> void:
	assert_bool(StimulusPropagation.segment_intersects_aabb(Vector3(-5, 2, 0), Vector3(5, 2, 0), BOX)).is_false()
	assert_bool(StimulusPropagation.segment_intersects_aabb(Vector3(-5, 0, 0), Vector3(0, 5, 0), BOX)).is_false()


func test_polyline_intersects_box_if_any_segment_does() -> void:
	var around := PackedVector3Array([Vector3(-5, 0, 0), Vector3(-5, 0, 5), Vector3(5, 0, 5)])
	var through := PackedVector3Array([Vector3(-5, 0, 5), Vector3(-5, 0, 0), Vector3(5, 0, 0)])

	assert_bool(StimulusPropagation.polyline_intersects_aabb(around, BOX)).is_false()
	assert_bool(StimulusPropagation.polyline_intersects_aabb(through, BOX)).is_true()


func test_segment_vs_sphere() -> void:
	(
		assert_bool(
			StimulusPropagation.segment_intersects_sphere(Vector3(-5, 0.9, 0), Vector3(5, 0.9, 0), Vector3.ZERO, 1.0)
		)
		. is_true()
	)
	(
		assert_bool(
			StimulusPropagation.segment_intersects_sphere(Vector3(-5, 1.1, 0), Vector3(5, 1.1, 0), Vector3.ZERO, 1.0)
		)
		. is_false()
	)
