extends GdUnitTestSuite
## Unit (ADR 0109): the pick in the pin-tumbler model, as the final prototype moves it. The tip slides
## along the keyway (mouse motion or A / D) only while tip and aim are in the bottom band, its pin is
## the nearest slot past the hysteresis; the key pin rests on the tip, set or not; the binding pin
## sets after a dwell at its shear line (a fast lift through it oversets); after a set the aim's lead
## is a bias, so holding the aim (or a small extra lift) does not overset at any sweet-spot tension;
## a set pin shoved past the margin and a loose pin shoved to the top overset, never below the sweet
## spot; the wheel turns the wrench in notches.

const LockpickHelpers := preload("res://tests/objects/locks/lockpicking/lockpick_helpers.gd")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")
const DT := 1.0 / 60.0
const SHEAR := 0.5
const FIVE: Array[StringName] = [&"standard", &"standard", &"standard", &"standard", &"standard"]


func test_mouse_motion_slides_the_tip_only_in_the_bottom_band() -> void:
	var model := _model(FIVE, [4, 3, 2, 1, 0])
	model.tension = 0.45
	model.move_aim(2.0, 0.0)
	_run(model, 0.5)
	assert_int(model.pick).is_equal(2)
	assert_float(model.tip_x).is_equal_approx(2.0, 0.02)
	# Lifted above the band, the tip stays under its pin whatever the mouse does sideways.
	model.move_aim(0.0, 0.3)
	_run(model, 0.3)
	assert_float(model.tip).is_greater(0.2)
	model.move_aim(2.0, 0.0)
	_run(model, 0.5)
	assert_int(model.pick).is_equal(2)
	assert_float(model.tip_x).is_equal_approx(2.0, 0.02)
	assert_float(model.pins[2].height).is_equal_approx(model.tip, 0.001)
	# Back down, it slides on to where the mouse aims, lifting no pin on the way.
	model.move_aim(0.0, -0.3)
	var highest := 0.0
	for i in 40:
		_run(model, DT)
		for k: int in [0, 1, 3]:
			highest = maxf(highest, model.pins[k].height)
	assert_int(model.pick).is_equal(4)
	assert_float(highest).is_less(TUNING.bottom_band + 0.01)
	# The aim stops a little past the back pin.
	model.move_aim(5.0, 0.0)
	assert_float(model.aim_x).is_equal_approx(4.0 + TUNING.aim_x_margin, 0.0001)


func test_a_and_d_move_the_tip_only_in_the_bottom_band() -> void:
	var model := _model(FIVE, [4, 3, 2, 1, 0])
	model.tension = 0.45
	model.step_pin(1)
	model.step_pin(1)
	_run(model, 0.5)
	assert_int(model.pick).is_equal(2)
	model.step_pin(-1)
	_run(model, 0.4)
	assert_int(model.pick).is_equal(1)
	# Lifted: A / D do nothing.
	model.move_aim(0.0, 0.3)
	_run(model, 0.2)
	model.step_pin(1)
	assert_float(model.aim_x).is_equal_approx(1.0, 0.0001)
	_run(model, 0.3)
	assert_int(model.pick).is_equal(1)
	# At the back the next press stays on the last pin.
	model.move_aim(0.0, -0.3)
	_run(model, 0.2)
	for i in 5:
		model.step_pin(1)
	assert_float(model.aim_x).is_equal(4.0)


func test_the_pin_is_the_nearest_slot_past_the_hysteresis() -> void:
	var model := _model(FIVE, [4, 3, 2, 1, 0])
	model.tension = 0.45
	# Half a slot over: still pin 0.
	_slide_to(model, 0.5)
	assert_int(model.pick).is_equal(0)
	_slide_to(model, 0.62)
	assert_int(model.pick).is_equal(1)
	# Coming back, pin 1 holds until the tip is more than 0.55 slots from it.
	_slide_to(model, 0.48)
	assert_int(model.pick).is_equal(1)
	_slide_to(model, 0.38)
	assert_int(model.pick).is_equal(0)


func test_a_set_pins_key_pin_rests_on_the_tip() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	_set_binding(model)
	assert_bool(model.pins[0].is_set).is_true()
	# The aim lowered (wearing off the bias), then raised a little: the key pin drops onto the tip and
	# follows it; the pin stays set.
	model.aim = 0.0
	_run(model, DT)
	model.aim = 0.2
	_run(model, 0.4)
	assert_float(model.tip).is_equal_approx(0.2, 0.01)
	assert_float(model.pins[0].height).is_equal(model.tip)
	assert_bool(model.pins[0].is_set).is_true()
	# Lifted to its shear line again: it rides the tip up (no margin below the shear line).
	model.aim = SHEAR + 0.05
	_run(model, 0.4)
	assert_float(model.pins[0].height).is_equal(model.tip)
	assert_float(model.tip).is_greater(SHEAR)
	assert_bool(model.pins[0].is_set).is_true()


func test_a_slow_lift_with_a_stop_sets_after_the_dwell() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	_lift_binding(model)
	var tol := TUNING.base_tolerance
	var frames_in := 0
	while not model.pins[0].is_set and frames_in < 60:
		_run(model, DT)
		if model.pins[0].height >= SHEAR - tol:
			frames_in += 1
	assert_bool(model.pins[0].is_set).is_true()
	assert_bool(model.pins[0].overset).is_false()
	# Untrained: 0.08 s at the shear line (about 5 frames at 60 Hz) before the click.
	assert_int(frames_in).is_between(4, 7)


