extends GdUnitTestSuite
## Integration (ADR 0124): the Settings screen nested in the Esc menu, with the real player on a
## small level and real key events: it opens from the Esc menu (still paused), Esc and Back return
## to the Esc menu (still paused), the next Esc resumes; its controls change the settings live
## (FOV moves the player's camera while paused, sensitivity scales the look, invert Y flips it) and
## the profile is written on leaving. Uses a test profile, never the real one.

const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const LEVEL := "res://tests/actors/player/fixtures/flat_floor.tscn"
const TEST_PATH := "user://test_settings.cfg"

var _original: Node
var _level: Node


func before_test() -> void:
	_original = get_tree().current_scene
	_delete_profile()
	GameSettings.use_path(TEST_PATH)
	Saves.use_test_slot()
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)
	_level = await Saves.open_level(get_tree(), LEVEL, 4)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	_delete_profile()
	GameSettings.use_path(GameSettings.DEFAULT_PATH)


func _delete_profile() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _player() -> Player:
	return _level.get_node("Player") as Player


func _menu() -> GameMenu:
	return _player().get_node("GameMenu") as GameMenu


func _press(key: Key) -> void:
	Saves.press(key)
	await get_tree().process_frame


func _open_settings() -> SettingsMenu:
	await _press(KEY_ESCAPE)
	_menu().settings_button.pressed.emit()
	return _menu().settings_menu


func test_opens_from_the_esc_menu_and_esc_returns_to_it() -> void:
	var settings := await _open_settings()

	assert_bool(_menu().is_in_settings()).is_true()
	assert_bool(_menu().panel.visible).is_false()
	assert_bool(get_tree().paused).is_true()
	assert_bool(settings.first_control().has_focus()).is_true()

	await _press(KEY_ESCAPE)

	assert_bool(_menu().is_open()).is_true()
	assert_bool(_menu().is_in_settings()).is_false()
	assert_bool(_menu().panel.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(_menu().settings_button.has_focus()).is_true()

	await _press(KEY_ESCAPE)

	assert_bool(_menu().is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_back_returns_to_the_esc_menu_and_saves_the_profile() -> void:
	var settings := await _open_settings()
	settings.slider(GameSettings.MASTER_VOLUME).value = 40.0
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()

	settings.back_button.pressed.emit()

	assert_bool(_menu().is_open()).is_true()
	assert_bool(_menu().is_in_settings()).is_false()
	assert_bool(get_tree().paused).is_true()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_true()
	GameSettings.use_path(TEST_PATH)
	assert_float(GameSettings.master_volume()).is_equal_approx(0.4, 0.0001)


func test_the_screen_shows_the_current_settings() -> void:
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.35)
	GameSettings.set_value(GameSettings.VSYNC, false)

	var settings := await _open_settings()

	assert_float(settings.slider(GameSettings.CAMERA_MOTION).value).is_equal_approx(35.0, 0.001)
	assert_str(settings.value_text(GameSettings.CAMERA_MOTION)).is_equal("35 %")
	assert_str(settings.value_text(GameSettings.FOV)).is_equal("80°")
	assert_bool(settings.toggle(GameSettings.VSYNC).button_pressed).is_false()
	assert_bool(settings.toggle(GameSettings.FULLSCREEN).button_pressed).is_false()


func test_fov_slider_moves_the_camera_while_paused() -> void:
	var settings := await _open_settings()
	var camera := _player().get_node("Head/Camera") as Camera3D

	settings.slider(GameSettings.FOV).value = 95.0

	assert_float(GameSettings.fov()).is_equal(95.0)
	assert_float(camera.fov).is_equal_approx(95.0, 0.001)
	assert_float(_player().fov_ratio()).is_equal_approx(1.0, 0.0001)


func test_sensitivity_and_invert_y_change_the_look() -> void:
	var settings := await _open_settings()
	settings.slider(GameSettings.MOUSE_SENSITIVITY).value = 2.0
	settings.toggle(GameSettings.INVERT_Y).button_pressed = true
	settings.back_button.pressed.emit()
	await _press(KEY_ESCAPE)
	var player := _player()
	player.rotation.y = 0.0
	player.pitch = 0.0

	player.look(Vector2(100, 50))

	assert_float(player.rotation.y).is_equal_approx(-100 * CONFIG.mouse_sensitivity * 2.0, 0.0001)
	# Mouse down (positive y) looks up with invert Y.
	assert_float(player.pitch).is_equal_approx(50 * CONFIG.mouse_sensitivity * 2.0, 0.0001)
