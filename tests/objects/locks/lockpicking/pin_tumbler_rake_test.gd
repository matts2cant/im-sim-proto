extends GdUnitTestSuite
## Unit (ADR 0109): raking in the pin-tumbler model. A stroke is the tip moving sideways in the
## bottom band faster than 2.5 slots/s; each reversal counts one (a tick, the scrape, a throttled rake
## noise at the scrape loudness). Every lock rattles; a Master on a rakeable lock (a property: at most
## 5 pins, all standard) with tension from the drop threshold to the sweet spot's top and no overset
## sets the binding pin every 3 strokes. Not untrained, not on a lock with spools, not too slow, not
## with the rhythm broken, not with the tip lifted; without tension, with too much or with an overset
## pin a caption says why. The strokes are mouse motion: a 3 Hz back-and-forth of the aim.

const LockpickHelpers := preload("res://tests/objects/locks/lockpicking/lockpick_helpers.gd")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")
const DT := 1.0 / 60.0
const SIMPLE: Array[StringName] = [&"standard", &"standard", &"standard"]
const STANDARD: Array[StringName] = [&"standard", &"standard", &"standard", &"standard", &"standard"]
const SECURE: Array[StringName] = [&"standard", &"standard", &"standard", &"spool", &"spool"]
const MASTER := 3


func test_a_master_rakes_simple_and_standard_locks_at_light_and_mid_tension() -> void:
	for types: Array[StringName] in [SIMPLE, STANDARD]:
		for tension: float in [0.15, 0.45]:
			var model := _model(types, MASTER)
			assert_bool(model.rakeable).is_true()
			model.tension = tension
			var seconds := _rake(model, 3.0, 1.0, 4.0)
			var at := "%d pins at %.2f" % [types.size(), tension]
			assert_bool(model.opened).override_failure_message(at).is_true()
			# 3 strokes a pin, 6 reversals a second: about 0.5 s a pin.
			assert_float(seconds).override_failure_message(at).is_between(0.4 * types.size(), 0.6 * types.size() + 0.3)


func test_every_lock_rattles_but_an_untrained_rake_sets_nothing() -> void:
	var model := _model(SIMPLE, 0)
	model.tension = 0.45
	_rake(model, 3.0, 1.0, 2.0)
	var events := model.take_events()
	assert_int(model.set_count()).is_equal(0)
	var strokes := _of(events, &"rake_stroke")
	assert_int(strokes.size()).is_greater(9)
	assert_str(String(strokes[0].cue)).is_equal("tick")
	assert_float(strokes[0].loudness).is_equal(0.0)
	# The rake noise: the scrape's loudness, at most every 0.6 s.
	var noises := _of(events, &"rake")
	assert_int(noises.size()).is_between(2, 4)
	assert_float(noises[0].loudness).is_equal(TUNING.noise_scrape)
	assert_array(_of(events, &"rake_hint")).is_empty()


func test_a_lock_with_spools_is_not_rakeable() -> void:
	var model := _model(SECURE, MASTER)
	assert_bool(model.rakeable).is_false()
	model.tension = 0.45
	_rake(model, 3.0, 1.5, 3.0)
	assert_int(model.set_count()).is_equal(0)
	assert_array(_of(model.take_events(), &"rake_hint")).is_empty()


func test_too_slow_or_broken_rhythm_sets_nothing() -> void:
	# Slow: 0.5 Hz over 0.6 slots is under 2.5 slots/s, no stroke at all.
	var slow := _model(STANDARD, MASTER)
	slow.tension = 0.45
	_rake(slow, 0.5, 0.6, 3.0)
	assert_int(slow.set_count()).is_equal(0)
	assert_array(_of(slow.take_events(), &"rake_stroke")).is_empty()
	# Fast bursts of two strokes, each followed by a slow 0.7 s drift back: the count restarts every
	# time.
	var bursts := _model(STANDARD, MASTER)
	bursts.tension = 0.45
	for i in 4:
		_rake(bursts, 3.0, 1.0, 0.4)
		_drift(bursts, 2.0, 0.7)
	assert_int(bursts.set_count()).is_equal(0)
	assert_int(_of(bursts.take_events(), &"rake_stroke").size()).is_greater(6)


func test_with_the_tip_lifted_it_does_not_rake() -> void:
	var model := _model(SIMPLE, MASTER)
	model.tension = 0.45
	model.move_aim(0.0, 0.3)
	_run(model, 0.3)
	_rake(model, 3.0, 1.0, 2.0)
	assert_int(model.set_count()).is_equal(0)
	assert_array(_of(model.take_events(), &"rake_stroke")).is_empty()
	assert_int(model.pick).is_equal(0)


func test_without_the_right_tension_a_caption_says_why() -> void:
	var none := _model(SIMPLE, MASTER)
	_rake(none, 3.0, 1.0, 3.2)
	assert_int(none.set_count()).is_equal(0)
	var hints := _of(none.take_events(), &"rake_hint")
	# At most one every 1.5 s.
	assert_int(hints.size()).is_between(2, 3)
	assert_str(hints[0].caption).is_equal("rattle: the pins bounce back, add a little tension")

	var heavy := _model(SIMPLE, MASTER)
	heavy.tension = 0.8
	_rake(heavy, 3.0, 1.0, 1.0)
	assert_int(heavy.set_count()).is_equal(0)
	assert_str(_of(heavy.take_events(), &"rake_hint")[0].caption).is_equal("rattle: too much tension, the pins bind")

	var jammed := _model(SIMPLE, MASTER)
	jammed.tension = 0.45
	jammed.pins[2].overset = true
	_rake(jammed, 3.0, 1.0, 1.0)
	assert_int(jammed.set_count()).is_equal(0)
	assert_str(_of(jammed.take_events(), &"rake_hint")[0].caption).is_equal(
		"rattle: a pin is overset, release the tension"
	)


# --- helpers -------------------------------------------------------------------------------------


func _model(types: Array[StringName], tier: int) -> PinTumbler:
	var model := PinTumbler.new(TUNING, LockpickHelpers.params(tier))
	model.build(types, 4127)
	return model


func _run(model: PinTumbler, seconds: float) -> void:
	for i in roundi(seconds / DT):
		model.step(DT)


# Strokes the aim back and forth around the middle of the keyway (`hz`, `amplitude` slots) for up to
# `seconds`, as mouse motion; stops once the lock opens. Returns the seconds it ran.
func _rake(model: PinTumbler, hz: float, amplitude: float, seconds: float) -> float:
	var center := (model.pins.size() - 1) / 2.0
	model.move_aim(center - model.aim_x, 0.0)
	var frames := roundi(seconds / DT)
	for i in frames:
		var goal := center + amplitude * sin(TAU * hz * i * DT)
		model.move_aim(goal - model.aim_x, 0.0)
		model.step(DT)
		if model.opened:
			return (i + 1) * DT
	return seconds


# Moves the aim along the keyway to `slot` at an even, slow pace over `seconds`.
func _drift(model: PinTumbler, slot: float, seconds: float) -> void:
	var frames := roundi(seconds / DT)
	var step := (slot - model.aim_x) / frames
	for i in frames:
		model.move_aim(step, 0.0)
		model.step(DT)


func _of(events: Array[PinTumbler.Event], kind: StringName) -> Array[PinTumbler.Event]:
	var out: Array[PinTumbler.Event] = []
	out.assign(events.filter(func(event: PinTumbler.Event) -> bool: return event.kind == kind))
	return out
