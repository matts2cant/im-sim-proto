extends GdUnitTestSuite
## Unit: TurretModel and TurretConfig (ADR 0079) with the shipped tuning (turret.tres: 1 s wind-up,
## bursts of 1.5 s with 0.75 s pauses, stops 1 s after losing sight; spread 3 + 0.1 per metre beyond
## 4 m; presets intruders / guards / everyone).

const CONFIG: TurretConfig = preload("res://objects/turret/turret.tres")
const TICK := 1.0 / 60.0


## Steps `seconds`; returns how many ticks it may fire.
func _run(model: TurretModel, seconds: float, seen: bool = true) -> int:
	var firing := 0
	for i in roundi(seconds * 60.0):
		model.step(TICK, seen, true)
		if model.may_fire():
			firing += 1
	return firing


func test_it_waits_for_a_full_meter_and_a_target_in_sight() -> void:
	var model := TurretModel.new(CONFIG)
	model.step(TICK, true, false)
	assert_int(model.state).is_equal(TurretModel.State.IDLE)
	model.step(TICK, false, true)
	assert_int(model.state).is_equal(TurretModel.State.IDLE)
	model.step(TICK, true, true)
	assert_int(model.state).is_equal(TurretModel.State.WINDUP)


func test_one_second_of_wind_up_then_bursts_and_pauses() -> void:
	var model := TurretModel.new(CONFIG)
	model.step(TICK, true, true)
	assert_int(_run(model, 0.95)).is_equal(0)
	assert_int(model.state).is_equal(TurretModel.State.WINDUP)
	_run(model, 0.1)
	assert_int(model.state).is_equal(TurretModel.State.FIRING)
	# From 1.0 s: firing to 2.5, pause to 3.25, firing to 4.75.
	var model2 := TurretModel.new(CONFIG)
	model2.step(TICK, true, true)
	_run(model2, 1.1)
	assert_bool(model2.may_fire()).is_true()
	_run(model2, 1.2)
	assert_bool(model2.may_fire()).is_true()
	_run(model2, 0.4)
	assert_bool(model2.may_fire()).is_false()
	_run(model2, 0.6)
	assert_bool(model2.may_fire()).is_true()


func test_firing_time_over_one_cycle_is_one_burst() -> void:
	var model := TurretModel.new(CONFIG)
	model.step(TICK, true, true)
	_run(model, 1.0)
	# One full burst + pause cycle (2.25 s): 1.5 s of firing.
	assert_float(_run(model, 2.25) * TICK).is_equal_approx(1.5, 0.05)


func test_it_stops_one_second_after_losing_sight() -> void:
	var model := TurretModel.new(CONFIG)
	model.step(TICK, true, true)
	_run(model, 1.5)
	_run(model, 0.9, false)
	assert_int(model.state).is_equal(TurretModel.State.FIRING)
	# Seen again: the loss timer restarts.
	_run(model, 0.1, true)
	_run(model, 0.9, false)
	assert_int(model.state).is_equal(TurretModel.State.FIRING)
	_run(model, 0.2, false)
	assert_int(model.state).is_equal(TurretModel.State.IDLE)


func test_spread_grows_beyond_4_m() -> void:
	assert_float(TurretModel.spread_deg(CONFIG, 2.0)).is_equal(3.0)
	assert_float(TurretModel.spread_deg(CONFIG, 6.0)).is_equal_approx(3.2, 0.001)
	assert_float(TurretModel.spread_deg(CONFIG, 14.0)).is_equal_approx(4.0, 0.001)


func test_presets_map_commands_to_hostile_tags() -> void:
	assert_array(CONFIG.preset_tags(Turret.TARGET_INTRUDERS)).contains_exactly([&"actor.player"])
	assert_array(CONFIG.preset_tags(Turret.TARGET_GUARDS)).contains_exactly([&"actor.guard"])
	assert_array(CONFIG.preset_tags(Turret.TARGET_EVERYONE)).contains_exactly_in_any_order(
		[&"actor.player", &"actor.guard"]
	)
	assert_bool(CONFIG.has_preset(DeviceSwitch.DISABLE)).is_false()
	assert_array(CONFIG.preset_tags(DeviceSwitch.DISABLE)).is_empty()
	assert_str(String(CONFIG.default_preset)).is_equal(String(Turret.TARGET_INTRUDERS))
