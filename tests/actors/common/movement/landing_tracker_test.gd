extends GdUnitTestSuite
## Unit: LandingTracker rebuilds the impact speed of a touchdown from the ticks before it.

const DT: float = 1.0 / 60.0


func test_free_fall_impact_is_the_velocity_the_landing_move_started_with() -> void:
	var tracker := LandingTracker.new()
	var g := 19.6
	assert_float(tracker.step(true, 0.0)).is_equal(-1.0)
	# Airborne for 30 ticks: the velocity after tick k is -g * dt * k.
	for k in range(1, 31):
		assert_float(tracker.step(false, -g * DT * k)).is_equal(-1.0)

	var impact := tracker.step(true, 0.0)

	assert_float(impact).is_equal_approx(g * DT * 31, 0.0001)


func test_only_one_report_per_touchdown() -> void:
	var tracker := LandingTracker.new()
	tracker.step(false, -5.0)
	tracker.step(false, -5.5)

	assert_float(tracker.step(true, 0.0)).is_equal_approx(6.0, 0.0001)
	assert_float(tracker.step(true, 0.0)).is_equal(-1.0)


func test_upward_change_is_not_extrapolated() -> void:
	var tracker := LandingTracker.new()
	tracker.step(true, 0.0)
	# Jump launch then an immediate touchdown (a ledge at the jump's start height).
	tracker.step(false, 6.0)

	assert_float(tracker.step(true, 0.0)).is_equal(0.0)


func test_reset_forgets_the_history() -> void:
	var tracker := LandingTracker.new()
	tracker.step(false, -8.0)
	tracker.step(false, -9.0)

	tracker.reset(false)

	assert_float(tracker.step(true, 0.0)).is_equal(0.0)
