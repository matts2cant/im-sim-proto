extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Routes covered by tests", ghost route A): the real player,
## starting kit only, through the populated warehouse with its guards at work, from PlayerSpawn
## over the north-west fence, up the annex chain to the roof, down duct B into the manager office
## (the manifest), back up the duct, down the fire escape and out of the back gate (it opens from
## inside) to the boat. Ends with the Ghost and Pacifist badges.
## Three segments, one per test, in order: each continues the level state the previous one saved
## (WarehouseRouteDriver.snapshot(), restored as a quickload restores it), so the badges at the
## extraction count the whole route. The guard waits are conditions on their patrols, not times.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const MANIFEST := "Population/Security/Items/ManifestDatapad"
const BACK_GATE := "Population/Security/Doors/BackGate"
const G2 := "G2YardPatrolWest"
const G9 := "G9BackStrip"

var _route: Route
## The level state at the end of the last segment.
var _saved: Dictionary = {}


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()


func after_test() -> void:
	_route.teardown()
	StimulusSystem.clear()


func test_1_over_the_fence_and_up_the_annex_chain_unseen() -> void:
	_saved = {}
	await _route.setup(scene_runner(Route.fixture(self)))
	# Road -> pallets (1.2) -> outside container (1.3) -> hop the fence onto the inside container.
	var ok := await _route.go([Vector3(-29, 0, -31)])
	ok = ok and await _route.climb_from(Vector3(-29, 0, -29.5), Route.SOUTH, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29, 1.2, -28.2), Route.SOUTH, 2.5)
	ok = ok and await _route.climb_from(Vector3(-29, 2.5, -25.7), Route.SOUTH, 2.5, 45)
	# Down the inside pallets into the dark corner, then along the dark west strip of the yard.
	ok = ok and await _route.go([Vector3(-29, 0, -20.6)], Route.Stance.CROUCH)
	ok = ok and await _route.sneak([Vector3(-33, 0, -20), Vector3(-33.5, 0, -2)], 8.0)
	# G2 walks past the annex chain's foot from B to C and back to D: climb once it has left D for A.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.patrol_target(G2) == "YardWestA", 60.0, "G2 to leave for A"
		)
	)
	ok = ok and await _route.sneak([Vector3(-33, 0, 3), Vector3(-31.6, 0, 6)], 8.0)
	# Pallets (1.2) -> container (1.3) -> crate (1.1) -> annex roof (1.15).
	ok = ok and await _route.climb_from(Vector3(-30.8, 0, 6), Route.EAST, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29.6, 1.2, 6), Route.EAST, 2.5)
	ok = ok and await _route.climb_from(Vector3(-28.4, 2.5, 6), Route.EAST, 3.6)
	ok = ok and await _route.climb_from(Vector3(-27.2, 3.6, 6), Route.EAST, 4.75)
	ok = ok and await _route.go([Vector3(-23.5, 4.75, 7)], Route.Stance.CROUCH)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_2_roof_and_duct_b_to_the_manifest() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	# Annex stair to the roof, east across the roof between the skylights, into duct B's mouth.
	ok = ok and await _route.go([Vector3(-23.5, 4.75, 12.3), Vector3(-21.25, 4.75, 12.3), Vector3(-21.25, 9.5, 3.0)])
	ok = (
		ok
		and await _route.go(
			[
				Vector3(-18.5, 9.5, 3.0),
				Vector3(-16.5, 9.5, 0.5),
				Vector3(8, 9.5, 0.5),
				Vector3(10.2, 9.5, -7.6),
				Vector3(11, 9.5, -7.2)
			]
		)
	)
	# Crawl down the duct and through the hatch onto the filing cabinet, then to the desk.
	ok = ok and await _route.go([Vector3(11, 9.7, -5.0), Vector3(11, 7.6, 2.8)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.player.global_position.y < 6.5, 3.0, "drop onto the cabinet"
		)
	)
	ok = ok and await _route.go([Vector3(11, 4.5, 4.2), Vector3(9.3, 4.5, 2.0)], Route.Stance.CROUCH)
	ok = ok and await _route.hands.read(MANIFEST)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tracker.main_done()).override_failure_message(_route.report()).is_true()
	assert_bool(_route.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_3_back_up_the_duct_down_the_fire_escape_and_out_of_the_back_gate() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	# Back up duct B: the cabinet (1.6), then the hatch (1.45, its lip), crawl up to the roof mouth.
	ok = ok and await _route.climb_from(Vector3(11, 4.5, 4.1), Route.NORTH, 6.1)
	ok = ok and await _route.go([Vector3(11, 6.1, 2.65)], Route.Stance.CROUCH)
	ok = ok and await _route.climb(Route.NORTH, 7.55)
	ok = (
		ok
		and await _route.go(
			[Vector3(11, 7.6, -1.0), Vector3(11, 9.7, -5.6), Vector3(11, 9.5, -7.0)], Route.Stance.CROUCH
		)
	)
	# Across the roof to the fire escape's landing (the east parapet's gap).
	ok = ok and await _route.go([Vector3(18.5, 9.5, -3.9), Vector3(21.2, 9.5, -3.9)])
	# G9 turns at the fire escape's foot: go down once it walks back west, past the back gate's east.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool:
				return _route.patrol_target(G9) == "BackStripA" and _route.guard(G9).global_position.x < 12.0,
			60.0,
			"G9 to head west"
		)
	)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(21.2, 4.5, 5.6), Vector3(21.2, 4.5, 7.0), Vector3(21.2, 1.44, 12.7), Vector3(21.2, 0, 14.8)]
		)
	)
	# Behind G9 along the back strip; the back gate opens from inside.
	ok = ok and await _route.sneak([Vector3(14, 0, 18.5), Vector3(6.6, 0, 23.6)], 8.0)
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
