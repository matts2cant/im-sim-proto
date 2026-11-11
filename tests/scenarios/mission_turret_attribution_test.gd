extends GdUnitTestSuite
## Scenario (ADR 0087): a turret the player retargets kills a guard, and that death is the player's.
## The player sends `command.target_guards` from the security showcase's computer (Computer.send()
## with the player as the operator, as the Security app does); the turret makes that command the
## cause of its shots (WeaponHolder.cause_id), so a MissionTally fed the EventLog counts the guard's
## death as a kill. The same command sent by nobody in particular kills nobody of the player's.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")

var _show: Showcase
var _tally: MissionTally


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Camera")
	_show.turret().holder.seed_rng(7)
	# The player out of the turret's way, beside the console.
	await _show.place_player(Vector3(12, 0, 1), PI / 2.0)
	var names: Array[String] = [String(_show.player.name)]
	_tally = MissionTally.new(names)
	EventLog.entry_added.connect(_tally.observe)
	EventLog.clear()


func after_test() -> void:
	if EventLog.entry_added.is_connected(_tally.observe):
		EventLog.entry_added.disconnect(_tally.observe)
	StimulusSystem.clear()


func _guard() -> BodyParts:
	var body := Characters.character(
		_show.scene, "Guard", Showcase.TURRET_SPOT, [] as Array[StringName], PhysicsLayers.ACTORS
	)
	body.rotation.y = -PI / 2.0
	body.add_child(HITBOXES.instantiate())
	Characters.tags_of(body).add(&"actor.guard")
	return BodyParts.of(body)


func _wait_for_death(body: BodyParts, limit: float) -> void:
	for tick in roundi(limit * 60.0):
		if body.is_dead():
			return
		await _show.frames(1)


func test_a_guard_killed_by_a_turret_the_player_retargeted_is_the_players_kill() -> void:
	var computer := _show.computer()
	assert_bool(computer.send(Device.TARGET_GUARDS, _show.turret().device, _show.player)).is_true()
	await _show.frames(2)
	var body := _guard()

	await _wait_for_death(body, 15.0)

	assert_bool(body.is_dead()).is_true()
	var command := EventLog.find(&"device.command")[0]
	assert_str(str(command.data["by"])).is_equal(String(_show.player.name))
	assert_int(_show.turret().holder.cause_id).is_equal(int(command.data["stimulus"]))
	assert_int(_tally.kills).is_equal(1)
	assert_bool(_tally.pacifist()).is_false()


func test_a_turret_nobody_retargeted_kills_nobody_of_the_players() -> void:
	await _show.command(Device.TARGET_GUARDS, "Turret")
	var body := _guard()

	await _wait_for_death(body, 15.0)

	assert_bool(body.is_dead()).is_true()
	assert_int(_tally.kills).is_equal(0)
	assert_bool(_tally.pacifist()).is_true()
