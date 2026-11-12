extends GdUnitTestSuite
## Measurement (ADR 0070 rows, re-measured for ADR 0127): the pistol guard's first-shot hit share and
## median time under fire at 15 m (standing, crouched) and running at 6 and 10 m, through the real
## WeaponHolder (guard_fire_sim.gd); prints the table. Split from guard_accuracy_test.gd (time budget).

const FireSim := preload("res://tests/actors/guard/guard_fire_sim.gd")
const PISTOL_GUARD := "res://actors/guard/guard_pistol.tscn"
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
