extends GdUnitTestSuite
## Scenario (design/levels/mission-warehouse.md "Roof security", ADR 0097): the roof's security is
## on the yard circuit, so cutting breaker A switches it off. The real player, starting kit only, in
## the populated level with its guards removed (the moves and the devices are under test), starts
## arranged on the back strip under the annex's high window with the two small crates stacked there
## (as warehouse_additions_test.gd leaves them): climbs in, switches breaker A off, climbs out, goes
## up the annex chain and the annex stair and walks upright through the west gap, across the dark
## forecourt in the roof camera's view and into duct B. No beam trips, the camera sees nothing and no
## alarm rings.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const PROPS := "Population/People/Props/"
const BREAKER_A := "Population/Security/Devices/BreakerA"
const LASERS: Array[String] = ["LaserRoofWest", "LaserRoofEast"]
const WINDOW_X := -23.0
## The annex south wall's outer face; the crates stand against it.
const WALL_FACE_Z := 13.0

var _route: Route


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()


func after_test() -> void:
	_route.teardown()
	StimulusSystem.clear()


func test_breaker_a_off_the_roof_is_walked_upright_unseen() -> void:
	var level := Route.fixture(self)
	for guard in level.get_node(Route.GUARDS).get_children():
		guard.free()
	await _route.setup(scene_runner(level))
	var hands := _route.hands
	var events: Array[EventLogEntry] = []
	var collect := func(entry: EventLogEntry) -> void:
		if entry.kind in [&"laser.tripped", &"camera.detected", &"alarm.raised", &"power.switched"]:
			events.append(entry)
	EventLog.entry_added.connect(collect)
	# Arranged: the two window crates stacked against the wall under the window.
	var stack := Vector3(WINDOW_X, 0, WALL_FACE_Z + 0.65)
	for i in 2:
		var crate := _route.level.get_node(PROPS + "WindowCrate%d" % (i + 1)) as RigidBody3D
		crate.global_transform = Transform3D(Basis.IDENTITY, stack + Vector3(0, 0.3 + 0.6 * i, 0))
		crate.linear_velocity = Vector3.ZERO
		crate.angular_velocity = Vector3.ZERO
	await _route.frames(30)
	for i in 2:
		_route.notes.append(
			(
				"crate %d at %s"
				% [i + 1, (_route.level.get_node(PROPS + "WindowCrate%d" % (i + 1)) as Node3D).global_position]
			)
		)
	await _route.place(Vector3(WINDOW_X, 0, WALL_FACE_Z + 1.7), Route.NORTH)

	# Onto the stack (1.2), into the window (1.7), down the ledge inside (1.4, 1.5) to breaker A.
	var ok := await _route.climb(Route.NORTH, 1.2)
	ok = ok and await _route.climb(Route.NORTH, 2.9)
	ok = ok and await _route.go([Vector3(WINDOW_X, 0, 11.0), Vector3(-25.2, 0, 4.0)], Route.Stance.CROUCH)
	ok = ok and await hands.use_node(BREAKER_A)
	ok = ok and await _route.wait_until(func() -> bool: return not _lasers_on(), 1.0, "the beams to go off")
	# Out the same way: the ledge (1.5), the window (1.4), down the stack to the back strip.
	ok = ok and await _route.climb_from(Vector3(WINDOW_X, 0, 11.15), Route.SOUTH, 1.5)
	ok = ok and await _route.climb(Route.SOUTH, 2.9)
	ok = ok and await _route.go([Vector3(WINDOW_X, 0, WALL_FACE_Z + 1.6)], Route.Stance.CROUCH)
	# West along the back strip and north to the annex chain; up it and the annex stair.
	ok = ok and await _route.go([Vector3(-31, 0, 15), Vector3(-32.2, 0, 8)])
	ok = ok and await _route.climb_from(Vector3(-30.8, 0, 6), Route.EAST, 1.2)
	ok = ok and await _route.climb_from(Vector3(-29.6, 1.2, 6), Route.EAST, 2.5)
	ok = ok and await _route.climb_from(Vector3(-28.4, 2.5, 6), Route.EAST, 3.6)
	ok = ok and await _route.climb_from(Vector3(-27.2, 3.6, 6), Route.EAST, 4.75)
	ok = ok and await _route.go([Vector3(-23.5, 4.75, 7), Vector3(-23.5, 4.75, 12.3), Vector3(-21.25, 4.75, 12.3)])
	ok = ok and await _route.go([Vector3(-21.25, 9.5, 3.0)])
	# Upright through the west gap, across the roof and the unlit forecourt into duct B.
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
	# Stand in the forecourt in the camera's sweep for a whole cycle: still nothing.
	await _route.frames(roundi(15.0 / Route.TICK))
	ok = ok and await _route.go([Vector3(11, 9.7, -5.0)], Route.Stance.CROUCH)
	EventLog.entry_added.disconnect(collect)
	var report := (
		"%s\n%s" % [events.map(func(e: EventLogEntry) -> String: return "%s %s" % [e.kind, e.data]), _route.report()]
	)

	assert_bool(ok).override_failure_message(report).is_true()
	var kinds := events.map(func(e: EventLogEntry) -> StringName: return e.kind)
	assert_array(kinds).override_failure_message(report).contains([&"power.switched"])
	assert_array(kinds).override_failure_message(report).not_contains(
		[&"laser.tripped", &"camera.detected", &"alarm.raised"]
	)
	assert_bool(_lasers_on()).is_false()
	assert_bool(SecurityCamera.of(_route.level.get_node(Route.DEVICES + "/CameraRoof")).is_watching()).is_true()
	assert_int(_route.mission.tally.alarms).is_equal(0)


# True while any roof laser watches its beam.
func _lasers_on() -> bool:
	for laser_name: String in LASERS:
		if LaserArray.of(_route.level.get_node(Route.DEVICES + "/" + laser_name)).is_watching():
			return true
	return false
