extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Routes covered by tests", the vault route): the
## real player, starting kit only, with the guards at work. Starts in the manager office (arranged:
## the ways in are the fence and culvert suites'), reads the manifest and the console audit, back up
## duct B, down the fire escape and into the drain chamber between two patrols, the service tunnel
## to the boiler room, up duct C into the security room; knocks the operator out from behind with
## the baton (between two glances) and carries him out of the window's sight; logs in at the console
## with the audit's credentials, disables the vault turret and the office camera and opens the vault
## door (the systems chain); out of the security room (its lock's free side), up the office stair,
## knocks the vault guard out from behind as he glances away, carries him into the vault and takes
## the prototype (optional objective); out of the fire escape door (its free side), down and out of
## the back gate to the boat. Ends with Ghost and Pacifist: two knockouts, both bodies out of sight.
## Segments, one per test, in order: each continues the level state the previous one saved
## (WarehouseRouteDriver.snapshot()).

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const Roof := preload("res://tests/levels/mission/warehouse_route_roof.gd")
const MANIFEST := "Population/Security/Items/ManifestDatapad"
const AUDIT := "Population/Security/Items/ConsoleAudit"
const CONSOLE := "Population/Security/Devices/SecurityConsole"
const TURRET := "Population/Security/Devices/VaultTurret"
const CAMERA_OFFICE := "Population/Security/Devices/CameraOffice"
const VAULT_DOOR := "Population/Security/Doors/VaultDoor"
const BOILER_TUNNEL := "Population/Security/Doors/BoilerTunnel"
const SECURITY_DOOR := "Population/Security/Doors/SecurityDoor"
const STAIRS_GROUND := "Population/Security/Doors/StairsGround"
const STAIRS_UPPER := "Population/Security/Doors/StairsUpper"
const PROTOTYPE := "Population/People/Items/Prototype"
const FIRE_ESCAPE_DOOR := "Population/Security/Doors/FireEscapeDoor"
const BACK_GATE := "Population/Security/Doors/BackGate"
const G3 := "G3YardPatrolEast"
const G7 := "G7VaultDoor"
const G9 := "G9BackStrip"
const G5 := "G5SecurityOperator"

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


func test_1_office_down_the_fire_escape_and_the_tunnel_to_the_boiler_room() -> void:
	_saved = {}
	await _route.setup(scene_runner(Route.fixture(self)))
	var hands := _route.hands
	await _route.place(Vector3(9.4, 4.5, 2.2), Route.NORTH)
	var ok := await hands.read(MANIFEST)
	ok = ok and await hands.read(AUDIT)
	# Back up duct B to the roof, across to duct A's roof mouth.
	ok = ok and await _route.climb_from(Vector3(11, 4.5, 4.1), Route.NORTH, 6.1)
	ok = ok and await _route.go([Vector3(11, 6.1, 2.65)], Route.Stance.CROUCH)
	ok = ok and await _route.climb(Route.NORTH, 7.55)
	ok = ok and await _route.go([Vector3(11, 7.6, -1.0), Vector3(11, 9.6, -4.4)], Route.Stance.CROUCH)
	# Out of the mouth once the roof camera and G4 look away from the lit forecourt, east into the dark and
	# crouched under the east gap's beam onto the fire escape (ADR 0097).
	ok = ok and await Roof.wait_for_forecourt(_route)
	ok = ok and await _route.go([Vector3(11, 9.5, -7.0)], Route.Stance.CROUCH)
	ok = ok and await _route.go([Vector3(14.5, 9.5, -4.5), Vector3(18.5, 9.5, -3.9)])
	ok = ok and await _route.go([Vector3(21.2, 9.5, -3.9)], Route.Stance.CROUCH)
	# Down the fire escape once G9 has turned back west, past the back gate.
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
	# North along the dark east strip behind the fire-escape container, into the drain chamber once
	# G3 has left its exit for the yard's north end.
	ok = ok and await _route.sneak([Vector3(23.5, 0, 13), Vector3(31, 0, 12.5), Vector3(32.5, 0, 0)])
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool:
				return (
					_route.patrol_target(G3) == "YardEastA"
					and _route.guard(G3).global_position.distance_to(Vector3(30.6, 0, -7.6)) > 9.0
				),
			60.0,
			"G3 to leave the drain chamber"
		)
	)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(32.5, 0, -5.5), Vector3(31.6, 0, -7.6), Vector3(32.6, -2.4, -7.6), Vector3(33.2, -2.4, -6.6)]
		)
	)
	# The tunnel west to the boiler room.
	ok = ok and await _route.go([Vector3(33.2, -2.4, -5.0), Vector3(21.2, -4, -5.0)])
	ok = ok and await hands.use_door(BOILER_TUNNEL)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(BOILER_TUNNEL).is_open(), 3.0, "the boiler room door to open"
		)
	)
	ok = (
		ok
		and await _route.go(
			[Vector3(18.5, -4, -5.0), Vector3(15.0, -4, -5.0), Vector3(12.3, -4, -6.0), Vector3(12.3, -4, -8.3)]
		)
	)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tally.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_2_duct_c_the_operator_knocked_out_and_hidden_and_the_console() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var hands := _route.hands
	# Duct C: mantle into its mouth facing east, crawl to the turn, then south up to the security room.
	ok = ok and await _route.climb_from(Vector3(12.7, -4, -8.3), Route.EAST, -2.9)
	ok = ok and await _route.go([Vector3(14.9, -2.9, -8.3), Vector3(14.9, -0.4, -1.0)], Route.Stance.CROUCH)
	# Out of the duct and behind the operator between two glances: the baton from behind.
	ok = ok and await hands.draw(&"baton")
	ok = ok and await _route.glance_over(G5)
	ok = (
		ok
		and await _route.go([Vector3(14.9, 0, 0.9), Vector3(15.2, 0, 2.9), Vector3(17.5, 0, 2.75)], Route.Stance.CROUCH)
	)
	var g5 := _route.guard(G5)
	await hands.swing_at(g5)
	ok = ok and await _route.wait_until(func() -> bool: return not ActorState.can_act(g5), 2.0, "G5 down")
	# Carry him out of the window's sight, along the room's south wall.
	ok = ok and await hands.carry(g5)
	ok = ok and await _route.go([Vector3(14.8, 0, 4.2)])
	ok = ok and await hands.put_down(Route.EAST)
	# The console, with the manager's audit credentials: the turret and the office camera off, the
	# vault door open.
	ok = ok and await _route.go([Vector3(16.05, 0, 1.6)])
	ok = (
		ok
		and await hands.run_terminal(
			CONSOLE, [[&"command.disable", TURRET], [&"command.disable", CAMERA_OFFICE], [&"command.open", VAULT_DOOR]]
		)
	)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tally.ghost()).override_failure_message(_route.report()).is_true()
	assert_bool(hands.door(VAULT_DOOR).is_open()).is_true()
	_saved = _route.snapshot()


