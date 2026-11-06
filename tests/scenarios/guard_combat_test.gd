extends GdUnitTestSuite
## Scenario (EventLog): the player and a pistol guard in the combat yard
## (tests/scenarios/fixtures/combat_yard_player.tscn: lit floor, a 12 m cover wall across
## x -6..6 at z -12; the guard at the origin facing -Z, the player hidden behind the wall at
## z -14). The player steps into the light 8 m in front of the guard: sight -> Alerted -> engaged ->
## shots (the same `damage.ballistic` RAY stimuli as the player's) -> the player's health drops.
## Back behind the wall: the guard stops firing, hands its walker back, runs to the last known
## position and, unseen for 4 s, starts Searching.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const OPEN := Vector3(0, 0, -8)
const HIDDEN := Vector3(0, 0, -14)
const FACING_GUARD := PI

var _c: Combat
var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	var runner := scene_runner(Combat.YARD_WITH_PLAYER)
	_driver = PlayerDriver.new(runner)
	_c = Combat.new()
	await _c.setup(runner, Combat.PISTOL_GUARD)
	await _driver.place(HIDDEN, FACING_GUARD)


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_lit_player_is_shot_until_it_breaks_line_of_sight_then_searched_for() -> void:
	var player := _driver.player
	var full := Combat.total_health(player)
	await _driver.place(OPEN, FACING_GUARD)
	assert_float(LightExposure.of(player).level).is_greater(0.5)

	# Seen, alerted, engaged, and shot until hurt.
	var hurt := false
	for tick in 360:
		await _c.frames(1)
		if Combat.total_health(player) < full:
			hurt = true
			break
	assert_bool(hurt).is_true()
	assert_array(Combat.states()).contains(["alerted"])
	var alerted := Combat.guard_entries(&"actor.awareness").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["to"] == "alerted"
	)
	assert_str(String(alerted[0].data["reason"])).is_equal("sight")
	assert_array(Combat.guard_entries(&"actor.engaged")).has_size(1)
	assert_array(Combat.guard_entries(&"weapon.fired")).is_not_empty()
	var hits := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool:
			return entry.target == "Player" and entry.data.get("type") == &"damage.ballistic"
	)
	assert_array(hits).is_not_empty()
	assert_bool(ActorState.is_dead(player)).is_false()

	# Back behind the wall: no more shots, the walker goes back to the awareness behaviour.
	player.global_position = HIDDEN
	var hidden_tick := Engine.get_physics_frames()
	var searching := false
	for tick in 600:
		await _c.frames(1)
		if _c.awareness.state() == AwarenessModel.State.SEARCHING:
			searching = true
			break
	assert_bool(searching).is_true()
	var later := Combat.guard_entries(&"weapon.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.tick > hidden_tick + 1
	)
	assert_array(later).is_empty()
	var disengaged := Combat.guard_entries(&"actor.disengaged")
	assert_array(disengaged).has_size(1)
	assert_str(String(disengaged[0].data["reason"])).is_equal("lost")
	assert_array(Combat.states()).is_equal(["suspicious", "alerted", "searching"])
	assert_str(String(Combat.guard_entries(&"actor.awareness")[-1].data["reason"])).is_equal("lost")
