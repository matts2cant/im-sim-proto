extends GdUnitTestSuite
## Integration (ADR 0130 step 3, design/levels/mission-warehouse.md "Office bay (M13c)"): the player
## walks from the upper corridor through the second office's door (unlocked here) into the office,
## up to the locked linking bay on its east wall (stopped by its glass door, 0.3 m from the bay's
## front) and up to both desks (stopped by their lips), with the security population in place and
## the guards removed.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const SECURITY := "Population/Security/"
## The second office (upper floor, x 13.25..19.75, z 7..14.75).
const OFFICE := Rect2(13.25, 7.0, 6.5, 7.75)
const FLOOR := 4.5
## The bay's glass door (x 19.11 + 0.03 thick) and the desks' lips (z 13.9); the player's capsule
## radius is 0.35 m, so its feet stop about 0.35 m short of each.
const BAY_DOOR_X := 19.11
const DESK_LIP_Z := 13.9

var _helpers: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_the_player_walks_into_the_office_up_to_the_bay_and_both_desks() -> void:
	var level := Helpers.fixture(self, false)
	level.get_node("Population/People/Guards").free()
	var runner := scene_runner(level)
	_helpers.driver = PlayerDriver.new(runner)
	_helpers.player = _helpers.driver.player
	_helpers.player.reload_on_reset = false
	_helpers.level = level
	await _helpers.driver.frames(3)
	var mission := level.get_node("Mission") as Mission
	if mission.briefing.is_open():
		mission.briefing.close()
	var door := Door.of(level.get_node(SECURITY + "Doors/OfficeTwo"))
	Lockable.of(door.entity).unlock(null, &"test")
	door.open()
	await _helpers.driver.frames(90)

	var failures: PackedStringArray = []
	# From the upper corridor south through the office door.
	await _helpers.play(Vector3(16.5, FLOOR, 6.0), Helpers.SOUTH, [Helpers.walk(120)])
	var feet := _helpers.player.global_position
	if not OFFICE.has_point(Vector2(feet.x, feet.z)) or feet.z < 8.5 or absf(feet.y - FLOOR) > 0.1:
		failures.append("into the office: ended at %s" % feet)
	# East to the bay: stopped by its glass door.
	await _helpers.play(Vector3(16.5, FLOOR, 12.5), Helpers.EAST, [Helpers.walk(120)])
	feet = _helpers.player.global_position
	if absf(feet.x - (BAY_DOOR_X - 0.35)) > 0.1 or absf(feet.z - 12.5) > 0.2:
		failures.append("to the bay: ended at %s" % feet)
	# South to each desk: stopped by its lip.
	for x: float in [14.5, 18.0]:
		await _helpers.play(Vector3(x, FLOOR, 10.5), Helpers.SOUTH, [Helpers.walk(120)])
		feet = _helpers.player.global_position
		if absf(feet.z - (DESK_LIP_Z - 0.35)) > 0.1 or absf(feet.x - x) > 0.2:
			failures.append("to the desk at x %.1f: ended at %s" % [x, feet])
	assert_array(Array(failures)).is_empty()
