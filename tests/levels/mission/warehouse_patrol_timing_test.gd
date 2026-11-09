extends GdUnitTestSuite
## Warehouse patrols, simulated (design/levels/mission-warehouse.md "Targets": patrols leave crossing
## gaps of at least 4 s). The level runs with its guards (no player, synchronous navigation) for
## SIMULATED seconds of game time; at each crossing point (where a player route crosses a patrol
## path) a guard "passes" while it is within PASS_RADIUS (horizontal, centre to centre, same floor).
## The gap is the time between one pass ending and the next starting; a point passed by a single
## guard repeats with that guard's lap (measured: the time between two arrivals at its first
## point), so its gaps are taken round one lap. Every crossing point must be passed (it really is
## on a route), every gap must be at least MIN_GAP (a window to cross) and at most MAX_GAP (the
## compound feels watched). The measured laps and gaps are printed for the doc's guards table.

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
const PEOPLE := "Population/People"
const TIME_FACTOR := 9.0
const TICK := 1.0 / 60.0
## Game time simulated: one lap of the longest route (the rifle guard's, about 53 s) plus margin.
const SIMULATED := 60.0
const PASS_RADIUS := 5.0
const SAME_FLOOR := 1.5
const MIN_GAP := 4.0
const MAX_GAP := 40.0
## Where player routes cross patrol paths (feet, warehouse coordinates).
const CROSSINGS: Dictionary[String, Vector3] = {
	"side door": Vector3(-21.7, 0.0, -6.0),
	"drain chamber exit": Vector3(30.6, 0.0, -7.6),
	"fire escape foot": Vector3(21.2, 0.0, 13.6),
	"back gate": Vector3(7.0, 0.0, 23.0),
	"annex roof door": Vector3(-19.25, 4.5, 2.1),
	"bridge east end": Vector3(6.5, 4.5, 6.0),
	"duct A alcove": Vector3(14.0, 4.5, -8.2),
}

var _runner: GdUnitSceneRunner
var _map: RID


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()
	if _map.is_valid():
		NavigationServer3D.map_set_use_async_iterations(_map, true)


func test_patrols_leave_crossing_gaps_of_four_to_forty_seconds() -> void:
	await GuardHelpers.let_old_scenes_go(get_tree())
	var level: Node3D = auto_free(LEVEL.instantiate())
	# No player: the Mission would spawn one and pause the game for the briefing. Guards holding a
	# post never cross a route: removed, they only cost simulation time.
	level.get_node("Mission").free()
	for guard in level.get_node(PEOPLE + "/Guards").get_children():
		if (guard.get_node("Behaviour") as AwarenessBehaviour).patrol_route.is_empty():
			guard.free()
	_runner = scene_runner(level)
	_runner.set_time_factor(TIME_FACTOR)
	var region := level.get_node("Navigation") as LevelNavigation
	_map = region.get_navigation_map()
	await GuardHelpers.use_sync_iterations(_map, region)
	GuardHelpers.isolate_region(_map, region)
	region.bake()
	await get_tree().physics_frame

	var patrols: Array[NavWalker] = []
	for guard in level.get_node(PEOPLE + "/Guards").get_children():
		if (guard.get_node("Behaviour") as AwarenessBehaviour).route != null:
			patrols.append(guard as NavWalker)
	assert_int(patrols.size()).is_equal(5)

	# Crossing -> guard -> [[start, end], ...] pass intervals; guard -> arrival times at point 0.
	var passes: Dictionary = {}
	for crossing: String in CROSSINGS:
		passes[crossing] = {}
	# Guard -> times it arrived at its first point (it starts there, waiting: time 0).
	var arrivals: Dictionary = {}
	var waiting: Dictionary = {}
	for guard in patrols:
		arrivals[guard.name] = [0.0]
		waiting[guard.name] = true
	var frames := roundi(SIMULATED / TICK)
	for frame in frames:
		await get_tree().physics_frame
		var time := frame * TICK
		for guard in patrols:
			var behaviour := guard.get_node("Behaviour") as AwarenessBehaviour
			var now_waiting := behaviour.patrol_wait > 0.0
			if now_waiting and not bool(waiting[guard.name]) and behaviour.patrol_index == 0:
				(arrivals[guard.name] as Array).append(time)
			waiting[guard.name] = now_waiting
			for crossing: String in CROSSINGS:
				if _passing(guard.global_position, CROSSINGS[crossing]):
					_extend(passes[crossing], guard.name, time)

	var report: PackedStringArray = []
	var failures: PackedStringArray = []
	var laps := {}
	for guard in patrols:
		var times: Array = arrivals[guard.name]
		assert_int(times.size()).override_failure_message("%s finished no lap" % guard.name).is_greater_equal(2)
		var lap := float(times[1]) - float(times[0])
		laps[guard.name] = lap
		report.append("%s lap %.1f s" % [guard.name, lap])
		assert_str(GradedAwareness.of_node(guard).state_name()).override_failure_message(guard.name).is_equal("unaware")
	for crossing: String in CROSSINGS:
		var by_guard: Dictionary = passes[crossing]
		if by_guard.is_empty():
			failures.append("%s: never passed" % crossing)
			continue
		var gaps := _gaps(by_guard, laps)
		var smallest: float = gaps.min() if not gaps.is_empty() else INF
		var largest: float = gaps.max() if not gaps.is_empty() else INF
		report.append(
			"%s: passed by %s, gaps %.1f .. %.1f s" % [crossing, ", ".join(by_guard.keys()), smallest, largest]
		)
		if smallest < MIN_GAP or largest > MAX_GAP:
			failures.append("%s: gaps %.1f .. %.1f s" % [crossing, smallest, largest])
	print("Patrol timing: " + "; ".join(report))
	assert_array(failures).is_empty()


func _passing(guard: Vector3, crossing: Vector3) -> bool:
	if absf(guard.y - crossing.y) > SAME_FLOOR:
		return false
	return Vector2(guard.x - crossing.x, guard.z - crossing.z).length() <= PASS_RADIUS


# Adds `time` to the guard's pass intervals: extends the current one or starts a new one.
func _extend(by_guard: Dictionary, guard: StringName, time: float) -> void:
	if not by_guard.has(guard):
		by_guard[guard] = []
	var intervals: Array = by_guard[guard]
	if not intervals.is_empty() and time - float(intervals[-1][1]) <= TICK * 1.5:
		intervals[-1][1] = time
	else:
		intervals.append([time, time])


# Gaps between passes. One guard: its passes during its first lap (from time 0), round the lap (the
# last pass of the lap to the first of the next). Several guards: between consecutive passes of any.
func _gaps(by_guard: Dictionary, laps: Dictionary) -> Array[float]:
	var gaps: Array[float] = []
	if by_guard.size() == 1:
		var guard: StringName = by_guard.keys()[0]
		var lap: float = laps[guard]
		var intervals: Array = by_guard[guard]
		var in_lap: Array = intervals.filter(func(i: Array) -> bool: return float(i[0]) < lap)
		var first: Array = in_lap[0]
		for i in range(1, in_lap.size()):
			gaps.append(float(in_lap[i][0]) - float(in_lap[i - 1][1]))
		gaps.append(float(first[0]) + lap - float(in_lap[-1][1]))
		return gaps
	var merged: Array = []
	for guard: StringName in by_guard:
		merged.append_array(by_guard[guard])
	merged.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in range(1, merged.size()):
		gaps.append(maxf(0.0, float(merged[i][0]) - float(merged[i - 1][1])))
	return gaps
