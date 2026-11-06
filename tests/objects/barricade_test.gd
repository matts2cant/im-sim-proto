extends GdUnitTestSuite
## Integration: a wooden barricade blocks a 1.2 x 2.2 m doorway until it burns out; then it is
## removed and the player capsule walks through.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const DOOR := "res://tests/objects/fixtures/barricade_door.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_burnt_out_barricade_opens_the_doorway() -> void:
	_driver = PlayerDriver.new(scene_runner(DOOR))
	await _driver.settle()
	var player := _driver.player
	var barricade: Node3D = _driver.runner.find_child("WoodenBarricade")
	await _driver.place(Vector3(0, 0, -1))
	var probe := PlayerProbe.new(player, CONFIG)
	assert_bool(probe.sweep_clear(Vector3(0, 0, -1), Vector3(0, 0, -5), CONFIG.standing_height)).is_false()

	var flammable := Flammable.of(barricade)
	flammable.ignite(null)
	flammable.fuel_left = 0.3
	await _driver.frames(30)

	assert_array(Objects.logged(&"object.burnt_out", "object", "WoodenBarricade")).has_size(1)
	assert_array(Objects.logged(&"object.broken", "reason", &"burnt_out")).has_size(1)
	assert_bool(is_instance_valid(barricade)).is_false()
	assert_bool(probe.sweep_clear(Vector3(0, 0, -1), Vector3(0, 0, -5), CONFIG.standing_height)).is_true()

	await _driver.hold(&"move_forward", 90)
	assert_float(player.global_position.z).is_less(-4.0)


func test_barricade_blocks_the_doorway_while_intact() -> void:
	_driver = PlayerDriver.new(scene_runner(DOOR))
	await _driver.settle()
	var player := _driver.player
	await _driver.place(Vector3(0, 0, -1))

	await _driver.hold(&"move_forward", 90)

	assert_float(player.global_position.z).is_greater(-3.0)
