extends GdUnitTestSuite
## Measurement (ADR 0070 survival targets, re-measured for ADR 0127): how long the player survives a
## pistol guard's fire, through the real WeaponHolder with the guard loadout's data (the pistol's own
## cone, shot bloom and kick, 70 % of it pulled back) on CombatModel's timing (guard_fire_sim.gd).
## Medians over seeded engagements. The other rows of ADR 0070: guard_accuracy_table_test.gd.

const FireSim := preload("res://tests/actors/guard/guard_fire_sim.gd")
const PISTOL_GUARD := "res://actors/guard/guard_pistol.tscn"
const RUNS := 21

var _sim: FireSim


func before_test() -> void:
	StimulusSystem.clear()
	_sim = FireSim.new(self, PISTOL_GUARD)


func after_test() -> void:
	_sim.root.queue_free()
	StimulusSystem.clear()


func test_a_standing_player_survives_three_seconds_at_10m_and_about_two_at_4m() -> void:
	await _sim.place(4.0, false)
	var at_4 := _sim.median_survival(RUNS)
	await _sim.place(10.0, false)
	var at_10 := _sim.median_survival(RUNS)
	print("MEASURED pistol guard vs a standing player, median time under fire: 4 m %.2f s, 10 m %.2f s" % [at_4, at_10])
	assert_float(at_10).is_greater_equal(3.0)
	assert_float(at_4).is_between(1.5, 2.8)