func test_3_upstairs_the_vault_guard_knocked_out_and_the_prototype() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var hands := _route.hands
	# Out of the security room (its lock's free side), west along the ground corridor to the stairs.
	ok = ok and await hands.use_door(SECURITY_DOOR)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(SECURITY_DOOR).is_open(), 3.0, "the security door to open"
		)
	)
	ok = ok and await _route.sneak([Vector3(16.9, 0, 6.0), Vector3(10.65, 0, 6.0)])
	ok = ok and await hands.use_door(STAIRS_GROUND)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(STAIRS_GROUND).is_open(), 3.0, "the stairwell door to open"
		)
	)
	ok = (
		ok
		and await _route.sneak(
			[
				Vector3(10.65, 0, 7.8),
				Vector3(12.35, 0, 7.8),
				Vector3(12.35, 4.5, 14.3),
				Vector3(10.0, 4.5, 14.25),
				Vector3(10.0, 4.5, 7.8)
			]
		)
	)
	ok = ok and await hands.use_door(STAIRS_UPPER)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(STAIRS_UPPER).is_open(), 3.0, "the upper stairwell door to open"
		)
	)
	# The vault guard faces the vault door and glances left and right in turn. Once his glance to the
	# west (his left) is over, the next one is to the east, 4.5 s later: crouch from the stairwell
	# along the corridor's south wall (2.7 s) to arrive behind him as he turns east, and swing once
	# the player stands in his rear arc (the office camera is off).
	var g7 := _route.guard(G7)
	ok = ok and await _route.go([Vector3(10.65, 4.5, 7.4)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.wait_until(func() -> bool: return not GradedAwareness.of_node(g7).is_aware(), 20.0, "G7 calm")
	)
	ok = ok and await _route.glance_over(G7, 1)
	await _route.frames(120)
	ok = ok and await _route.go([Vector3(10.65, 4.5, 6.35), Vector3(15.05, 4.5, 6.35)], Route.Stance.CROUCH)
	ok = ok and await _route.wait_until(func() -> bool: return _route.behind(G7), 2.0, "G7 to turn his back")
	await hands.swing_at(g7)
	ok = ok and await _route.wait_until(func() -> bool: return not ActorState.can_act(g7), 2.0, "G7 down")
	# Carry him into the vault (the turret is off) and take the prototype from its pedestal.
	ok = ok and await hands.carry(g7)
	ok = ok and await _route.go([Vector3(16.9, 4.5, 5.6), Vector3(16.9, 4.5, 3.4)])
	ok = ok and await hands.put_down(Route.WEST)
	ok = ok and await _route.go([Vector3(17.8, 4.5, 3.5)])
	ok = ok and await hands.use_node(PROTOTYPE)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.mission.tracker.optional_done() > 0, 2.0, "the prototype taken"
		)
	)

	assert_bool(ok).override_failure_message(_route.report()).is_true()
	assert_bool(_route.mission.tally.ghost()).override_failure_message(_route.report()).is_true()
	_saved = _route.snapshot()


func test_4_out_by_the_fire_escape_door_and_the_back_gate() -> void:
	var ok := await _route.resume(scene_runner(Route.fixture(self)), _saved)
	_saved = {}
	var hands := _route.hands
	# Wait inside the corridor (the office camera is off) until G9, who turns at the fire escape's
	# foot, walks west past the back gate; the fire escape door opens freely from the corridor (its
	# lock's free side).
	ok = ok and await _route.go([Vector3(16.9, 4.5, 5.9), Vector3(19.0, 4.5, 6.0)], Route.Stance.CROUCH)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool:
				return _route.patrol_target(G9) == "BackStripA" and _route.guard(G9).global_position.x < 14.0,
			60.0,
			"G9 to head west"
		)
	)
	ok = ok and await hands.use_door(FIRE_ESCAPE_DOOR)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return hands.door(FIRE_ESCAPE_DOOR).is_open(), 3.0, "the fire escape door to open"
		)
	)
	ok = (
		ok
		and await _route.sneak(
			[Vector3(21.2, 4.5, 6.0), Vector3(21.2, 4.5, 7.0), Vector3(21.2, 1.44, 12.7), Vector3(21.2, 0, 14.8)]
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
	assert_bool(results["ghost"]).override_failure_message(_route.report()).is_true()
	assert_bool(results["pacifist"]).override_failure_message(_route.report()).is_true()
	assert_int(results["knockouts"]).is_equal(2)
	assert_int(results["kills"]).is_equal(0)
	assert_int(results["optional_done"]).is_equal(1)
