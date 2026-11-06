extends GdUnitTestSuite
## Scenario (EventLog) across body discovery (ADR 0071) and combat (ADR 0070), in the combat yard
## with the player (tests/scenarios/fixtures/combat_yard_player.tscn: lit floor, a 12 m cover wall
## across x -6..6 at z -12, the pistol guard at the origin facing -Z, the player hidden behind the
## wall at z -14). An unconscious ally lies across the guard's view, its middle 5 m ahead.
## - The guard finds it while the player is hidden and goes to wake it; the player steps into the
##   light 8 m from the origin: the guard drops the body, is Alerted by sight and engages; it does
##   not stop to wake the body while it fights.
## - A woken pistol guard fights: woken through the `revive` stimulus, it engages the player.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const GUARD_SCENE: PackedScene = preload("res://actors/guard/guard.tscn")
const PISTOL_SCENE: PackedScene = preload("res://actors/guard/guard_pistol.tscn")
const OPEN := Vector3(0, 0, -8)
const HIDDEN := Vector3(0, 0, -14)
const FACING_GUARD := PI
const UNCONSCIOUS: Array[StringName] = [&"actor.guard", &"equipment.radio", &"state.unconscious"]

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


func _downed(scene: PackedScene, body_name: String, feet: Vector3, yaw: float) -> NavWalker:
	var body := scene.instantiate() as NavWalker
	body.name = body_name
	(body.get_node("Tags") as Tags).initial_tags = UNCONSCIOUS
	body.position = feet
	body.rotation.y = yaw
	_c.scene.add_child(body)
	return body


func test_a_guard_tending_a_body_drops_it_to_engage_the_player() -> void:
	var body := _downed(GUARD_SCENE, "Downed", Vector3(-0.9, 0, -5), PI * 0.5)
	var model := _c.awareness.model
	# Found while the player is hidden; it runs over and stands by the body.
	var tending := false
	for tick in 300:
		await _c.frames(1)
		if model.phase == AwarenessModel.Phase.TEND:
			tending = true
			break
	assert_bool(tending).is_true()
	assert_array(Combat.guard_entries(&"actor.body_found")).has_size(1)
	assert_str(model.reason).is_equal("body")
	assert_array(Combat.guard_entries(&"actor.engaged")).is_empty()

	await _driver.place(OPEN, FACING_GUARD)
	var engaged := false
	for tick in 240:
		await _c.frames(1)
		if _c.combat.is_engaged():
			engaged = true
			break
	assert_bool(engaged).is_true()
	# (PlayerDriver.place() clears the log once the player has landed: read the model.)
	assert_str(_c.awareness.state_name()).is_equal("alerted")
	assert_str(model.reason).is_equal("sight")
	assert_bool(model.tending).is_false()

	# Fighting, not waking: the body stays down while the guard engages.
	await _c.frames(180)
	assert_array(Combat.guard_entries(&"weapon.fired")).is_not_empty()
	assert_array(Combat.guard_entries(&"actor.wake")).is_empty()
	assert_bool(ActorState.has(body, ActorState.UNCONSCIOUS)).is_true()


func test_a_woken_pistol_guard_engages_the_player() -> void:
	# Off to the side of the main guard, facing the open ground; woken directly.
	var sleeper := _downed(PISTOL_SCENE, "Sleeper", Vector3(3, 0, -2), 0.0)
	await _c.frames(10)
	StimulusSystem.emit(Stimulus.make_contact(&"revive", 1.0, sleeper, _c.guard))
	await _c.frames(4)
	assert_bool(ActorState.can_act(sleeper)).is_true()
	var awareness := GradedAwareness.of_node(sleeper)
	assert_str(awareness.state_name()).is_equal("searching")
	assert_str(awareness.model.reason).is_equal("woken")

	await _driver.place(OPEN, FACING_GUARD)
	var sleeper_combat := CombatBehaviour.of(sleeper)
	var engaged := false
	for tick in 300:
		await _c.frames(1)
		if sleeper_combat.is_engaged():
			engaged = true
			break
	assert_bool(engaged).is_true()
	var engagements := EventLog.find(&"actor.engaged").filter(
		func(entry: EventLogEntry) -> bool: return entry.data.get("actor") == "Sleeper"
	)
	assert_array(engagements).is_not_empty()
