extends GdUnitTestSuite
## Integration: player contracts (saveable) and its debug panel tab.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const FLAT_FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_save_load_round_trip() -> void:
	await _load()
	var state := {
		"position": Vector3(3, 0.5, -4),
		"yaw": 1.2,
		"pitch": -0.4,
		"crouched": true,
		"velocity": Vector3(1, 0, 2),
	}

	_player.load_state(state)
	var saved := _player.save_state()
	_player.load_state(PlayerDriver.state(Vector3.ZERO, 0.0))
	_player.load_state(saved)

	assert_bool(_player.is_in_group(LevelSnapshot.GROUP)).is_true()
	assert_vector(saved["position"]).is_equal_approx(state["position"], Vector3.ONE * 0.0001)
	assert_float(saved["yaw"]).is_equal_approx(state["yaw"], 0.0001)
	assert_float(saved["pitch"]).is_equal_approx(state["pitch"], 0.0001)
	assert_bool(saved["crouched"]).is_true()
	assert_vector(saved["velocity"]).is_equal(state["velocity"])
	assert_dict(_player.save_state()).is_equal(saved)
	assert_float(_player.capsule_height()).is_equal_approx(CONFIG.crouched_height, 0.0001)


func test_debug_tab_shows_live_state() -> void:
	await _load()
	await _driver.place(Vector3.ZERO)
	_driver.runner.simulate_action_press("move_forward")
	await _driver.frames(60)

	var tab := _player_tab()
	tab.call(&"refresh")
	var text: String = (tab.get_node("Readout") as Label).text
	_driver.runner.simulate_action_release("move_forward")

	assert_str(text).contains("Mode: walk").contains("Surface: wood").contains("Grounded: yes")
	assert_str(text).contains("Speed: %.2f" % CONFIG.walk_speed)


func test_debug_tab_is_removed_with_player() -> void:
	await _load()
	var tab := _player_tab()
	assert_object(tab).is_not_null()

	_player.get_parent().remove_child(_player)
	_player.free()
	await get_tree().process_frame

	assert_bool(is_instance_valid(tab)).is_false()


func test_debug_tab_returns_when_player_reenters_tree() -> void:
	await _load()
	var parent := _player.get_parent()

	parent.remove_child(_player)
	await get_tree().process_frame
	assert_object(_player_tab()).is_null()
	parent.add_child(_player)

	assert_object(_player_tab()).is_not_null()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FLAT_FLOOR))
	_player = _driver.player
	await _driver.settle()


func _player_tab() -> Control:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		var tab := tabs.get_tab_control(i)
		if tabs.get_tab_title(i) == "Player" and tab.get(&"player") == _player:
			return tab
	return null
