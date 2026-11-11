extends GdUnitTestSuite
## Unit (ADR 0073, 0107, 0109): the pin-tumbler model, a port of the final prototype's step():
## binding order, set click, drops below the drop threshold and at 0 %, overset and its recovery,
## spool false set and counter-rotation, serrated ticks, strain and pick break at high tension, the
## open, the seed and a practice re-layout. Pins get fixed shear lifts so the numbers are known;
## tension is set directly (the wheel only changes it by notches). The pick's movement, the set and
## overset rules are in pin_tumbler_pick_test.gd, raking in pin_tumbler_rake_test.gd.

const LockpickHelpers := preload("res://tests/objects/locks/lockpicking/lockpick_helpers.gd")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")
const DT := 1.0 / 60.0
const SHEAR := 0.5


func test_one_pin_binds_at_a_time_in_the_seeded_order() -> void:
	var model := _model([&"standard", &"standard", &"standard"], [2, 0, 1])
	model.tension = 0.45
	assert_int(model.binding_index()).is_equal(2)
	# The pick on pin 0 (not binding) lifts it freely: no set at its shear line.
	model.aim = 0.45
	_run(model, 0.4)
	assert_float(model.pins[0].height).is_equal_approx(0.45, 0.01)
	assert_int(model.set_count()).is_equal(0)
	# The binding pin sets with a click; then the next one in the order binds.
	_set_binding(model)
	assert_bool(model.pins[2].is_set).is_true()
	assert_int(model.binding_index()).is_equal(0)


func test_lifting_the_binding_pin_to_the_shear_line_clicks() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	var angle := model.plug_angle_deg()
	_lift_binding(model)
	_run(model, 0.6)

	assert_bool(model.pins[0].is_set).is_true()
	var clicks := _events(model, &"set")
	assert_int(clicks.size()).is_equal(1)
	assert_str(String(clicks[0].cue)).is_equal("click")
	assert_str(clicks[0].caption).is_equal("click")
	assert_float(clicks[0].loudness).is_equal(2.0)
	# The plug turns a hair per set pin.
	assert_float(model.plug_angle_deg() - angle).is_equal_approx(TUNING.plug_set_turn, 0.01)


func test_above_the_sweet_spot_the_click_is_muted() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.7
	_lift_binding(model)
	_run(model, 1.0)
	var clicks := _events(model, &"set")
	assert_int(clicks.size()).is_equal(1)
	assert_str(String(clicks[0].cue)).is_equal("click_muted")


func test_set_pins_drop_below_the_threshold_one_by_one_and_all_at_zero() -> void:
	var model := _model([&"standard", &"standard", &"standard"], [0, 1, 2])
	model.tension = 0.45
	_set_binding(model)
	_set_binding(model)
	assert_int(model.set_count()).is_equal(2)
	model.take_events()
	# Untrained: below 15 % the last set pin drops after 0.3 s.
	model.tension = 0.10
	_run(model, 0.25)
	assert_int(model.set_count()).is_equal(2)
	_run(model, 0.1)
	assert_int(model.set_count()).is_equal(1)
	assert_str(_events(model, &"drop")[0].caption).is_equal("a pin drops")
	# At 0 % every pin drops at once.
	model.tension = 0.0
	_run(model, DT)
	assert_int(model.set_count()).is_equal(0)
	assert_str(_events(model, &"drop")[0].caption).is_equal("pins drop")


func test_an_overset_jams_until_tension_is_released() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	# Lifted high with too little tension to bind, then tension: the pin is past its shear line.
	model.tension = 0.10
	model.aim = 0.95
	_run(model, 0.4)
	model.tension = 0.45
	_run(model, DT * 2)
	assert_bool(model.pins[0].overset).is_true()
	var jams := _events(model, &"overset")
	assert_int(jams.size()).is_equal(1)
	assert_str(String(jams[0].cue)).is_equal("jam")
	assert_str(jams[0].caption).is_equal("clunk, a pin is overset: release the tension to reset")
	assert_float(jams[0].loudness).is_equal(3.0)
	# Jammed: lowering and lifting again does not set it.
	model.aim = 0.0
	_run(model, 0.3)
	_lift_binding(model)
	_run(model, 0.6)
	assert_bool(model.pins[0].is_set).is_false()
	# Releasing tension recovers it; then it sets normally.
	model.tension = 0.0
	model.aim = 0.0
	_run(model, 0.3)
	assert_bool(model.pins[0].overset).is_false()
	model.tension = 0.45
	_set_binding(model)
	assert_bool(model.pins[0].is_set).is_true()


