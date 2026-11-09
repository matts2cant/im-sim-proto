extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Roof security", ADR 0097; M9g playtest: "I was able
## to rush directly to the roof jumping on crates and drop into the office ... all in 1:30"): the
## real player, starting kit only, guards at work, sprints from PlayerSpawn the fastest crate climb
## to the roof: over the north-west fence on the pallets and containers, down the dark west strip,
## up the annex chain (pallets, container, crate) and the annex stair, upright through the west
## gap's beam and across the roof into duct B's mouth, without stopping or looking. The roof's
## security rings the alarm: the beam reports to both controllers.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const SPRINT := Route.Stance.SPRINT

var _route: Route


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()


func after_test() -> void:
	_route.teardown()
	StimulusSystem.clear()


func test_rushing_the_annex_chain_to_duct_b_rings_the_alarm() -> void:
	await _route.setup(scene_runner(Route.fixture(self)))
	var tripped: Array[EventLogEntry] = []
	var detected: Array[EventLogEntry] = []
	var collect := func(entry: EventLogEntry) -> void:
		if entry.kind == &"laser.tripped":
			tripped.append(entry)
		elif entry.kind == &"camera.detected":
			detected.append(entry)
	EventLog.entry_added.connect(collect)
	# Road -> pallets (1.2) -> outside container (1.3) -> hop the fence onto the inside container.
	var ok := await _route.go([Vector3(-29, 0, -31)], SPRINT)
	ok = ok and await _route.climb_from(Vector3(-29, 0, -29.5), Route.SOUTH, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29, 1.2, -28.2), Route.SOUTH, 2.5)
	ok = ok and await _route.climb_from(Vector3(-29, 2.5, -25.7), Route.SOUTH, 2.5, 45)
	# Off the inside container's pallets and south along the west strip, west of the yard containers.
	ok = ok and await _route.go([Vector3(-29, 0, -20.6), Vector3(-32.2, 0, -19), Vector3(-32.2, 0, 6)], SPRINT)
	# Pallets (1.2) -> container (1.3) -> crate (1.1) -> annex roof (1.15) -> annex stair -> roof.
	ok = ok and await _route.climb_from(Vector3(-30.8, 0, 6), Route.EAST, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29.6, 1.2, 6), Route.EAST, 2.5)
	ok = ok and await _route.climb_from(Vector3(-28.4, 2.5, 6), Route.EAST, 3.6)
	ok = ok and await _route.climb_from(Vector3(-27.2, 3.6, 6), Route.EAST, 4.75)
	ok = (
		ok
		and await _route.go(
			[Vector3(-22.6, 4.75, 12.3), Vector3(-21.25, 4.75, 12.3), Vector3(-21.25, 9.5, 3.0)], SPRINT
		)
	)
	# Upright through the gap and straight across the roof to duct B's mouth, then in.
	var on_roof := _route.mission.time
	ok = (
		ok
		and await _route.go(
			[Vector3(-18.5, 9.5, 3.0), Vector3(-16.5, 9.5, 0.5), Vector3(8, 9.5, 0.5), Vector3(10.2, 9.5, -7.6)], SPRINT
		)
	)
	ok = ok and await _route.go([Vector3(11, 9.5, -7.2)])
	ok = ok and await _route.go([Vector3(11, 9.7, -5.0)], Route.Stance.CROUCH)
	var at_duct := _route.mission.time
	await _route.frames(30)
	EventLog.entry_added.disconnect(collect)
	var report := (
		"roof at %.1f s, duct B at %.1f s, laser trips %s, camera detections %s\n%s"
		% [
			on_roof,
			at_duct,
			tripped.map(func(e: EventLogEntry) -> Dictionary: return e.data),
			detected.size(),
			_route.report()
		]
	)
	print("rush: ", report.get_slice("\n", 0))

	assert_bool(ok).override_failure_message(report).is_true()
	# The west gap's beam caught the player and both controllers heard it: the alarm rang.
	assert_array(tripped).override_failure_message(report).is_not_empty()
	assert_str(String(tripped[0].data["laser"])).is_equal("LaserRoofWest")
	assert_str(String(tripped[0].data["by"])).is_equal("Player")
	assert_int(int(tripped[0].data["controllers"])).is_equal(2)
	assert_int(_route.mission.tally.alarms).override_failure_message(report).is_greater(0)
	assert_bool(_route.mission.tally.ghost()).is_false()
