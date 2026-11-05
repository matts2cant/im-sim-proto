extends GdUnitTestSuite
## Integration: mantling ledges in the obstacles fixture (faces at z = -2, player 0.6 m away).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const OBSTACLES := "res://tests/actors/player/fixtures/obstacles.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_mantles_one_metre_ledge() -> void:
	await _assert_mantles(Vector3(0, 0, -1.4), 1.0, false)


func test_mantles_max_height_ledge() -> void:
	await _assert_mantles(Vector3(5, 0, -1.4), 1.9, false)


func test_mantles_into_vent_crouched() -> void:
	await _assert_mantles(Vector3(15, 0, -1.4), 1.5, true)


func test_refuses_ledge_above_max_height_even_with_jump_held() -> void:
	await _load()
	await _driver.place(Vector3(10, 0, -1.4))

	await _driver.hold(&"jump", 50)
	await _driver.frames(40)

	assert_array(EventLog.find(&"player.mantled")).is_empty()
	assert_float(_player.global_position.y).is_less(0.05)
	assert_float(_player.global_position.z).is_greater(-2.0)


func _assert_mantles(start: Vector3, height: float, end_crouched: bool) -> void:
	await _load()
	await _driver.place(start)

	await _driver.hold(&"jump", 3)
	await _driver.frames(60)

	var mantles := EventLog.find(&"player.mantled")
	assert_int(mantles.size()).is_equal(1)
	assert_str(mantles[0].source).is_equal("Player")
	assert_float(mantles[0].data["height"]).is_equal_approx(height, 0.02)
	assert_float(_player.global_position.y).is_equal_approx(height, 0.02)
	assert_float(_player.global_position.z).is_less(-2.3)
	assert_bool(_player.crouched).is_equal(end_crouched)
	assert_bool(_player.is_on_floor()).is_true()
	assert_array(EventLog.find(&"player.landed")).is_empty()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(OBSTACLES))
	_player = _driver.player
	await _driver.settle()
