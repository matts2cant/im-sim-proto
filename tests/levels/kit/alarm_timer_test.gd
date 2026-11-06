extends GdUnitTestSuite
## Unit: AlarmTimer (ADR 0072): on for its duration, restarted by raising again, ended by time or
## by clearing.

const TICK := 1.0 / 60.0


func test_runs_for_its_duration_then_ends_once() -> void:
	var timer := AlarmTimer.new()
	timer.raise(90.0)
	var ended := 0
	var ticks := 0
	while timer.is_on() and ticks < 10000:
		if timer.step(TICK):
			ended += 1
		ticks += 1
	assert_int(ended).is_equal(1)
	assert_float(ticks * TICK).is_equal_approx(90.0, 0.05)
	assert_bool(timer.step(TICK)).is_false()


func test_raising_again_restarts_it() -> void:
	var timer := AlarmTimer.new()
	timer.raise(90.0)
	for i in 3000:
		timer.step(TICK)
	assert_float(timer.left).is_equal_approx(40.0, 0.05)
	timer.raise(90.0)
	assert_float(timer.left).is_equal(90.0)


func test_clear_ends_it_now() -> void:
	var timer := AlarmTimer.new()
	timer.raise(90.0)
	timer.clear()
	assert_bool(timer.is_on()).is_false()
	assert_bool(timer.step(TICK)).is_false()
