extends GdUnitTestSuite
## Unit: VisionRules (ADR 0067) with the guard's tuning, and the worked numbers of the brief: the
## gain fed to an AwarenessModel at 60 ticks per second, checked away from the thresholds.

const CONFIG: PerceptionConfig = preload("res://actors/guard/guard_perception.tres")
const AWARENESS: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const TICK := 1.0 / 60.0


func test_zones() -> void:
	assert_float(VisionRules.zone_factor(0.0, 19.0, CONFIG)).is_equal(1.0)
	assert_float(VisionRules.zone_factor(25.0, 15.0, CONFIG)).is_equal(1.0)
	assert_float(VisionRules.zone_factor(45.0, 6.0, CONFIG)).is_equal_approx(0.4, 0.0001)
	# Peripheral reaches 10 m only; focus 20 m; nothing past 60 degrees.
	assert_float(VisionRules.zone_factor(45.0, 12.0, CONFIG)).is_equal(0.0)
	assert_float(VisionRules.zone_factor(0.0, 22.0, CONFIG)).is_equal(0.0)
	assert_float(VisionRules.zone_factor(75.0, 3.0, CONFIG)).is_equal(0.0)
	assert_float(VisionRules.zone_factor(150.0, 3.0, CONFIG)).is_equal(0.0)


func test_light_factor_and_close_override() -> void:
	assert_float(VisionRules.light_factor(0.6, 4.0, CONFIG)).is_equal(1.0)
	assert_float(VisionRules.light_factor(0.25, 4.0, CONFIG)).is_equal_approx(0.375, 0.0001)
	assert_float(VisionRules.light_factor(0.05, 6.0, CONFIG)).is_equal(0.0)
	# Within 2 m (centre to centre) the light counts at least 0.5.
	assert_float(VisionRules.light_factor(0.05, 1.5, CONFIG)).is_equal_approx(0.5, 0.0001)
	assert_float(VisionRules.light_factor(0.6, 1.5, CONFIG)).is_equal(1.0)


func test_distance_factor() -> void:
	assert_float(VisionRules.distance_factor(4.0, CONFIG)).is_equal(1.0)
	assert_float(VisionRules.distance_factor(12.0, CONFIG)).is_equal_approx(0.65, 0.0001)
	assert_float(VisionRules.distance_factor(8.0, CONFIG)).is_equal_approx(0.85, 0.0001)
	assert_float(VisionRules.distance_factor(20.0, CONFIG)).is_equal_approx(0.25, 0.0001)


func test_angle_off_is_horizontal() -> void:
	var eye := Vector3(0, 1.6, 0)
	assert_float(VisionRules.angle_off(Vector3.FORWARD, eye, Vector3(0, 0, -4))).is_equal_approx(0.0, 0.001)
	assert_float(VisionRules.angle_off(Vector3.FORWARD, eye, Vector3(4, 3, -4))).is_equal_approx(45.0, 0.001)
	assert_float(VisionRules.angle_off(Vector3.FORWARD, eye, Vector3(0, 0, 3))).is_equal_approx(180.0, 0.001)


