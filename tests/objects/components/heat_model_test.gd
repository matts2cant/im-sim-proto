extends GdUnitTestSuite
## Unit: heat accumulation and cooling (ADR 0046) and the expected ignition times of the M3 brief.

const SMALL_CRATE: FlammableConfig = preload("res://objects/small_crate/small_crate_fire.tres")
const LARGE_CRATE: FlammableConfig = preload("res://objects/large_crate/large_crate_fire.tres")
const CARDBOARD: FlammableConfig = preload("res://objects/cardboard_box/cardboard_box_fire.tres")
const BRAZIER: FlammableConfig = preload("res://objects/brazier/brazier_fire.tres")
const BARREL: ExplosiveConfig = preload("res://objects/explosive_barrel/explosive_barrel_explosive.tres")


func test_add_accumulates_and_reports_threshold() -> void:
	var model := HeatModel.new(6.0, 0.5)

	assert_bool(model.add(2.5)).is_false()
	assert_bool(model.add(2.5)).is_false()
	assert_bool(model.add(1.0)).is_true()
	assert_float(model.heat).is_equal_approx(6.0, 0.0001)


func test_negative_heat_is_ignored() -> void:
	var model := HeatModel.new(6.0, 0.5)
	model.add(2.0)

	model.add(-5.0)

	assert_float(model.heat).is_equal_approx(2.0, 0.0001)


func test_cooling_is_continuous_and_stops_at_zero() -> void:
	var model := HeatModel.new(6.0, 0.5)
	model.add(2.0)

	for i in 60:
		model.cool(1.0 / 60.0)
	assert_float(model.heat).is_equal_approx(1.5, 0.0001)

	model.cool(10.0)
	assert_float(model.heat).is_equal(0.0)


func test_zero_threshold_never_reached() -> void:
	assert_bool(HeatModel.new(0.0, 0.5).add(100.0)).is_false()


func test_small_crate_next_to_burning_small_crate_ignites_in_three_seconds() -> void:
	# Centres 0.6 m apart (touching 0.6 m crates): perceived 2.0 x (1 - 0.6 / 1.5) = 1.2 per pulse,
	# cooling 0.25 between pulses: 1.2 k - 0.25 (k - 1) >= 6 first at k = 7, i.e. 6 intervals = 3.0 s.
	var perceived := StimulusPropagation.falloff(SMALL_CRATE.intensity, SMALL_CRATE.radius, 0.6)

	assert_float(perceived).is_equal_approx(1.2, 0.0001)
	assert_float(_seconds(perceived, SMALL_CRATE)).is_equal_approx(3.0, 0.0001)


func test_crate_touching_brazier_ignites_in_two_seconds() -> void:
	# Brazier fire at its centre (0.45 m up), crate centre 0.6 m away at 0.3 m up: 0.618 m,
	# perceived 3.0 x (1 - 0.618 / 1.2) = 1.45; 5 pulses = 2.0 s.
	var distance := Vector3(0, 0.45, 0).distance_to(Vector3(0.6, 0.3, 0))
	var perceived := StimulusPropagation.falloff(BRAZIER.intensity, BRAZIER.radius, distance)

	assert_float(perceived).is_equal_approx(1.454, 0.001)
	assert_float(_seconds(perceived, SMALL_CRATE)).is_equal_approx(2.0, 0.0001)


func test_crate_with_a_gap_takes_much_longer() -> void:
	# A 0.6 m gap (centres 1.2 m): 0.4 per pulse, net 0.15: k = 39 -> 19 s, just inside the 20 s fuel.
	var perceived := StimulusPropagation.falloff(SMALL_CRATE.intensity, SMALL_CRATE.radius, 1.2)

	assert_float(_seconds(perceived, SMALL_CRATE)).is_equal_approx(19.0, 0.0001)


func test_heat_below_cooling_never_ignites() -> void:
	assert_float(HeatModel.seconds_to_reach(0.25, 6.0, 0.5, 0.5)).is_equal(-1.0)
	assert_float(HeatModel.seconds_to_reach(0.0, 6.0, 0.5, 0.5)).is_equal(-1.0)


func test_cardboard_next_to_burning_crate_ignites_fast() -> void:
	# Centres 0.55 m apart: 2.0 x (1 - 0.55 / 1.5) = 1.27 per pulse, threshold 2: second pulse, 0.5 s.
	var perceived := StimulusPropagation.falloff(SMALL_CRATE.intensity, SMALL_CRATE.radius, 0.55)

	assert_float(_seconds(perceived, CARDBOARD)).is_equal_approx(0.5, 0.0001)


func test_explosion_fire_burst_ignites_within_two_metres_at_once() -> void:
	# Fire burst 20 / 3 m: 6.67 at 2 m >= small crate 6 and barrel 4, < large crate 10 (1.5 m: 10).
	var at_two := StimulusPropagation.falloff(BARREL.fire_intensity, BARREL.fire_radius, 2.0)
	var at_one_and_half := StimulusPropagation.falloff(BARREL.fire_intensity, BARREL.fire_radius, 1.5)

	assert_float(_seconds(at_two, SMALL_CRATE)).is_equal(0.0)
	assert_bool(HeatModel.new(BARREL.heat_threshold, BARREL.cool_rate).add(at_two)).is_true()
	assert_bool(HeatModel.new(LARGE_CRATE.ignition_threshold, 0.5).add(at_two)).is_false()
	assert_bool(HeatModel.new(LARGE_CRATE.ignition_threshold, 0.5).add(at_one_and_half)).is_true()


func _seconds(perceived: float, config: FlammableConfig) -> float:
	return HeatModel.seconds_to_reach(perceived, config.ignition_threshold, config.cool_rate, config.pulse_interval)
