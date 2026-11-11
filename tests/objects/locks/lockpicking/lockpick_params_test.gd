extends GdUnitTestSuite
## Unit (ADR 0107, 0109): the Lockpicking skill as attributes. Each tier's params equal the final
## prototype's skillParams(t) (sweet spot 40-3t .. 55+3t %, drop below 15-3t %, 0.3+0.15t s per
## dropped pin, +0.012t lift tolerance, 0.08-0.012t s set dwell, rake at Master); assists are
## cumulative from the assist attribute and a practice lock shows all of them; an augmentation-like
## modifier on the assist attribute raises it.

const LockpickHelpers := preload("res://tests/objects/locks/lockpicking/lockpick_helpers.gd")
const TUNING: LockpickTuning = preload("res://objects/locks/lockpicking/lockpick_tuning.tres")


func test_each_tier_matches_the_prototype_skill_params() -> void:
	for t in 4:
		var params := LockpickHelpers.params(t)
		assert_float(params.low).override_failure_message("tier %d" % t).is_equal_approx(0.40 - 0.03 * t, 0.0001)
		assert_float(params.high).is_equal_approx(0.55 + 0.03 * t, 0.0001)
		assert_float(params.drop).is_equal_approx(0.15 - 0.03 * t, 0.0001)
		assert_float(params.drop_delay).is_equal_approx(0.3 + 0.15 * t, 0.0001)
		assert_float(params.tolerance_bonus).is_equal_approx(0.012 * t, 0.0001)
		assert_float(params.set_dwell).is_equal_approx(0.08 - 0.012 * t, 0.0001)
		assert_bool(params.rake).is_equal(t >= 3)
		assert_int(params.assist).is_equal(t)


func test_the_sweet_spot_widens_from_40_55_to_31_64_percent() -> void:
	var untrained := LockpickHelpers.params(0)
	var master := LockpickHelpers.params(3)
	assert_str(untrained.zone(0.38)).is_equal("low")
	assert_str(untrained.zone(0.42)).is_equal("sweet")
	assert_str(untrained.zone(0.53)).is_equal("sweet")
	assert_str(untrained.zone(0.57)).is_equal("high")
	assert_str(master.zone(0.33)).is_equal("sweet")
	assert_str(master.zone(0.62)).is_equal("sweet")
	assert_str(master.zone(0.66)).is_equal("high")
	assert_str(master.zone(0.04)).is_equal("drop")


func test_assists_are_cumulative() -> void:
	var expected := [[false, false, false], [true, false, false], [true, true, false], [true, true, true]]
	for level in 4:
		assert_bool(LockpickParams.shows_gauge(level)).is_equal(expected[level][0])
		assert_bool(LockpickParams.shows_captions(level)).is_equal(expected[level][1])
		assert_bool(LockpickParams.shows_pins(level)).is_equal(expected[level][2])


func test_a_practice_lock_shows_every_assist() -> void:
	for level in 4:
		assert_int(LockpickParams.assist_for(level, true)).is_equal(LockpickParams.ASSIST_PINS)
	assert_int(LockpickParams.assist_for(1, false)).is_equal(1)


func test_any_modifier_on_the_assist_attribute_raises_it() -> void:
	var attributes := LockpickHelpers.attributes(1)
	attributes.add_modifier(Modifier.create(LockpickParams.ASSIST, Modifier.Op.ADD, 2.0, &"aug.test"))
	assert_int(LockpickParams.from_set(attributes, TUNING).assist).is_equal(3)


func test_the_gauge_zone_words_follow_the_thresholds() -> void:
	var params := LockpickHelpers.params(0)
	assert_str(params.zone(0.1)).is_equal("drop")
	assert_str(params.zone(0.2)).is_equal("low")
	assert_str(params.zone(0.45)).is_equal("sweet")
	assert_str(params.zone(0.8)).is_equal("high")
