extends GdUnitTestSuite
## Measurement (ADR 0127): the survival targets of ADR 0070 against guards with automatic weapons
## (the assault rifle and the submachine gun: bursts at the weapon's cycle, its cone, bloom and
## recoil pattern, 70 % of the climb pulled back), through guard_fire_sim.gd. Medians over seeded
## engagements; prints what it measures.

const FireSim := preload("res://tests/actors/guard/guard_fire_sim.gd")
const RIFLE_GUARD := "res://actors/guard/guard_rifle.tscn"
const SMG_GUARD := "res://actors/guard/guard_smg.tscn"
const RUNS := 15
const TABLE_RUNS := 9
const RUNNING_SPEED := 5.0

var _sim: FireSim


func before_test() -> void:
	StimulusSystem.clear()


func after_test() -> void:
	if _sim != null:
		_sim.root.queue_free()
	StimulusSystem.clear()


func test_a_standing_player_survives_a_rifle_guard_three_seconds_at_10m() -> void:
	var times := await _measure(RIFLE_GUARD)
	assert_float(times[1]).is_greater_equal(3.0)
	assert_float(times[0]).is_between(1.5, 3.5)


func test_a_standing_player_survives_an_smg_guard_three_seconds_at_10m() -> void:
	var times := await _measure(SMG_GUARD)
	assert_float(times[1]).is_greater_equal(3.0)
	assert_float(times[0]).is_between(1.5, 3.5)


# Median survival at 4 m and 10 m (standing still), then the other rows printed.
func _measure(guard_scene: String) -> Array[float]:
	_sim = FireSim.new(self, guard_scene)
	var times: Array[float] = []
	for distance: float in [4.0, 10.0]:
		await _sim.place(distance, false)
		times.append(_sim.median_survival(RUNS))
	var lines: Array[String] = ["standing still, 4 m: %.2f s" % times[0], "standing still, 10 m: %.2f s" % times[1]]
	var rows: Array = [
		["standing still, 15 m", 15.0, false, 0.0],
		["crouched still, 15 m", 15.0, true, 0.0],
		["running, 6 m", 6.0, false, RUNNING_SPEED],
		["running, 10 m", 10.0, false, RUNNING_SPEED],
	]
	for row: Array in rows:
		await _sim.place(row[1], row[2])
		lines.append("%s: %.1f s" % [row[0], _sim.median_survival(TABLE_RUNS, row[3])])
	print("MEASURED %s, median time under fire:\n%s" % [_sim.weapon.id, "\n".join(lines)])
	return times
