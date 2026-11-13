extends GdUnitTestSuite
## Scenario: the player throws a wooden crate at a brazier; the brazier's fire ignites it.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FIXTURE := "res://tests/scenarios/fixtures/brazier_throw.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_brazier_ignites_a_thrown_crate() -> void:
	var driver := PlayerDriver.new(scene_runner(FIXTURE))
	await driver.settle()
	var player := driver.player
	var crate := Objects.spawn(driver.runner.scene(), Objects.SMALL_CRATE, Vector3(0, 0.3, -1.0))
	await driver.frames(5)
	player.load_state(Objects.aiming_state(player, Vector3(0, 0, 0.6), crate.global_position))
	await driver.frames(3)
	await driver.hold(&"use", 2)
	assert_object(player.carry.held).is_same(crate)
	await driver.frames(20)
	player.look(Vector2(0, player.pitch / CONFIG.mouse_sensitivity))
	await driver.frames(10)
	EventLog.clear()

	await driver.hold(&"fire", 2)
	for i in 480:
		if not Objects.logged(&"object.ignited", "object", "SmallCrate").is_empty():
			break
		await driver.frames(1)

	assert_array(Objects.logged(&"carry.threw", "object", "SmallCrate")).has_size(1)
	var ignited := Objects.logged(&"object.ignited", "object", "SmallCrate")
	assert_array(ignited).has_size(1)
	var igniter := Objects.emitted(ignited[0].data["by"])
	assert_str(igniter.source).is_equal("Brazier")
	assert_str(igniter.data["type"]).is_equal("fire")
	# Landed next to the brazier and caught within a few seconds of the throw.
	assert_float((ignited[0].tick - EventLog.find(&"carry.threw")[0].tick) / 60.0).is_less(5.0)
