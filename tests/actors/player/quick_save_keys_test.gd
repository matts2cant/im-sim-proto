extends GdUnitTestSuite
## Integration: F5 / F9 (QuickSaveKeys on the player) with real key events on a small level made
## the current scene: messages, refusals (dead, pause screen), quickload from the death screen and
## from a pause screen, bad slot files.

const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const LEVEL := "res://tests/actors/player/fixtures/flat_floor.tscn"
const SPOT := Vector3(1.5, 0.0, -2.0)

var _original: Node
var _level: Node


func before_test() -> void:
	_original = get_tree().current_scene
	Saves.use_test_slot()
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)
	_level = await Saves.open_level(get_tree(), LEVEL)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)


func _player(level: Node = _level) -> Player:
	return level.get_node("Player") as Player


func _message(level: Node = _level) -> String:
	return (_player(level).get_node("Hud") as Hud).message_label.text


func _place(position: Vector3) -> void:
	_player().load_state({"position": position, "yaw": 0.5, "pitch": 0.0, "velocity": Vector3.ZERO})
	for i in 3:
		await get_tree().physics_frame


func _kill() -> void:
	_player().body.take_damage(&"damage.blunt", 1000.0, &"head")
	await get_tree().physics_frame


func test_f5_quicksaves() -> void:
	Saves.press(KEY_F5)
	await get_tree().process_frame

	assert_bool(FileAccess.file_exists(Saves.SLOT)).is_true()
	assert_str(_message()).is_equal(QuickSaveKeys.SAVED)
	assert_array(EventLog.find(&"game.saved")).has_size(1)


func test_f9_without_a_quicksave_says_so() -> void:
	Saves.press(KEY_F9)
	await get_tree().process_frame

	assert_str(_message()).is_equal(QuickSaveKeys.NO_SAVE)
	assert_object(get_tree().current_scene).is_same(_level)
	assert_bool(QuickSave.is_loading()).is_false()


func test_f5_is_refused_while_dead() -> void:
	await _kill()
	assert_bool(_player().is_dead()).is_true()

	Saves.press(KEY_F5)
	await get_tree().process_frame

	assert_bool(FileAccess.file_exists(Saves.SLOT)).is_false()
	assert_array(EventLog.find(&"game.saved")).is_empty()


func test_f5_is_refused_while_a_pause_screen_is_open() -> void:
	var screen := _player().get_node("InventoryScreen") as InventoryScreen
	screen.open()

	var keys := _player().get_node("QuickSaveKeys") as QuickSaveKeys
	assert_bool(keys.quicksave()).is_false()
	screen.close()
	assert_bool(keys.quicksave()).is_true()


func test_f9_from_the_death_screen_loads_the_quicksave() -> void:
	await _place(SPOT)
	var saved := _player().global_position
	Saves.press(KEY_F5)
	await get_tree().process_frame
	await _place(Vector3(-2, 0, 2))
	await _kill()
	assert_bool((_player().get_node("Hud") as Hud).death_overlay.visible).is_true()

	Saves.press(KEY_F9)
	var fresh := await Saves.wait_for_load(get_tree(), _level)

	assert_object(fresh).is_not_null()
	var player := _player(fresh)
	assert_bool(player.is_dead()).is_false()
	assert_vector(player.global_position).is_equal_approx(saved, Vector3.ONE * 0.01)
	assert_bool((player.get_node("Hud") as Hud).death_overlay.visible).is_false()
	assert_str(_message(fresh)).is_equal(QuickSaveKeys.LOADED)
	assert_array(EventLog.find(&"game.loaded")).has_size(1)
	assert_int(StimulusSystem.pending_count()).is_equal(0)


func test_f9_works_from_a_pause_screen() -> void:
	await _place(SPOT)
	var saved := _player().global_position
	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	(_player().get_node("InventoryScreen") as InventoryScreen).open()
	assert_bool(get_tree().paused).is_true()

	Saves.press(KEY_F9)
	var fresh := await Saves.wait_for_load(get_tree(), _level)

	assert_object(fresh).is_not_null()
	assert_bool(get_tree().paused).is_false()
	assert_bool(PauseScreens.any_open(get_tree())).is_false()
	assert_vector(_player(fresh).global_position).is_equal_approx(saved, Vector3.ONE * 0.01)


func test_a_corrupt_quicksave_is_reported_and_not_loaded() -> void:
	Saves.write_slot("{ this is not a save")

	Saves.press(KEY_F9)
	await get_tree().process_frame

	assert_str(_message()).is_equal(QuickSaveKeys.MESSAGES[SaveFile.Status.CORRUPT])
	assert_object(get_tree().current_scene).is_same(_level)


func test_a_quicksave_of_another_version_is_reported_and_not_loaded() -> void:
	var data := {"version": SaveFile.VERSION + 1, "level": LEVEL, "saved_at": "x"}
	data.merge({"states": {}, "removed": [], "spawned": {}})
	Saves.write_slot(SaveFile.encode(data))

	Saves.press(KEY_F9)
	await get_tree().process_frame

	assert_str(_message()).is_equal(QuickSaveKeys.MESSAGES[SaveFile.Status.WRONG_VERSION])
	assert_object(get_tree().current_scene).is_same(_level)
	assert_int(await QuickSave.load_game(get_tree())).is_equal(SaveFile.Status.WRONG_VERSION)