func test_lit_at_4m_in_focus_alerts_in_about_0_8s() -> void:
	var gain := VisionRules.gain(0.0, 4.0, 0.6, false, false, CONFIG)
	assert_float(gain).is_equal_approx(1.25, 0.0001)
	var model := _model()
	_see(model, gain, 0.4)
	assert_int(model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	_see(model, gain, 1.1)
	assert_int(model.state).is_equal(AwarenessModel.State.ALERTED)


func test_lit_at_12m_alerts_in_about_1_2s() -> void:
	var gain := VisionRules.gain(0.0, 12.0, 0.6, false, false, CONFIG)
	assert_float(gain).is_equal_approx(0.8125, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(1.1, 1.4)


func test_dim_at_4m_alerts_in_about_2_1s() -> void:
	var gain := VisionRules.gain(0.0, 4.0, 0.25, false, false, CONFIG)
	assert_float(gain).is_equal_approx(0.46875, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(1.9, 2.4)


func test_crouched_dim_at_8m_alerts_in_about_3_6s() -> void:
	var gain := VisionRules.gain(0.0, 8.0, 0.25, true, false, CONFIG)
	assert_float(gain).is_equal_approx(1.25 * 0.375 * 0.85 * 0.7, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(3.3, 3.9)


func test_dark_at_6m_is_never_seen() -> void:
	var gain := VisionRules.gain(0.0, 6.0, 0.05, false, false, CONFIG)
	assert_float(gain).is_equal(0.0)
	var model := _model()
	_see(model, gain, 5.0)
	assert_int(model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(model.meter).is_equal(0.0)


func test_peripheral_45_degrees_at_6m_alerts_in_about_2_1s() -> void:
	var gain := VisionRules.gain(45.0, 6.0, 0.6, false, false, CONFIG)
	assert_float(gain).is_equal_approx(0.475, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(1.9, 2.4)


func test_behind_is_never_seen() -> void:
	assert_float(VisionRules.gain(150.0, 3.0, 0.6, false, false, CONFIG)).is_equal(0.0)


func test_dark_at_1_5m_in_focus_is_seen_by_the_close_override() -> void:
	var gain := VisionRules.gain(0.0, 1.5, 0.0, false, false, CONFIG)
	assert_float(gain).is_equal_approx(0.625, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(1.45, 1.8)


func test_moving_in_the_dark_keeps_the_moving_floor() -> void:
	# ADR 0095: faster than 0.5 m/s (horizontal), the light factor is at least 0.14; a step.
	assert_float(VisionRules.light_factor(0.05, 6.0, CONFIG, 4.0)).is_equal_approx(0.14, 0.0001)
	assert_float(VisionRules.light_factor(0.05, 6.0, CONFIG, 1.0)).is_equal_approx(0.14, 0.0001)
	assert_float(VisionRules.light_factor(0.05, 6.0, CONFIG, 0.2)).is_equal(0.0)
	# Brighter than the floor, or close: the larger factor wins.
	assert_float(VisionRules.light_factor(0.25, 6.0, CONFIG, 4.0)).is_equal_approx(0.375, 0.0001)
	assert_float(VisionRules.light_factor(0.05, 1.5, CONFIG, 4.0)).is_equal_approx(0.5, 0.0001)


func test_walking_in_the_dark_at_4_5m_alerts_in_about_5_7s() -> void:
	# 4.5 m keeps clear of the 5 m distance breakpoint. Without the guard closing in.
	var gain := VisionRules.gain(0.0, 4.5, 0.05, false, false, CONFIG, 4.0)
	assert_float(gain).is_equal_approx(1.25 * 0.14, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(5.4, 6.0)


func test_crouch_walking_in_the_dark_at_4_5m_alerts_in_about_8_2s() -> void:
	var gain := VisionRules.gain(0.0, 4.5, 0.05, true, false, CONFIG, 2.0)
	assert_float(gain).is_equal_approx(1.25 * 0.14 * 0.7, 0.0001)
	assert_float(_time_to_alert(gain)).is_between(7.9, 8.5)


func test_cameras_have_no_moving_floor() -> void:
	var camera: PerceptionConfig = load("res://objects/camera/security_camera_perception.tres")
	assert_float(VisionRules.gain(0.0, 6.0, 0.05, false, false, camera, 4.0)).is_equal(0.0)


func test_wary_multiplies_the_gain() -> void:
	var calm := VisionRules.gain(0.0, 8.0, 0.25, false, false, CONFIG)
	var wary := VisionRules.gain(0.0, 8.0, 0.25, false, true, CONFIG)
	assert_float(wary).is_equal_approx(calm * 1.5, 0.0001)


func _model() -> AwarenessModel:
	return AwarenessModel.new(AWARENESS, 1)


func _see(model: AwarenessModel, gain: float, seconds: float) -> void:
	for i in roundi(seconds / TICK):
		model.step(TICK, true, gain, Vector3(0, 0, -4))


# Seconds of continuous sight until Alerted (at most 15 s).
func _time_to_alert(gain: float) -> float:
	var model := _model()
	for i in 900:
		model.step(TICK, true, gain, Vector3(0, 0, -4))
		if model.state == AwarenessModel.State.ALERTED:
			return (i + 1) * TICK
	return INF
