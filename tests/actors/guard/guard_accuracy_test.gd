extends GdUnitTestSuite
## Measurement (ADR 0070 survival targets, re-measured for ADR 0127): how long the player survives a
## pistol guard's fire, through the real WeaponHolder with the guard loadout's data (the pistol's own
## cone, shot bloom and kick, 70 % of it pulled back) on CombatModel's timing (guard_fire_sim.gd).
## Medians over seeded engagements; prints the table it measures (rows of ADR 0070).

const FireSim := preload("res://tests/actors/guard/guard_fire_sim.gd")
const PISTOL_GUARD := "res://actors/guard/guard_pistol.tscn"
const RUNS := 21
const TABLE_RUNS := 11
const SAMPLES := 400
const RUNNING_SPEED := 5.0

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


func test_hit_chances_crouched_far_versus_running_near() -> void:
	var lines: Array[String] = []
	var rows: Array = [
		["standing still, 15 m", 15.0, false, 0.0],
		["crouched still, 15 m", 15.0, true, 0.0],
		["running, 6 m", 6.0, false, RUNNING_SPEED],
		["running, 10 m", 10.0, false, RUNNING_SPEED],
	]
	var chance: Dictionary[String, float] = {}
	for row: Array in rows:
		await _sim.place(row[1], row[2])
		chance[row[0]] = _sim.first_shot_hit_share(SAMPLES, row[3])
		var survival := _sim.median_survival(TABLE_RUNS, row[3])
		lines.append(
			(
				"%-22s first shot hits %3d%%, median time under fire %.1f s"
				% [row[0], roundi(chance[row[0]] * 100.0), survival]
			)
		)
	print("MEASURED pistol guard:\n" + "\n".join(lines))
	assert_float(chance["crouched still, 15 m"]).is_less(chance["running, 6 m"] - 0.2)
