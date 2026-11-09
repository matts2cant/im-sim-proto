extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Routes covered by tests", loud route): the real
## player, starting kit only (the loud pistol, 10 + 10 rounds), with the guards at work: shoots the
## gate guard through the grille from the road, opens the gate and steps into the gate camera's view
## (the alarm: both controllers ring, every guard searches), runs back west along the dark road and
## up the outside containers, out of reach, and shoots the guards that come close while the sirens
## ring and the two reinforcements arrive (30 s after the alarm). Then over the fence and up the
## annex chain to the roof while the guards search the gate lane, one round down through the dock's
## west skylight blows up the shipment's fuel drum (optional objective), duct B to the manifest,
## back up and down the fire escape once the guards have left the back strip, out of the back gate
## to the boat: alarms, kills, no Ghost, no Pacifist, one optional objective.
## Segments, one per test, in order: each continues the level state the previous one saved
## (WarehouseRouteDriver.snapshot()). Fixed seeds for every guard, weapon and the debris.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const FRONT_GATE := "Population/Security/Doors/FrontGate"
const G1 := "G1GatePost"
const DRUM := "Population/People/Shipment/FuelDrum"
const BACK_GATE := "Population/Security/Doors/BackGate"
const MANIFEST := "Population/Security/Items/ManifestDatapad"

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


