extends GdUnitTestSuite
## Integration: the player walks through a default 1.2 x 2.2 m Room opening; walls without one block.
## Fixture: a 4 x 3 x 4 m room at the origin with a door in the north wall (z = -2).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const FIXTURE := "res://tests/levels/kit/fixtures/room_passage.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_player_walks_out_through_the_door() -> void:
	await _load()
	await _driver.place(Vector3(0, 0, 1), 0.0)

	await _driver.hold(&"move_forward", 90)

	assert_float(_player.global_position.z).is_less(-3.0)
	assert_float(_player.global_position.y).is_between(-0.05, 0.05)


func test_wall_without_opening_blocks_the_player() -> void:
	await _load()
	await _driver.place(Vector3(0, 0, -1), PI)

	await _driver.hold(&"move_forward", 90)

	assert_float(_player.global_position.z).is_between(1.0, 2.0 - 0.3)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FIXTURE))
	_player = _driver.player
	await _driver.settle()
