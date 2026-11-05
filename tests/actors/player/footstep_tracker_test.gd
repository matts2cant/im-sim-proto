extends GdUnitTestSuite


func test_fires_every_stride() -> void:
	var tracker := FootstepTracker.new()
	var steps := 0
	for i in 100:
		if tracker.advance(0.1, 2.0):
			steps += 1
	assert_int(steps).is_equal(5)


func test_carries_remainder_over() -> void:
	var tracker := FootstepTracker.new()
	assert_bool(tracker.advance(1.5, 2.0)).is_false()
	assert_bool(tracker.advance(0.7, 2.0)).is_true()
	assert_float(tracker.distance).is_equal_approx(0.2, 0.0001)


func test_large_jump_fires_once() -> void:
	var tracker := FootstepTracker.new()
	assert_bool(tracker.advance(9.0, 2.0)).is_true()
	assert_float(tracker.distance).is_less(2.0)


func test_reset_and_invalid_stride() -> void:
	var tracker := FootstepTracker.new()
	tracker.advance(1.9, 2.0)
	tracker.reset()
	assert_bool(tracker.advance(0.5, 2.0)).is_false()
	assert_bool(tracker.advance(10.0, 0.0)).is_false()
	assert_bool(tracker.advance(-5.0, 2.0)).is_false()
	assert_float(tracker.distance).is_equal_approx(0.5, 0.0001)
