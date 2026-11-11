extends GdUnitTestSuite
## Unit (ADR 0113): TraceModel, a tracer's pure logic with the default tuning (tracer.tres: drain
## 10 %/s from 2 s after the last gain, lockout 30 s). Gains add up to 100 %; filling reports once
## while the address is locked out; traces of different users are apart.

const CONFIG: TracerConfig = preload("res://objects/network/tracer.tres")
const SENSITIVE: TracerConfig = preload("res://objects/network/tracer_sensitive.tres")
const STEP := 1.0 / 60.0


func _run(model: TraceModel, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		model.step(STEP)


func test_the_shipped_tuning() -> void:
	assert_float(CONFIG.gain_per_second).is_equal(4.0)
	assert_float(SENSITIVE.gain_per_second).is_equal(7.0)
	assert_float(CONFIG.failed_login).is_equal(15.0)
	assert_float(CONFIG.scan).is_equal(10.0)
	assert_float(CONFIG.drain_per_second).is_equal(10.0)
	assert_float(CONFIG.drain_delay).is_equal(2.0)
	assert_float(CONFIG.lockout).is_equal(30.0)


func test_gains_add_up_and_cap_at_full() -> void:
	var model := TraceModel.new(CONFIG)
	assert_bool(model.add("you", 15.0, "a")).is_false()
	assert_bool(model.add("you", 60.0, "a")).is_false()
	assert_float(model.trace_of("you")).is_equal_approx(75.0, 0.001)
	assert_bool(model.add("you", 40.0, "a")).is_true()
	assert_float(model.trace_of("you")).is_equal(100.0)
	assert_float(model.trace_of("other")).is_equal(0.0)


func test_trace_drains_two_seconds_after_the_last_gain() -> void:
	var model := TraceModel.new(CONFIG)
	model.add("you", 60.0, "a")
	_run(model, 1.5)
	assert_float(model.trace_of("you")).is_equal(60.0)
	# 60 % drains in 8 s once draining starts (2 s after the gain).
	_run(model, 0.5 + 4.0)
	assert_float(model.trace_of("you")).is_equal_approx(20.0, 0.5)
	_run(model, 4.5)
	assert_float(model.trace_of("you")).is_equal(0.0)
	# A new gain restarts the delay.
	model.add("you", 10.0, "a")
	_run(model, 1.0)
	assert_float(model.trace_of("you")).is_equal(10.0)


func test_a_lockout_counts_down_and_full_fires_once_while_locked() -> void:
	var model := TraceModel.new(CONFIG)
	assert_bool(model.add("you", 100.0, "10.0.10.40")).is_true()
	model.lock("10.0.10.40")
	assert_bool(model.is_locked("10.0.10.40")).is_true()
	assert_bool(model.is_locked("10.0.10.12")).is_false()
	_run(model, 10.0)
	# Drained below full, then full again while still locked: no second report.
	assert_bool(model.add("you", 100.0, "10.0.10.40")).is_false()
	_run(model, 20.5)
	assert_bool(model.is_locked("10.0.10.40")).is_false()
	assert_float(model.lockout_left("10.0.10.40")).is_equal(0.0)


func test_state_round_trips() -> void:
	var model := TraceModel.new(CONFIG)
	model.add("you", 42.0, "a")
	model.lock("a")
	_run(model, 1.0)
	var again := TraceModel.new(CONFIG)
	again.from_dict(JSON.to_native(JSON.from_native(model.to_dict())) as Dictionary)
	assert_float(again.trace_of("you")).is_equal_approx(42.0, 0.001)
	assert_float(again.lockout_left("a")).is_equal_approx(29.0, 0.02)
	_run(again, 1.5)
	assert_float(again.trace_of("you")).is_less(42.0)
