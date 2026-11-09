extends GdUnitTestSuite
## Regression (M9h playtest, ADR 0100): at the booth terminal the player sets the turret to target
## guards, then opens the vault; the turret kills the post guard. Before the fix the turret saw the
## body as a hostile every tick, engaged it again (warning beep restarted, noise 10 emitted) and
## dropped it as `target_down` on the next tick: the beep looped for as long as the body lay there.
## Now the dead guard is no sighting: no new engagement, no turret noise, and the beep stops.
## The hub loads every gallery room: the other rooms' guards are held still, or one answering the
## wing's alarm (the AI arena's post guard, seen once in a full run) can walk into the turret's view
## after the kill and be engaged, rightly: the turret targets every `actor.guard`. This test is
## about the downed one only.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"

var _driver: PlayerDriver
var _wing: Node3D
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(HUB))
	_player = _driver.player
	_player.reload_on_reset = false
	_wing = _driver.runner.find_child("SecurityWing") as Node3D
	assert_array(GuardHelpers.hold_guards_outside(_driver.runner.scene(), _wing)).is_not_empty()
	await _driver.settle()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _node(path: String) -> Node3D:
	return _wing.get_node(path) as Node3D


func test_the_turret_beep_stops_after_it_kills_the_post_guard() -> void:
	# At the booth terminal (as in security_wing_scenario_test), logged in with the booth login.
	var feet := Vector3(-0.25, 0, 8.1)
	var to := Vector3(-0.25, 1.45, 8.99) - feet
	await _driver.place(_wing.to_global(feet), atan2(-to.x, -to.z))
	var terminal := Terminal.of(_node("Devices/Terminal"))
	assert_bool(terminal.log_in("rvoss", "kestrel4", _player)).is_true()
	var turret := Turret.of(_node("Devices/Turret"))
	assert_bool(terminal.send(Device.TARGET_GUARDS, Device.of(_node("Devices/Turret")))).is_true()
	await _driver.frames(3)
	assert_bool(terminal.send(Device.OPEN, Device.of(_node("Doors/VaultDoor")))).is_true()

	# The turret sees the post guard through the open vault and kills him (about 5 s).
	var guard := _node("Guards/GuardBatonVault")
	for i in 60 * 15:
		await _driver.frames(1)
		if not ActorState.can_act(guard):
			break
	assert_bool(ActorState.can_act(guard)).override_failure_message("the turret never downed the guard").is_false()

	# From now on: no new engagement and no turret noise; the 0.6 s beep has stopped by 1.5 s.
	var engaged: Array[EventLogEntry] = []
	var turret_noises: Array[EventLogEntry] = []
	var on_entry := func(entry: EventLogEntry) -> void:
		if entry.kind == &"turret.engaged":
			engaged.append(entry)
		elif entry.kind == &"stimulus.emitted" and entry.source == "Turret":
			turret_noises.append(entry)
	EventLog.entry_added.connect(on_entry)
	await _driver.frames(90)
	var beep := _node("Devices/Turret").get_node("Sound") as AudioStreamPlayer3D
	assert_bool(beep.playing).override_failure_message("the turret beep still plays").is_false()
	await _driver.frames(90)
	EventLog.entry_added.disconnect(on_entry)
	assert_array(engaged).is_empty()
	assert_array(turret_noises).is_empty()
	assert_object(turret.target).is_null()
	assert_bool(beep.playing).is_false()