func test_a_spool_false_sets_then_needs_tension_eased_while_lifting() -> void:
	var model := _model([&"spool", &"standard"], [0, 1])
	model.tension = 0.45
	var before := model.plug_angle_deg()
	model.aim = model.pins[0].false_lift + LockpickHelpers.required(model) + 0.02
	_run(model, 0.6)
	assert_int(_events(model, &"false_set").size()).is_equal(1)
	assert_int(model.pins[0].spool).is_equal(PinTumbler.Spool.FALSE_SET)
	# The plug turns noticeably further.
	assert_float(model.plug_angle_deg() - before).is_greater(3.0)
	# Holding tension, the spool stays stuck however hard the pick pushes.
	var stuck_at := model.tip
	_lift_binding(model)
	_run(model, 0.3)
	assert_float(model.tip).is_equal_approx(stuck_at, 0.001)
	assert_bool(model.pins[0].is_set).is_false()
	# Easing tension below the false-set tension lets it rise: the plug turns back (creak), then it sets.
	model.tension = 0.36
	_lift_binding(model)
	_run(model, 0.8)
	assert_int(_events(model, &"creak").size()).is_greater(0)
	assert_bool(model.pins[0].is_set).is_true()
	assert_float(model.false_turn).is_equal(0.0)


func test_serrated_pins_tick_before_they_set() -> void:
	var model := _model([&"serrated", &"standard"], [0, 1])
	model.tension = 0.45
	model.aim = SHEAR + LockpickHelpers.required(model) + TUNING.tick_bump
	_run(model, 1.2)
	var ticks := _events(model, &"tick")
	assert_int(ticks.size()).is_equal(2)
	assert_float(ticks[0].loudness).is_equal(2.0)
	assert_bool(model.pins[0].is_set).is_true()
	assert_float(model.tick_turn).is_equal_approx(2 * TUNING.tick_turn, 0.001)


func test_forcing_a_bound_pin_at_high_tension_snaps_the_pick() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.pins[0].shear = 0.74
	model.tension = 0.9
	model.aim = 1.0
	_run(model, 0.25)
	assert_float(model.strain).is_greater(0.2)
	assert_array(_events(model, &"snap")).is_empty()
	_run(model, 1.5)
	var snaps := _events(model, &"snap")
	assert_int(snaps.size()).is_equal(1)
	assert_float(snaps[0].loudness).is_equal(6.0)
	# Tension and lift released, progress lost.
	assert_float(model.tension).is_equal(0.0)
	assert_float(model.aim).is_equal(0.0)
	assert_float(model.strain).is_equal(0.0)


func test_the_same_push_in_the_sweet_spot_does_not_strain() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.pins[0].shear = 0.74
	model.tension = 0.45
	model.aim = 1.0
	_run(model, 2.0)
	assert_float(model.strain).is_equal(0.0)
	assert_array(_events(model, &"snap")).is_empty()


func test_the_last_set_opens_and_the_open_noise_follows() -> void:
	var model := _model([&"standard"], [0])
	model.tension = 0.45
	_set_binding(model)
	assert_bool(model.opened).is_true()
	assert_array(_events(model, &"open")).is_empty()
	_run(model, 0.15)
	var opens := _events(model, &"open")
	assert_int(opens.size()).is_equal(1)
	assert_float(opens[0].loudness).is_equal(4.0)
	_run(model, 0.6)
	assert_float(model.plug_angle_deg()).is_equal_approx(TUNING.plug_open_base + TUNING.plug_open_turn, 0.5)


func test_scrape_and_strain_fall_silent_once_it_opens() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	_set_binding(model)
	# The last pin: lifted while it rubs, with some strain left from earlier forcing.
	LockpickHelpers.drive(model, 1)
	_run(model, 0.4)
	model.strain = 0.6
	_lift_binding(model)
	var scraped := 0.0
	for i in 60:
		_run(model, DT)
		if model.opened:
			break
		scraped = maxf(scraped, model.scraping)
	assert_float(scraped).is_greater(0.0)
	assert_bool(model.opened).is_true()
	_run(model, DT)
	assert_float(model.scraping).is_equal(0.0)
	assert_float(model.strain).is_equal(0.0)


