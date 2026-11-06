extends GdUnitTestSuite
## Integration: a thrown glass bottle shatters on the wall and makes noise.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_thrown_bottle_breaks_on_the_wall_and_makes_noise() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	await _driver.settle()
	var player := _driver.player
	var bottle := Objects.spawn(_driver.runner.scene(), Objects.GLASS_BOTTLE, Vector3(0, 0.15, -1.0))
	await _driver.frames(5)
	player.load_state(Objects.aiming_state(player, Vector3.ZERO, bottle.global_position))
	await _driver.frames(3)
	await _driver.hold(&"use", 2)
	assert_object(player.carry.held).is_same(bottle)
	await _driver.frames(20)
	player.look(Vector2(0, player.pitch / CONFIG.mouse_sensitivity))
	EventLog.clear()

	await _driver.hold(&"fire", 2)
	await _driver.frames(40)

	assert_float(Objects.logged(&"player.threw", "object", "GlassBottle")[0].data["speed"]).is_equal(12.0)
	var impact: EventLogEntry = Objects.logged(&"object.impact", "object", "GlassBottle")[0]
	assert_str(impact.data["other"]).is_equal("Wall")
	assert_float(impact.data["speed"]).is_greater(4.0)
	assert_array(Objects.logged(&"object.broken", "reason", &"impact")).has_size(1)
	assert_bool(is_instance_valid(bottle)).is_false()
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "GlassBottle" and entry.data["type"] == &"noise"
	)
	var loudness := noises.map(func(entry: EventLogEntry) -> float: return entry.data["intensity"])
	assert_array(loudness).contains([15.0])
	assert_float(loudness[0]).is_equal_approx(impact.data["loudness"], 0.0001)
