extends GdUnitTestSuite
## Measurement (ADR 0127): the survival targets of ADR 0070 against a rifle guard (bursts at the
## assault rifle's cycle, its cone, bloom and recoil pattern, 70 % of the climb pulled back), through
## guard_fire_sim.gd. Medians over seeded engagements; prints the table. The SMG guard:
## guard_smg_accuracy_test.gd.

const FireSim := preload("res://tests/actors/guard/guard_fire_sim.gd")
const RIFLE_GUARD := "res://actors/guard/guard_rifle.tscn"
const RUNS := 15
const TABLE_RUNS := 9

var _sim: FireSim


func before_test() -> void:
	StimulusSystem.clear()
	_sim = FireSim.new(self, RIFLE_GUARD)


func after_test() -> void:
	_sim.root.queue_free()
	StimulusSystem.clear()


func test_a_standing_player_survives_a_rifle_guard_three_seconds_at_10m() -> void:
	var times := await _sim.survival_table(RUNS, TABLE_RUNS)
	assert_float(times[1]).is_greater_equal(3.0)
	assert_float(times[0]).is_between(1.5, 3.5)
