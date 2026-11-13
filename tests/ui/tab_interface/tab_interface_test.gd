extends GdUnitTestSuite
## Integration (ADR 0110): the Tab interface's open / close / switch rules with real actions. Tab
## opens on the last tab used and closes; I and L open on Inventory / Journal, switch to it when open
## and close when it already shows; 1-5 and Q / E select tabs; Esc and the close button close it.
## While open the player's input is off and the mouse is free, both restored on close; the world
## keeps running (the game is not paused, a rigid body keeps falling).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const INVENTORY := 0
const JOURNAL := 4
const TITLES: Array[String] = ["Inventory", "Health", "Augmentations", "Skills", "Journal"]

var _driver: PlayerDriver
var _player: Player
var _tabs: TabInterface


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_tab_opens_on_the_last_tab_used_and_closes() -> void:
	await _load()

	await _driver.press(&"tab_interface")
	assert_bool(_tabs.is_open()).is_true()
	assert_int(_tabs.current).is_equal(INVENTORY)
	assert_int(_tabs.page_count()).is_equal(TITLES.size())
	for i in TITLES.size():
		assert_str(_tabs.tab_button(i).text).is_equal(TITLES[i])
		assert_bool(_tabs.page(i).visible).is_equal(i == INVENTORY)

	await _driver.press(&"belt_3")
	assert_int(_tabs.current).is_equal(2)
	await _driver.press(&"tab_interface")
	assert_bool(_tabs.is_open()).is_false()

	await _driver.press(&"tab_interface")
	assert_bool(_tabs.is_open()).is_true()
	assert_int(_tabs.current).is_equal(2)
	assert_bool(_tabs.current_page().visible).is_true()


func test_i_and_l_open_switch_and_close_their_tab() -> void:
	await _load()

	await _driver.press(&"inventory")
	assert_bool(_tabs.is_open()).is_true()
	assert_int(_tabs.current).is_equal(INVENTORY)
	await _driver.press(&"personal_log")
	assert_bool(_tabs.is_open()).is_true()
	assert_int(_tabs.current).is_equal(JOURNAL)
	await _driver.press(&"personal_log")
	assert_bool(_tabs.is_open()).is_false()

	await _driver.press(&"personal_log")
	assert_int(_tabs.current).is_equal(JOURNAL)
	await _driver.press(&"inventory")
	assert_int(_tabs.current).is_equal(INVENTORY)
	await _driver.press(&"inventory")
	assert_bool(_tabs.is_open()).is_false()


func test_number_keys_and_q_e_select_tabs() -> void:
	await _load()
	await _driver.press(&"tab_interface")

	await _driver.press(&"belt_5")
	assert_int(_tabs.current).is_equal(4)
	await _driver.press(&"tab_next")
	assert_int(_tabs.current).is_equal(0)
	await _driver.press(&"tab_prev")
	assert_int(_tabs.current).is_equal(4)
	await _driver.press(&"tab_prev")
	assert_int(_tabs.current).is_equal(3)
	await _driver.press(&"belt_2")
	assert_int(_tabs.current).is_equal(1)
	# A click on a tab title does the same.
	_tabs.tab_button(3).pressed.emit()
	assert_int(_tabs.current).is_equal(3)
	# The belt keys select tabs, not belt slots, while it is open.
	assert_int(_player.inventory.belt.selected).is_equal(-1)


func test_esc_and_the_close_button_close() -> void:
	await _load()

	await _driver.press(&"tab_interface")
	await _driver.press(&"ui_cancel")
	assert_bool(_tabs.is_open()).is_false()
	assert_bool((_player.get_node("GameMenu") as GameMenu).is_open()).is_false()

	await _driver.press(&"tab_interface")
	_tabs.close_button().pressed.emit()
	assert_bool(_tabs.is_open()).is_false()


func test_input_off_and_mouse_free_while_open_both_restored() -> void:
	await _load()
	var mouse_before := Input.mouse_mode
	var hud := _player.get_node("Hud") as CanvasLayer

	await _driver.press(&"tab_interface")
	assert_bool(_player.accepts_input()).is_false()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_bool(hud.visible).is_false()
	var start := _player.global_position
	await _driver.hold(&"move_forward", 10)
	assert_float(_player.global_position.distance_to(start)).is_less(0.001)

	await _driver.press(&"tab_interface")
	assert_bool(_player.accepts_input()).is_true()
	assert_int(Input.mouse_mode).is_equal(mouse_before)
	assert_bool(hud.visible).is_true()
	await _driver.hold(&"move_forward", 10)
	assert_float(_player.global_position.distance_to(start)).is_greater(0.05)


func test_the_world_keeps_running_while_open() -> void:
	await _load()
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	_driver.runner.scene().add_child(ball)
	ball.global_position = Vector3(3, 6, 0)

	await _driver.press(&"tab_interface")
	var start := ball.global_position.y
	await _driver.frames(20)

	assert_bool(_tabs.is_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_float(ball.global_position.y).is_less(start - 0.3)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_tabs = TabInterface.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
