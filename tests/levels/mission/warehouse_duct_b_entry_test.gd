extends GdUnitTestSuite
## Scenario (playtest report, design/levels/mission-warehouse.md "Routes"): the real player in the
## populated warehouse enters the manager office the way a player does, through duct B: walks into
## the roof mouth, crawls down the duct holding crouch and forward, drops through the hatch onto the
## filing cabinet and walks on off it onto the carpet, then opens the office door from inside (its
## free side) to leave. Duct B is the ghost route into the office: an ordinary entry must not leave
## a guard Alerted, and no guard outside the office hears the careful drop through its walls.
## KNOWN FAILURE (branch fix-duct-b-alert, not fixed yet): the landing on the metal cabinet top
## (1.45 m drop, 7.2 m/s, loudness 13.8) snaps to the navmesh island on the cabinet top, from which
## no navmesh path leaves; StimulusSystem bridges the partial path with a straight line through the
## office wall (G7, 6.2 m: margin 7.6), its floor (G6, 6.7 m: 7.2) and more (G5, 9.5 m: 4.3). The
## real way out, by the office door (attenuator 6 m), is 9.0 m to G7 and over 70 m to G5 and G6.
## G7 investigates, looks around right outside the door and sees the player as it opens (0.7 m,
## light 0.17): Alerted about 1.6 s later, then radio.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const MANAGER_DOOR := "Population/Security/Doors/ManagerDoor"
## On the roof 2.7 m north of duct B's mouth (x 11, z -5.8), facing it (south).
const ROOF_START := Vector3(11, 9.5, -8.5)

var _route: Route
## "actor (reason)" for every guard that became Alerted, and "guard margin" for every one that
## heard the player.
var _alerted: PackedStringArray = []
var _heard: PackedStringArray = []


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()
	_alerted = []
	_heard = []


func after_test() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	_route.teardown()
	StimulusSystem.clear()


func test_entering_by_duct_b_and_opening_the_door_alerts_no_guard() -> void:
	await _route.setup(scene_runner(Route.fixture(self)))
	await _route.place(ROOF_START, Route.SOUTH)
	# Collected after place(): it clears the EventLog, nothing happens on the roof before.
	EventLog.entry_added.connect(_on_entry)
	# Walk into the mouth, then crouch and keep going forward: down the duct, through the hatch onto
	# the cabinet and on off its south edge onto the carpet.
	await _walk_south(0.5)
	var ok := await _crawl_to_the_office_floor()
	# Leave by the door at once: it opens freely from the office side.
	ok = ok and await _route.hands.use_door(MANAGER_DOOR)
	ok = (
		ok
		and await _route.wait_until(
			func() -> bool: return _route.hands.door(MANAGER_DOOR).is_open(), 3.0, "the door to open"
		)
	)
	# 5 s of game time with the door open (G7 needed 1.6 s at 0.7 m), or until a guard is Alerted.
	await _route.wait_until(func() -> bool: return not _alerted.is_empty(), 5.0, "a guard to be alerted")

	var report := "%s\nheard (guard, margin m): %s" % [_route.report(), ", ".join(_heard)]
	assert_bool(ok).override_failure_message(report).is_true()
	assert_array(Array(_alerted)).override_failure_message("Alerted: %s\n%s" % [_alerted, report]).is_empty()
	assert_array(Array(_heard)).override_failure_message("Heard the careful entry:\n" + report).is_empty()


# Holds forward (the view turned south) for `seconds` of game time.
func _walk_south(seconds: float) -> void:
	_route.runner.simulate_action_press(&"move_forward")
	for i in roundi(seconds * 60.0):
		_route.player.rotation.y = Route.SOUTH
		await _route.frames(1)
	_route.runner.simulate_action_release(&"move_forward")


# Forward and crouch held until the feet stand on the office floor (4.5), at most 15 s.
func _crawl_to_the_office_floor() -> bool:
	_route.runner.simulate_action_press(&"move_forward")
	_route.runner.simulate_action_press(&"crouch")
	var reached := false
	for i in 900:
		_route.player.rotation.y = Route.SOUTH
		await _route.frames(1)
		if _route.player.is_on_floor() and absf(_route.player.global_position.y - 4.5) < 0.1:
			reached = true
			break
	_route.runner.simulate_action_release(&"move_forward")
	_route.runner.simulate_action_release(&"crouch")
	if not reached:
		_route.notes.append("did not reach the office floor: feet at %s" % _route.player.global_position)
	return reached


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind == &"actor.awareness" and entry.data.get("to", "") == "alerted":
		_alerted.append("%s (%s)" % [entry.data.get("actor", ""), entry.data.get("reason", "")])
	elif entry.kind == &"actor.heard" and entry.source == "Player":
		_heard.append("%s %.1f" % [entry.target, float(entry.data.get("perceived", 0.0))])
