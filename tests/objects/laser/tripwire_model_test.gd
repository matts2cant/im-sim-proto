extends GdUnitTestSuite
## Unit (ADR 0096): TripwireModel, the trip and re-arm of a laser tripwire.

const TICK := 1.0 / 60.0


func test_the_first_break_trips_once_while_it_lasts() -> void:
	var model := TripwireModel.new(1.0)
	assert_bool(model.step(TICK, false)).is_false()
	assert_bool(model.step(TICK, true)).is_true()
	assert_bool(model.tripped).is_true()
	for i in 120:
		assert_bool(model.step(TICK, true)).is_false()
	assert_bool(model.blocked).is_true()


func test_it_rearms_only_after_the_beam_stays_clear() -> void:
	var model := TripwireModel.new(1.0)
	model.step(TICK, true)
	# Clear for 0.5 s, broken again: still the same crossing.
	for i in 30:
		model.step(TICK, false)
	assert_bool(model.step(TICK, true)).is_false()
	# Clear for 1.5 s: re-armed, the next break trips.
	for i in 90:
		model.step(TICK, false)
	assert_bool(model.tripped).is_false()
	assert_bool(model.step(TICK, true)).is_true()


func test_reset_arms_it_at_once() -> void:
	var model := TripwireModel.new(1.0)
	model.step(TICK, true)
	model.reset()
	assert_bool(model.tripped).is_false()
	assert_bool(model.step(TICK, true)).is_true()


func test_round_trip() -> void:
	var model := TripwireModel.new(1.0)
	model.step(TICK, true)
	for i in 30:
		model.step(TICK, false)
	var copy := TripwireModel.new(1.0)
	copy.from_dict(model.to_dict())
	assert_bool(copy.tripped).is_true()
	assert_float(copy.clear_time).is_equal_approx(0.5, 0.001)
	for i in 40:
		copy.step(TICK, false)
	assert_bool(copy.tripped).is_false()
