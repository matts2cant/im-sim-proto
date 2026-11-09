extends GdUnitTestSuite
## Scenario (playtest report, design/levels/mission-warehouse.md "Routes"; ADR 0094): the real
## player in the populated warehouse enters the manager office the way a player does, through duct
## B: walks into the roof mouth, crawls down the duct holding crouch and forward, drops through the
## hatch onto the filing cabinet (1.45 m onto metal: loudness 13.8) and walks on off it onto the
## carpet. Duct B is the ghost route into the office: no guard outside it hears that careful entry
## (the way out of the office is by its door: about 9 m to G7 plus the closed door's 6 m). A
## careless drop is noticed: with Speed Enhancement on (landings x1.5: 20.7) G7 hears it.
## Before ADR 0094 the noise leaked from the cabinet top's navmesh island in a straight line through
## the office wall (G7) and floor (G6, G5): all three went Suspicious, and G7, looking around outside
## the door, was Alerted when the player opened it.

const Route := preload("res://tests/levels/mission/warehouse_route_driver.gd")
const G7 := "G7VaultDoor"
## On the roof 2.7 m north of duct B's mouth (x 11, z -5.8), facing it (south).
const ROOF_START := Vector3(11, 9.5, -8.5)
## After landing on the carpet: time for the guards to react (they hear at once).
const SETTLE_SECONDS := 2.0

var _route: Route
## "guard margin" for every guard that heard the player, and "guard (reason)" for every Alerted one.
var _heard: PackedStringArray = []
var _alerted: PackedStringArray = []


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_route = Route.new()
	_heard = []
	_alerted = []


func after_test() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	_route.teardown()
	StimulusSystem.clear()


func test_a_careful_entry_is_heard_by_no_guard() -> void:
	var ok := await _enter_by_duct_b(false)

	var report := _report()
	assert_bool(ok).override_failure_message(report).is_true()
	assert_array(Array(_heard)).override_failure_message("Heard the careful entry:\n" + report).is_empty()
	assert_array(Array(_alerted)).override_failure_message("Alerted:\n" + report).is_empty()


func test_a_speed_enhanced_drop_is_heard_by_g7() -> void:
	var ok := await _enter_by_duct_b(true)

	var report := _report()
	assert_bool(ok).override_failure_message(report).is_true()
	var g7_heard := Array(_heard).any(func(line: String) -> bool: return line.begins_with(G7))
	assert_bool(g7_heard).override_failure_message("G7 did not hear the loud drop:\n" + report).is_true()
	assert_array(Array(_alerted)).override_failure_message("Alerted:\n" + report).is_empty()


# Places the player on the roof, optionally with Speed Enhancement on, and crawls in until the feet
# stand on the office floor; then lets the guards react. True when it got there.
func _enter_by_duct_b(speed_enhancement: bool) -> bool:
	await _route.setup(scene_runner(Route.fixture(self)))
	await _route.place(ROOF_START, Route.SOUTH)
	# Collected after place(): it clears the EventLog, nothing happens on the roof before.
	EventLog.entry_added.connect(_on_entry)
	if speed_enhancement:
		_route.player.augmentations.set_installed(&"speed_enhancement", true)
		if not _route.player.augmentations.activate(&"speed_enhancement"):
			_route.notes.append("Speed Enhancement did not switch on")
			return false
	# Walk into the mouth, then crouch and keep going forward: down the duct, through the hatch onto
	# the cabinet and on off its south edge onto the carpet.
	await _walk_south(0.5)
	var ok := await _crawl_to_the_office_floor()
	await _route.frames(roundi(SETTLE_SECONDS * 60.0))
	return ok


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


func _report() -> String:
	return "%s\nheard (guard margin m): %s" % [_route.report(), ", ".join(_heard)]


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind == &"actor.awareness" and entry.data.get("to", "") == "alerted":
		_alerted.append("%s (%s)" % [entry.data.get("actor", ""), entry.data.get("reason", "")])
	elif entry.kind == &"actor.heard" and entry.source == "Player":
		_heard.append("%s %.1f" % [entry.target, float(entry.data.get("perceived", 0.0))])
