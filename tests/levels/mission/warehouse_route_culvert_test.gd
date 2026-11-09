extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Routes covered by tests", ghost route B): the real
## player, starting kit only, with the guards at work: east along the road, down the ditch, through
## the culvert into the drain chamber, out of it once the east yard patrol has walked north, across
## the dark east strip and up the fire escape to the roof, down duct B to the manifest and back up,
## west across the roof and down the annex stair and the annex chain into the west yard, round the
## back strip behind its patrol and out of the back gate to the boat. Ends with the Ghost and
## Pacifist badges.
## Three segments, one per test, in order: each continues the level state the previous one saved
## (WarehouseRouteDriver.snapshot()), so the badges at the extraction count the whole route.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const Roof := preload("res://tests/levels/mission/warehouse_route_roof.gd")
const MANIFEST := "Population/Security/Items/ManifestDatapad"
const BACK_GATE := "Population/Security/Doors/BackGate"
const G2 := "G2YardPatrolWest"
const G3 := "G3YardPatrolEast"
const G9 := "G9BackStrip"
const CHAMBER_EXIT := Vector3(30.6, 0, -7.6)

var _route: Route
var _saved: Dictionary = {}


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()


func after_test() -> void:
	_route.teardown()
	StimulusSystem.clear()


func test_1_ditch_culvert_and_fire_escape_to_the_roof() -> void:
	_saved = {}
	await _route.setup(scene_runner(Route.fixture(self)))
	# East along the road to the ditch's ramp, down it and south to the culvert's mouth.
	var ok := await _route.go(
		[
			Vector3(0, 0, -31),
			Vector3(39, 0, -30),
			Vector3(39, 0, -28),
			Vector3(39, -2.4, -20),
			Vector3(38.0, -2.4, -7.6)
		]
	)
	# Crawl west through the culvert into the drain chamber.
	ok = ok and await _route.go([Vector3(33.4, -2.4, -7.6)], Route.Stance.CROUCH)
	# Out of the chamber (two 1.2 m steps) once G3 has left its exit for the yard's north end.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool:
				return (
					_route.patrol_target(G3) == "YardEastA"
					and _route.guard(G3).global_position.distance_to(CHAMBER_EXIT) > 9.0
				),
			60.0,
			"G3 to leave the drain chamber"
		)
	)
	ok = ok and await _route.climb_from(Vector3(32.8, -2.4, -7.6), Route.WEST, -1.2)
	ok = ok and await _route.climb_from(Vector3(31.6, -1.2, -7.6), Route.WEST, 0.0)
	# South along the dark east strip behind the fire-escape container.
	ok = ok and await _route.sneak([Vector3(32.5, 0, 0), Vector3(31, 0, 12.5), Vector3(24.5, 0, 14.5)])
	# Up the fire escape (its bottom landing is mantled: 1.44) while G9 is away west.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.guard(G9).global_position.x < 10.0, 60.0, "G9 to be west of the back gate"
		)
	)
	ok = ok and await _route.sneak([Vector3(21.2, 0, 14.6)])
	ok = ok and await _route.climb_from(Vector3(21.2, 0, 13.95), Route.NORTH, 1.44)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(21.2, 1.44, 12.3), Vector3(21.2, 4.5, 7.0), Vector3(21.2, 4.5, 5.6), Vector3(21.2, 9.5, -3.9)]
		)
	)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tally.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_2_duct_b_to_the_manifest_and_back_to_the_annex_roof() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var roof := _route.raised.size()
	# Crouched under the high beam across the east parapet's gap (ADR 0097), into the dark east of
	# duct B's housing; across the lit forecourt once the roof camera and G4 look away from it.
	ok = ok and await _route.go([Vector3(18.5, 9.5, -3.9)], Route.Stance.CROUCH)
	ok = ok and await _route.go([Vector3(14.5, 9.5, -4.5)])
	ok = ok and await Roof.wait_for_forecourt(_route)
	ok = ok and await _route.go([Vector3(12.5, 9.5, -7.6), Vector3(11, 9.5, -7.2)])
	# Down the duct onto the cabinet and to the desk.
	ok = ok and await _route.go([Vector3(11, 9.7, -5.0)], Route.Stance.CROUCH)
	_assert_roof_unseen(roof)
	ok = ok and await _route.go([Vector3(11, 7.6, 2.8)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.player.global_position.y < 6.5, 3.0, "drop onto the cabinet"
		)
	)
	ok = ok and await _route.go([Vector3(11, 4.5, 4.2), Vector3(9.3, 4.5, 2.0)], Route.Stance.CROUCH)
	ok = ok and await _route.hands.read(MANIFEST)
	# Back up the duct, west across the roof between the skylights, down the annex stair.
	ok = ok and await _route.climb_from(Vector3(11, 4.5, 4.1), Route.NORTH, 6.1)
	ok = ok and await _route.go([Vector3(11, 6.1, 2.65)], Route.Stance.CROUCH)
	ok = ok and await _route.climb(Route.NORTH, 7.55)
	ok = ok and await _route.go([Vector3(11, 7.6, -1.0), Vector3(11, 9.6, -4.4)], Route.Stance.CROUCH)
	# Out into the forecourt once the camera and G4 look away, west round the duct's housing into the dark,
	# across the roof and crouched under the west gap's beam onto the annex stair's landing.
	roof = _route.raised.size()
	ok = ok and await Roof.wait_for_forecourt(_route)
	ok = ok and await _route.go([Vector3(11, 9.5, -7.0), Vector3(9.6, 9.5, -6.6)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.go(
			[Vector3(9.4, 9.5, -3.0), Vector3(8, 9.5, 0.5), Vector3(-16.5, 9.5, 0.5), Vector3(-18.5, 9.5, 3.0)]
		)
	)
	ok = ok and await _route.go([Vector3(-21.25, 9.5, 3.0)], Route.Stance.CROUCH)
	_assert_roof_unseen(roof)
	ok = ok and await _route.go([Vector3(-21.25, 4.75, 12.3), Vector3(-23.5, 4.75, 12.3), Vector3(-23.5, 4.75, 7)])

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tracker.main_done()).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tally.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_3_down_the_annex_chain_round_the_back_strip_and_out_of_the_back_gate() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	# Down the annex chain (drops of 1.15, 1.1, 1.3 and 1.2 m) once G2 has left the annex for the
	# yard's north end.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.patrol_target(G2) == "YardWestA", 60.0, "G2 to leave for A"
		)
	)
	ok = ok and await _route.go([Vector3(-26.4, 4.75, 6), Vector3(-31.6, 0, 6)], Route.Stance.CROUCH)
	# South along the dark west strip to the back strip, then east behind G9 once it walks east.
	ok = ok and await _route.sneak([Vector3(-32.5, 0, 15), Vector3(-31, 0, 17.5)], 8.0)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool:
				return _route.patrol_target(G9) == "BackStripB" and _route.guard(G9).global_position.x > 9.0,
			60.0,
			"G9 to pass the back gate east"
		)
	)
	ok = ok and await _route.sneak([Vector3(-22, 0, 17.5), Vector3(-2, 0, 18.5), Vector3(6.6, 0, 23.6)], 8.0)
	ok = ok and await _route.hands.use_door(BACK_GATE)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.hands.door(BACK_GATE).is_open(), 5.0, "the back gate to open"
		)
	)
	ok = ok and await _route.go([Vector3(7, 0, 28), Vector3(7, 0, 33)])
	ok = ok and await _route.extract(Vector3(7, 0, 35.6))

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	var results := _route.mission.results()
	assert_bool(results["ghost"]).override_failure_message(_route.report()).is_true()
	assert_bool(results["pacifist"]).override_failure_message(_route.report()).is_true()
	assert_int(results["alarms"]).is_equal(0)
	assert_int(results["kills"] + results["knockouts"]).is_equal(0)


# No guard's awareness rose above Unaware and no alarm rang since `mark` (the size of the driver's
# `raised` at the start of a roof stretch): the roof crossing went unnoticed.
func _assert_roof_unseen(mark: int) -> void:
	var risen := Array(_route.raised.slice(mark))
	assert_array(risen).override_failure_message("noticed on the roof:\n" + _route.report()).is_empty()
	assert_int(_route.mission.tally.alarms).override_failure_message(_route.report()).is_equal(0)