func test_a_fast_lift_through_the_shear_line_oversets() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	model.aim = 1.0
	_run(model, 0.5)
	assert_bool(model.pins[0].is_set).is_false()
	assert_bool(model.pins[0].overset).is_true()
	assert_array(_events(model, &"set")).is_empty()


func test_no_overset_after_a_click_with_the_aim_held() -> void:
	for tension: float in [0.42, 0.47, 0.54]:
		var model := _model([&"standard", &"standard"], [0, 1])
		model.tension = tension
		_lift_binding(model)
		_run_until_set(model, 0)
		var at := "tension %.2f" % tension
		var tip := model.tip
		assert_bool(model.pins[0].is_set).override_failure_message(at).is_true()
		# The aim held where it was: the tip does not spring up after the click.
		_run(model, 0.5)
		assert_bool(model.pins[0].overset).override_failure_message(at).is_false()
		assert_float(model.tip).override_failure_message(at).is_equal_approx(tip, 0.005)
		# A small extra lift does not overset it either.
		model.move_aim(0.0, 0.08)
		_run(model, 0.4)
		assert_bool(model.pins[0].overset).override_failure_message(at).is_false()
		assert_bool(model.pins[0].is_set).override_failure_message(at).is_true()


func test_lowering_the_aim_wears_the_bias_off() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	_lift_binding(model)
	_run_until_set(model, 0)
	assert_float(model.aim_bias).is_greater(0.1)
	model.move_aim(0.0, -1.0)
	_run(model, DT)
	assert_float(model.aim_bias).is_equal(0.0)
	model.move_aim(0.0, 0.3)
	_run(model, 0.5)
	assert_float(model.tip).is_equal_approx(0.3, 0.005)


func test_a_set_pin_shoved_past_the_margin_oversets() -> void:
	var model := _model([&"standard", &"standard"], [0, 1])
	model.tension = 0.45
	_lift_binding(model)
	_run_until_set(model, 0)
	model.take_events()
	# The tolerance is 0.045 (untrained): shove it 0.15 past that and a bit more.
	model.move_aim(0.0, 0.15 + 2.0 * TUNING.base_tolerance + 0.05)
	_run(model, 0.4)
	assert_bool(model.pins[0].overset).is_true()
	assert_bool(model.pins[0].is_set).is_false()
	assert_int(model.set_count()).is_equal(0)
	assert_int(_events(model, &"overset").size()).is_equal(1)


func test_a_loose_pin_shoved_to_the_top_oversets() -> void:
	var model := _model([&"standard", &"standard"], [1, 0])
	model.tension = 0.45
	model.aim = 1.0
	_run(model, 0.4)
	assert_bool(model.pins[0].overset).is_true()
	# A loose pin to its shear line and a little over does not.
	var other := _model([&"standard", &"standard"], [1, 0])
	other.tension = 0.45
	other.aim = SHEAR + 0.1
	_run(other, 0.4)
	assert_bool(other.pins[0].overset).is_false()


func test_no_overset_below_the_sweet_spot() -> void:
	# Untrained sweet spot from 40 %: at 30 % a loose pin to the top and a fast lift of the binding
	# pin do not overset.
	var loose := _model([&"standard", &"standard"], [1, 0])
	loose.tension = 0.30
	loose.aim = 1.0
	_run(loose, 0.4)
	assert_bool(loose.pins[0].overset).is_false()
	var bound := _model([&"standard", &"standard"], [0, 1])
	bound.tension = 0.30
	bound.aim = 1.0
	_run(bound, 0.6)
	assert_float(bound.pins[0].height).is_greater(SHEAR + 0.2)
	assert_bool(bound.pins[0].overset).is_false()
	assert_bool(bound.pins[0].is_set).is_false()


func test_the_wheel_turns_the_wrench_in_notches() -> void:
	var model := _model(FIVE, [0, 1, 2, 3, 4])
	model.turn_wrench(3.0, false)
	assert_float(model.tension).is_equal_approx(0.09, 0.0001)
	model.turn_wrench(2.0, true)
	assert_float(model.tension).is_equal_approx(0.11, 0.0001)
	model.turn_wrench(-1.0, false)
	assert_float(model.tension).is_equal_approx(0.08, 0.0001)
	model.turn_wrench(-10.0, false)
	assert_float(model.tension).is_equal(0.0)
	model.turn_wrench(50.0, false)
	assert_float(model.tension).is_equal(1.0)


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


func _run_until_set(model: PinTumbler, index: int) -> void:
	var frames := 0
	while not model.pins[index].is_set and frames < 120:
		model.step(DT)
		frames += 1


# Aims along the keyway at `slot` (in the bottom band) and waits for the tip to get there.
func _slide_to(model: PinTumbler, slot: float) -> void:
	model.move_aim(slot - model.aim_x, 0.0)
	_run(model, 0.6)


# Aims the lift so the tip settles on the binding pin's shear line.
func _lift_binding(model: PinTumbler) -> void:
	model.aim = model.pins[model.binding_index()].shear + LockpickHelpers.required(model) + 0.01


func _set_binding(model: PinTumbler) -> void:
	var index := model.binding_index()
	var frames := 0
	while not model.pins[index].is_set and frames < 180:
		LockpickHelpers.drive(model, index)
		_run(model, DT)
		frames += 1


func _events(model: PinTumbler, kind: StringName) -> Array[PinTumbler.Event]:
	var out: Array[PinTumbler.Event] = []
	for event in model.take_events():
		if event.kind == kind:
			out.append(event)
	return out
