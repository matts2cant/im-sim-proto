extends GdUnitTestSuite
## Unit: SightMeter (ADR 0079), the detection meter of cameras and turrets: rise by gain, decay,
## one detection, then none until nothing has been seen for the cooldown.

const TICK := 1.0 / 60.0


func _run(meter: SightMeter, seconds: float, gain: float) -> int:
	var detections := 0
	for i in roundi(seconds * 60.0):
		if meter.step(TICK, gain):
			detections += 1
	return detections


func test_a_gain_of_0_8_detects_after_1_25_seconds() -> void:
	var meter := SightMeter.new(0.25, 10.0)
	assert_int(_run(meter, 1.2, 0.8)).is_equal(0)
	assert_float(meter.meter).is_between(0.9, 0.99)
	assert_int(_run(meter, 0.1, 0.8)).is_equal(1)
	assert_bool(meter.detected).is_true()
	assert_float(meter.meter).is_equal(1.0)


func test_the_meter_falls_while_nothing_is_seen() -> void:
	var meter := SightMeter.new(0.25, 10.0)
	_run(meter, 1.0, 0.5)
	_run(meter, 1.0, 0.0)
	assert_float(meter.meter).is_equal_approx(0.25, 0.01)
	_run(meter, 2.0, 0.0)
	assert_float(meter.meter).is_equal(0.0)


func test_no_second_detection_until_unseen_for_the_cooldown() -> void:
	var meter := SightMeter.new(0.25, 10.0)
	assert_int(_run(meter, 2.0, 2.0)).is_equal(1)
	# Still in view, then out of view for 5 s, back in view: no new detection.
	assert_int(_run(meter, 3.0, 2.0)).is_equal(0)
	_run(meter, 5.0, 0.0)
	assert_int(_run(meter, 2.0, 2.0)).is_equal(0)
	assert_bool(meter.detected).is_true()
	# Unseen for 11 s: the cooldown is over and a new sighting detects again.
	_run(meter, 11.0, 0.0)
	assert_bool(meter.detected).is_false()
	assert_int(_run(meter, 1.0, 2.0)).is_equal(1)


func test_reset_and_save_round_trip() -> void:
	var meter := SightMeter.new(0.25, 10.0)
	_run(meter, 1.0, 2.0)
	var copy := SightMeter.new(0.25, 10.0)
	copy.from_dict(meter.to_dict())
	assert_bool(copy.detected).is_true()
	assert_float(copy.meter).is_equal(1.0)
	meter.reset()
	assert_bool(meter.detected).is_false()
	assert_float(meter.meter).is_equal(0.0)
