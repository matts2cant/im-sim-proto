extends GdUnitTestSuite
## Unit: CameraModel (ADR 0079), the camera's sweep and pan with the shipped tuning
## (security_camera.tres: +-40 degrees at 15 degrees/s, 2 s hold at each end, 15 degree pan steps).

const CONFIG: SecurityCameraConfig = preload("res://objects/camera/security_camera.tres")
const TICK := 1.0 / 60.0


func _run(model: CameraModel, seconds: float, paused: bool = false) -> void:
	for i in roundi(seconds * 60.0):
		model.step(TICK, paused)


func test_the_shipped_tuning() -> void:
	assert_float(CONFIG.sweep_half_angle).is_equal(40.0)
	assert_float(CONFIG.sweep_speed).is_equal(15.0)
	assert_float(CONFIG.sweep_hold).is_equal(2.0)
	assert_float(CONFIG.pan_step).is_equal(15.0)


func test_it_sweeps_to_an_end_holds_then_turns_back() -> void:
	var model := CameraModel.new(CONFIG)
	_run(model, 2.0)
	assert_float(model.yaw).is_equal_approx(30.0, 0.01)
	# 40 / 15 = 2.67 s to the left end, then it holds 2 s.
	_run(model, 1.0)
	assert_float(model.yaw).is_equal(40.0)
	_run(model, 1.5)
	assert_float(model.yaw).is_equal(40.0)
	# Hold over at 4.67 s; 1 s later it has turned back 15 degrees or so.
	_run(model, 1.5)
	assert_float(model.yaw).is_between(20.0, 30.0)
	assert_float(model.direction).is_equal(-1.0)


func test_a_full_cycle_covers_both_ends() -> void:
	var model := CameraModel.new(CONFIG)
	var lowest := 0.0
	var highest := 0.0
	# Period: 4 x 40 / 15 + 2 x 2 = 14.7 s.
	for i in roundi(15.0 * 60.0):
		model.step(TICK)
		lowest = minf(lowest, model.yaw)
		highest = maxf(highest, model.yaw)
	assert_float(lowest).is_equal(-40.0)
	assert_float(highest).is_equal(40.0)


func test_paused_it_keeps_pointing_where_it_was() -> void:
	var model := CameraModel.new(CONFIG)
	_run(model, 1.0)
	var before := model.yaw
	_run(model, 3.0, true)
	assert_float(model.yaw).is_equal(before)


func test_pan_steps_stop_the_sweep_and_clamp_to_the_range() -> void:
	var model := CameraModel.new(CONFIG)
	model.pan(1)
	assert_bool(model.sweeping).is_false()
	assert_float(model.yaw).is_equal(15.0)
	model.pan(1)
	model.pan(1)
	assert_float(model.yaw).is_equal(40.0)
	for i in 6:
		model.pan(-1)
	assert_float(model.yaw).is_equal(-40.0)
	_run(model, 2.0)
	assert_float(model.yaw).is_equal(-40.0)


func test_stop_and_resume_sweep() -> void:
	var model := CameraModel.new(CONFIG)
	_run(model, 1.0)
	model.stop_sweep()
	var stopped_at := model.yaw
	_run(model, 2.0)
	assert_float(model.yaw).is_equal(stopped_at)
	model.resume_sweep()
	_run(model, 1.0)
	assert_float(model.yaw).is_equal_approx(stopped_at + 15.0, 0.01)


func test_save_round_trip() -> void:
	var model := CameraModel.new(CONFIG)
	model.pan(-2)
	var copy := CameraModel.new(CONFIG)
	copy.from_dict(model.to_dict())
	assert_float(copy.yaw).is_equal(-30.0)
	assert_bool(copy.sweeping).is_false()