func test_1_front_gate_alarm_and_reinforcements() -> void:
	_saved = {}
	await _route.setup(scene_runner(Route.fixture(self)))
	var hands := _route.hands
	var g1 := _route.guard(G1)
	var ok := await hands.draw(&"pistol")
	ok = ok and await _route.go([Vector3(-12, 0, -30), _clear_spot(g1)])
	ok = ok and await hands.shoot_down(g1)
	ok = ok and await hands.use_door(FRONT_GATE)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(FRONT_GATE).is_open(), 5.0, "the front gate to open"
		)
	)
	# Into the lit lane: the gate camera rings both controllers.
	var mission := _route.mission
	ok = ok and await _route.go([Vector3(-6, 0, -23.5)])
	ok = ok and await _route.wait_until(func() -> bool: return mission.alarm_time >= 0.0, 5.0, "the alarm")
	# Out again and west along the dark road to the containers, up out of reach, and hold there.
	ok = ok and await _route.go([Vector3(-6, 0, -28), Vector3(-26, 0, -31), Vector3(-29, 0, -31)], Route.Stance.SPRINT)
	ok = ok and await _route.climb_from(Vector3(-29, 0, -29.5), Route.SOUTH, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29, 1.2, -28.2), Route.SOUTH, 2.5)
	ok = ok and await _route.go([Vector3(-29, 2.5, -26.6)])
	ok = (
		ok
		and await hands.fight(
			func() -> bool: return mission.reinforcements_sent and mission.time - mission.alarm_time > 33.0, 60.0, 15.0
		)
	)
	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_int(mission.tally.alarms).is_greater(0)
	assert_bool(mission.reinforcements_sent).is_true()
	assert_bool(ActorState.can_act(_route.player)).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_2_over_the_fence_to_the_roof_the_shipment_through_a_skylight_and_the_manifest() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var hands := _route.hands
	# Over the fence and up the annex chain while the guards search the gate lane.
	ok = ok and await _route.climb_from(Vector3(-29, 2.5, -25.7), Route.SOUTH, 2.5, 45)
	ok = ok and await _route.go([Vector3(-29, 0, -20.6)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(-33, 0, -20), Vector3(-33.5, 0, -2), Vector3(-33, 0, 3), Vector3(-31.6, 0, 6)], 8.0
		)
	)
	ok = ok and await _route.climb_from(Vector3(-30.8, 0, 6), Route.EAST, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29.6, 1.2, 6), Route.EAST, 2.5)
	ok = ok and await _route.climb_from(Vector3(-28.4, 2.5, 6), Route.EAST, 3.6)
	ok = ok and await _route.climb_from(Vector3(-27.2, 3.6, 6), Route.EAST, 4.75)
	ok = (
		ok
		and await _route.go(
			[
				Vector3(-23.5, 4.75, 7),
				Vector3(-23.5, 4.75, 12.3),
				Vector3(-21.25, 4.75, 12.3),
				Vector3(-21.25, 9.5, 3.0)
			]
		)
	)
	# The fuel drum stands east of the dock's west skylight: one round from its west railing, over
	# the top rail and down through the hole.
	var drum := _route.level.get_node(DRUM) as Node3D
	var spots: Array[Vector3] = []
	for i in 6:
		for j in 11:
			spots.append(Vector3(-9.66 - i * 0.05, 9.5, -7.2 + j * 0.2))
	var spot := hands.shooting_spot(spots, drum, drum.global_position)
	ok = ok and await _route.go([Vector3(-18.5, 9.5, 3.0), Vector3(-16.5, 9.5, 0.5), Vector3(-10.5, 9.5, -3.5), spot])
	ok = ok and await hands.shoot_at(drum, drum.global_position)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.mission.tracker.optional_done() > 0, 3.0, "the shipment sabotaged"
		)
	)
	# Duct B down into the manager office.
	ok = (
		ok
		and await _route.go(
			[Vector3(-10.5, 9.5, -3.5), Vector3(6.5, 9.5, -3.5), Vector3(10.2, 9.5, -7.6), Vector3(11, 9.5, -7.2)]
		)
	)
	ok = ok and await _route.go([Vector3(11, 9.7, -5.0), Vector3(11, 7.6, 2.8)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.player.global_position.y < 6.5, 3.0, "drop onto the cabinet"
		)
	)
	ok = ok and await _route.go([Vector3(11, 4.5, 4.2), Vector3(9.3, 4.5, 2.0)], Route.Stance.CROUCH)
	ok = ok and await hands.read(MANIFEST)
	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tracker.main_done()).is_true()
	assert_bool(ActorState.can_act(_route.player)).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_3_back_up_the_duct_down_the_fire_escape_and_out_to_the_boat() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var hands := _route.hands
	ok = ok and await _route.climb_from(Vector3(11, 4.5, 4.1), Route.NORTH, 6.1)
	ok = ok and await _route.go([Vector3(11, 6.1, 2.65)], Route.Stance.CROUCH)
	ok = ok and await _route.climb(Route.NORTH, 7.55)
	ok = (
		ok
		and await _route.go(
			[Vector3(11, 7.6, -1.0), Vector3(11, 9.7, -5.6), Vector3(11, 9.5, -7.0)], Route.Stance.CROUCH
		)
	)
	ok = ok and await _route.go([Vector3(18.5, 9.5, -3.9), Vector3(21.2, 9.5, -3.9)])
	# The guards still search: down once none stands near the fire escape or the back strip.
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _clear_of_guards([Vector3(21.2, 0, 12), Vector3(10, 0, 20)], 14.0),
			60.0,
			"the back strip to clear"
		)
	)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(21.2, 4.5, 5.6), Vector3(21.2, 4.5, 7.0), Vector3(21.2, 1.44, 12.7), Vector3(21.2, 0, 14.8)]
		)
	)
	ok = ok and await _route.sneak([Vector3(14, 0, 18.5), Vector3(6.6, 0, 23.6)], 8.0)
	ok = ok and await hands.use_door(BACK_GATE)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(BACK_GATE).is_open(), 5.0, "the back gate to open"
		)
	)
	ok = ok and await _route.go([Vector3(7, 0, 28), Vector3(7, 0, 33)])
	ok = ok and await _route.extract(Vector3(7, 0, 35.6))

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	var results := _route.mission.results()
	assert_int(results["alarms"]).is_greater(0)
	assert_int(results["kills"]).is_greater(0)
	assert_int(results["optional_done"]).is_equal(1)
	assert_bool(results["ghost"]).is_false()
	assert_bool(results["pacifist"]).is_false()
	assert_bool(_route.mission.reinforcements_sent).is_true()


# True when no guard that can act stands within `radius` (horizontal) of any of `points`.
func _clear_of_guards(points: Array[Vector3], radius: float) -> bool:
	for node in _route.guards():
		var guard := node as Node3D
		if not ActorState.can_act(guard):
			continue
		for point in points:
			if Vector2(guard.global_position.x - point.x, guard.global_position.z - point.z).length() < radius:
				return false
	return true


# Spots on the road north of the gate, nearest to the gate's middle first: one of them sees `guard`'s
# head between the bars.
func _clear_spot(guard: Node3D) -> Vector3:
	var spots: Array[Vector3] = []
	for step in 100:
		var offset := (step / 2) * 0.05 * (1.0 if step % 2 == 0 else -1.0)
		spots.append(Vector3(-6.5 + offset, 0, -27.6))
	return _route.hands.shooting_spot(spots, guard, Route.Hands.head_of(guard))
