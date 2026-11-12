extends GdUnitTestSuite
## Unit (ADR 0124): GameSettings reads defaults when the profile is missing or corrupt, clamps and
## type-checks values, persists through save and reload, applies volumes to the buses (dB, mute at
## 0), fullscreen and vsync to the display target, and notifies changes. Never the real profile.

const TEST_PATH := "user://test_settings.cfg"


class RecordingDisplay:
	extends GameSettingsDisplay
	var calls: Array[String] = []

	func set_fullscreen(on: bool) -> void:
		calls.append("fullscreen %s" % on)

	func set_vsync(on: bool) -> void:
		calls.append("vsync %s" % on)


var _display: RecordingDisplay
var _changed: Array[StringName] = []


func before_test() -> void:
	_delete_file()
	_display = RecordingDisplay.new()
	GameSettings.display = _display
	GameSettings.use_path(TEST_PATH)
	_display.calls.clear()
	_changed.clear()
	GameSettings.notifier().changed.connect(_on_changed)


func after_test() -> void:
	GameSettings.notifier().changed.disconnect(_on_changed)
	_delete_file()
	GameSettings.display = GameSettingsDisplay.new()
	GameSettings.use_path(GameSettings.DEFAULT_PATH)


func _on_changed(key: StringName) -> void:
	_changed.append(key)


func _delete_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _bus_db(bus: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))


func test_defaults_without_a_profile() -> void:
	assert_bool(GameSettings.path() == TEST_PATH).is_true()
	assert_float(GameSettings.mouse_sensitivity()).is_equal(1.0)
	assert_bool(GameSettings.invert_y()).is_false()
	assert_float(GameSettings.fov()).is_equal(80.0)
	assert_float(GameSettings.camera_motion()).is_equal(1.0)
	assert_float(GameSettings.master_volume()).is_equal(1.0)
	assert_float(GameSettings.effects_volume()).is_equal(1.0)
	assert_float(GameSettings.music_volume()).is_equal(1.0)
	assert_bool(GameSettings.fullscreen()).is_false()
	assert_bool(GameSettings.vsync()).is_true()
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_false()


## A file ConfigFile cannot parse also gives the defaults (load() fails), but the engine prints its
## parse error, which the runner's error scan counts as a failure: this is the garbage that parses.
func test_defaults_when_the_profile_is_corrupt() -> void:
	_write('garbage = 12\n[view]\nfov = "wide"\n[nothing]\nmouse_sensitivity = 2.0\n[controls]\n')

	GameSettings.use_path(TEST_PATH)

	assert_float(GameSettings.fov()).is_equal(80.0)
	assert_float(GameSettings.mouse_sensitivity()).is_equal(1.0)


func test_wrong_types_and_out_of_range_values() -> void:
	_write('[view]\nfov = 150.0\ncamera_motion = "lots"\n[controls]\ninvert_y = 1\nmouse_sensitivity = 0.01\n')

	GameSettings.use_path(TEST_PATH)

	assert_float(GameSettings.fov()).is_equal(100.0)
	assert_float(GameSettings.camera_motion()).is_equal(1.0)
	assert_bool(GameSettings.invert_y()).is_false()
	assert_float(GameSettings.mouse_sensitivity()).is_equal(0.25)


func test_values_persist_through_save_and_reload() -> void:
	GameSettings.set_value(GameSettings.MOUSE_SENSITIVITY, 1.5)
	GameSettings.set_value(GameSettings.INVERT_Y, true)
	GameSettings.set_value(GameSettings.FOV, 95.0)
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.4)
	GameSettings.set_value(GameSettings.MUSIC_VOLUME, 0.3)
	GameSettings.set_value(GameSettings.VSYNC, false)
	assert_bool(GameSettings.is_dirty()).is_true()

	GameSettings.save_if_changed()
	assert_bool(GameSettings.is_dirty()).is_false()
	GameSettings.use_path(TEST_PATH)

	assert_float(GameSettings.mouse_sensitivity()).is_equal_approx(1.5, 0.0001)
	assert_bool(GameSettings.invert_y()).is_true()
	assert_float(GameSettings.fov()).is_equal_approx(95.0, 0.0001)
	assert_float(GameSettings.camera_motion()).is_equal_approx(0.4, 0.0001)
	assert_float(GameSettings.music_volume()).is_equal_approx(0.3, 0.0001)
	assert_bool(GameSettings.vsync()).is_false()


func test_camera_motion_is_returned_clamped() -> void:
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.25)
	assert_float(GameSettings.camera_motion()).is_equal_approx(0.25, 0.0001)

	GameSettings.set_value(GameSettings.CAMERA_MOTION, 3.0)
	assert_float(GameSettings.camera_motion()).is_equal(1.0)


func test_volumes_set_the_bus_levels() -> void:
	GameSettings.set_value(GameSettings.EFFECTS_VOLUME, 0.5)
	GameSettings.set_value(GameSettings.MASTER_VOLUME, 0.25)
	GameSettings.set_value(GameSettings.MUSIC_VOLUME, 0.0)

	assert_float(_bus_db(GameSettings.EFFECTS_BUS)).is_equal_approx(-6.02, 0.01)
	assert_float(_bus_db(GameSettings.MASTER_BUS)).is_equal_approx(-12.04, 0.01)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.MUSIC_BUS))).is_true()
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.EFFECTS_BUS))).is_false()

	# Reloading a missing profile restores full volume.
	GameSettings.use_path(TEST_PATH)
	assert_float(_bus_db(GameSettings.EFFECTS_BUS)).is_equal_approx(0.0, 0.001)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.MUSIC_BUS))).is_false()


func test_display_settings_go_to_the_display() -> void:
	GameSettings.set_value(GameSettings.FULLSCREEN, true)
	GameSettings.set_value(GameSettings.VSYNC, false)

	assert_array(_display.calls).contains_exactly(["fullscreen true", "vsync false"])


func test_loading_applies_the_display_settings() -> void:
	assert_array(_display.calls).is_empty()

	GameSettings.use_path(TEST_PATH)

	assert_array(_display.calls).contains_exactly(["fullscreen false", "vsync true"])


func test_changes_notify_once_and_only_real_changes() -> void:
	GameSettings.set_value(GameSettings.FOV, 90.0)
	GameSettings.set_value(GameSettings.FOV, 90.0)
	GameSettings.set_value(GameSettings.INVERT_Y, false)

	assert_array(_changed).contains_exactly([GameSettings.FOV])
