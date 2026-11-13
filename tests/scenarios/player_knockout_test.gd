extends GdUnitTestSuite
## Scenario (regression, user report "stuck, no death screen"): the real player stands still in the
## lit combat yard (tests/scenarios/fixtures/combat_yard_player.tscn) while an armed guard with the
## level loadout (actors/guard/guard_baton.tscn or guard_pistol.tscn, as in the AI arena) attacks it.
## Nothing is tuned down: the baton's 20 stun a hit (items/weapons/baton/baton.tres) against the
## player's knockout threshold of 60 (actors/player/player_body.tres) knocks it out on the third hit,
## the guard leaves a downed target alone (ADR 0070) and nobody wakes the player (ADR 0071). The HUD
## must then show the "Knocked out" screen with the death screen's options.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
## 3 m in front of the guard (centre to centre), facing it: seen at once in the lit yard.
const SPOT := Vector3(0, 0, -3)
const FACING_GUARD := PI

var _c: Combat
var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_passive_player_hit_by_a_baton_guard_gets_the_knocked_out_screen() -> void:
	await _setup(Combat.BATON_GUARD)
	var player := _driver.player
	var hud := player.get_node("Hud") as Hud

	# The player does nothing; the guard keeps swinging until the player can no longer act.
	assert_bool(await _wait_until_down(player, 30.0)).is_true()
	var report := _state(player, hud)
	print("[knockout repro, baton] ", report)

	# Knocked out (not dead) after the third baton hit: 3 x 20 stun reaches the threshold of 60.
	assert_bool(ActorState.has(player, ActorState.UNCONSCIOUS)).is_true()
	assert_bool(player.is_dead()).is_false()
	assert_float(player.body.stun).is_equal_approx(60.0, 0.001)
	assert_array(EventLog.find(&"actor.knocked_out")).has_size(1)

	# The guard leaves the downed player alone; the player stays down and cannot move.
	await _c.seconds(2.0)
	assert_bool(ActorState.has(player, ActorState.UNCONSCIOUS)).is_true()
	var at := player.global_position
	await _driver.hold(&"move_forward", 30)
	assert_float(player.global_position.distance_to(at)).is_less(0.01)

	# The fix: the overlay shows the knockout variant, and E asks for the level reset as on death.
	assert_bool(hud.death_overlay.visible).is_true()
	assert_str(hud.overlay_title.text).is_equal(HudRules.KNOCKED_OUT_TITLE)
	player.reload_on_reset = false
	var resets: Array[int] = [0]
	player.reset_requested.connect(func() -> void: resets[0] += 1)
	await _driver.hold(&"use", 2)
	assert_int(resets[0]).is_equal(1)


func test_passive_player_shot_by_a_pistol_guard_dies_with_the_death_screen() -> void:
	await _setup(Combat.PISTOL_GUARD)
	var player := _driver.player
	var hud := player.get_node("Hud") as Hud

	assert_bool(await _wait_until_down(player, 60.0)).is_true()
	await _c.frames(2)
	print("[knockout repro, pistol] ", _state(player, hud))

	# Ballistic damage never adds stun: the pistol kills, and the death screen shows.
	assert_bool(player.is_dead()).is_true()
	assert_float(player.body.stun).is_equal(0.0)
	assert_array(EventLog.find(&"actor.knocked_out")).is_empty()
	assert_bool(hud.death_overlay.visible).is_true()
	assert_str(hud.overlay_title.text).is_equal(HudRules.DIED_TITLE)


func _setup(guard_scene: String) -> void:
	var runner := scene_runner(Combat.YARD_WITH_PLAYER)
	_driver = PlayerDriver.new(runner)
	_c = Combat.new()
	await _c.setup(runner, guard_scene)
	await _driver.place(SPOT, FACING_GUARD)


# Waits up to `limit` seconds for the player to lose the ability to act (dead or unconscious).
func _wait_until_down(player: Player, limit: float) -> bool:
	for tick in roundi(limit * 60.0):
		if not ActorState.can_act(player):
			return true
		await _c.frames(1)
	return not ActorState.can_act(player)


func _state(player: Player, hud: Hud) -> Dictionary:
	var health := {}
	for part in BodyDamageModel.PARTS:
		health[part] = player.body.health(part)
	var tags := (player.get_node("Tags") as Tags).save_state()
	return {
		"tags": tags,
		"stun": player.body.stun,
		"health": health,
		"dead": player.body.is_dead(),
		"unconscious": player.body.is_unconscious(),
		"overlay_visible": hud.death_overlay.visible,
		"hits": EventLog.find(&"actor.stunned").size(),
	}