func test_a_careful_player_opens_a_standard_lock() -> void:
	var model := PinTumbler.new(TUNING, LockpickHelpers.params(0))
	model.build([&"standard", &"standard", &"standard", &"standard", &"standard"], 4127)
	var seconds := LockpickHelpers.solve(model, 0.47, DT, 20.0)
	assert_float(seconds).is_between(0.5, 20.0)
	assert_array(_events(model, &"overset")).is_empty()


func test_the_same_seed_gives_the_same_lock() -> void:
	var types: Array[StringName] = [&"standard", &"spool", &"standard", &"serrated"]
	var a := PinTumbler.new(TUNING, LockpickHelpers.params(0))
	a.build(types, 4127)
	var b := PinTumbler.new(TUNING, LockpickHelpers.params(0))
	b.build(types, 4127)
	var c := PinTumbler.new(TUNING, LockpickHelpers.params(0))
	c.build(types, 4128)
	assert_array(a.order).is_equal(b.order)
	assert_float(a.pins[1].shear).is_equal(b.pins[1].shear)
	assert_str(String(a.pins[1].type)).is_equal("spool")
	assert_bool(a.pins[0].shear == c.pins[0].shear and a.order == c.order).is_false()
	for pin in a.pins:
		assert_float(pin.shear).is_between(TUNING.pin_height_min, TUNING.pin_height_min + TUNING.pin_height_range)


func test_a_relock_lays_new_pins_that_settle() -> void:
	var model := _model([&"standard"], [0])
	model.tension = 0.45
	_set_binding(model)
	_run(model, 1.0)
	var types: Array[StringName] = [&"standard", &"standard", &"standard"]
	model.relock(types, 77, 1.1, true)
	assert_bool(model.opened).is_false()
	assert_int(model.pins.size()).is_equal(3)
	assert_float(model.tension).is_equal(0.0)
	assert_float(model.aim).is_equal(0.0)
	assert_float(model.relayout_t).is_equal(0.0)
	# The old drawn shear line eases to the new one over about 0.5 s; the plug turns back.
	assert_float(model.pins[0].shown_shear).is_equal_approx(SHEAR, 0.0001)
	assert_float(model.plug_angle_deg()).is_greater(45.0)
	_run(model, 0.55)
	assert_float(model.relayout_t).is_equal(1.0)
	assert_float(model.pins[0].shown_shear).is_equal(model.pins[0].shear)
	assert_float(model.plug_angle_deg()).is_less(1.0)
	assert_float(model.pins[0].height).is_equal(0.0)


# --- helpers -------------------------------------------------------------------------------------


func _model(types: Array, binding: Array, tier: int = 0) -> PinTumbler:
	var kinds: Array[StringName] = []
	kinds.assign(types)
	var model := PinTumbler.new(TUNING, LockpickHelpers.params(tier))
	model.build(kinds, 4127)
	for pin in model.pins:
		LockpickHelpers.fix_pin(pin, SHEAR, TUNING)
	var order: Array[int] = []
	order.assign(binding)
	model.order = order
	return model


func _run(model: PinTumbler, seconds: float) -> void:
	for i in roundi(seconds / DT):
		model.step(DT)


# Aims the lift so the tip settles on the binding pin's shear line.
func _lift_binding(model: PinTumbler) -> void:
	model.aim = model.pins[model.binding_index()].shear + LockpickHelpers.required(model) + 0.01


# Moves to the binding pin, sets it, and lowers the aim again.
func _set_binding(model: PinTumbler) -> void:
	var index := model.binding_index()
	var frames := 0
	while not model.pins[index].is_set and frames < 180:
		LockpickHelpers.drive(model, index)
		_run(model, DT)
		frames += 1
	model.aim = 0.0


func _events(model: PinTumbler, kind: StringName) -> Array[PinTumbler.Event]:
	var out: Array[PinTumbler.Event] = []
	for event in model.take_events():
		if event.kind == kind:
			out.append(event)
	return out
