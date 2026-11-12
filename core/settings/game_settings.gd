class_name GameSettings
extends RefCounted
## The player's profile settings (ADR 0124): controls, view, audio and display, stored in
## `user://settings.cfg` (ConfigFile), never in save games. Static API, no autoload.
##
## Loaded on first use (any getter, or ensure_loaded(); the Player reads the FOV in its _ready, so
## every level start loads it) and applied at once: bus volumes go to the AudioServer, fullscreen and
## vsync to `display`. set_value() applies a change live and marks the profile dirty;
## save_if_changed() writes it (the Settings screen does on leaving). A missing or unreadable file,
## or a value of the wrong type, gives the default; numbers are clamped to their range.
##
## Change notification: notifier().changed(key) after every live change. Consumers that only read a
## value now and then call the getter each time (the player's look reads the sensitivity per mouse
## event); consumers that must react while the game is paused (the player's camera FOV) connect to it.
##
## Tests: use_path("user://test_settings.cfg") switches the file and reloads; after_test switches
## back with use_path(DEFAULT_PATH). tools/run_tests.sh gives every shard its own user:// (APPDATA),
## so suites never read the developer's real profile.

const DEFAULT_PATH := "user://settings.cfg"

const MASTER_BUS: StringName = &"Master"
## Every sound in the game today (default_bus_layout.tres).
const EFFECTS_BUS: StringName = &"Effects"
## Music (none yet).
const MUSIC_BUS: StringName = &"Music"

## Multiplier on the player config's mouse sensitivity (rad per pixel).
const MOUSE_SENSITIVITY: StringName = &"mouse_sensitivity"
const INVERT_Y: StringName = &"invert_y"
## Vertical field of view at the hip, degrees (a scope's own FOV stays fixed).
const FOV: StringName = &"fov"
## 0..1: scales shake, bob and the camera's recoil climb (never the bullets).
const CAMERA_MOTION: StringName = &"camera_motion"
## Linear bus volumes 0..1.
const MASTER_VOLUME: StringName = &"master_volume"
const EFFECTS_VOLUME: StringName = &"effects_volume"
const MUSIC_VOLUME: StringName = &"music_volume"
const FULLSCREEN: StringName = &"fullscreen"
const VSYNC: StringName = &"vsync"

const DEFAULTS: Dictionary[StringName, Variant] = {
	MOUSE_SENSITIVITY: 1.0,
	INVERT_Y: false,
	FOV: 80.0,
	CAMERA_MOTION: 1.0,
	MASTER_VOLUME: 1.0,
	EFFECTS_VOLUME: 1.0,
	MUSIC_VOLUME: 1.0,
	FULLSCREEN: false,
	VSYNC: true,
}
## Allowed range of each number (inclusive).
const RANGES: Dictionary[StringName, Vector2] = {
	MOUSE_SENSITIVITY: Vector2(0.25, 3.0),
	FOV: Vector2(70.0, 100.0),
	CAMERA_MOTION: Vector2(0.0, 1.0),
	MASTER_VOLUME: Vector2(0.0, 1.0),
	EFFECTS_VOLUME: Vector2(0.0, 1.0),
	MUSIC_VOLUME: Vector2(0.0, 1.0),
}
## ConfigFile section of each key.
const SECTIONS: Dictionary[StringName, String] = {
	MOUSE_SENSITIVITY: "controls",
	INVERT_Y: "controls",
	FOV: "view",
	CAMERA_MOTION: "view",
	MASTER_VOLUME: "audio",
	EFFECTS_VOLUME: "audio",
	MUSIC_VOLUME: "audio",
	FULLSCREEN: "display",
	VSYNC: "display",
}
## Bus of each volume key.
const VOLUME_BUSES: Dictionary[StringName, StringName] = {
	MASTER_VOLUME: MASTER_BUS,
	EFFECTS_VOLUME: EFFECTS_BUS,
	MUSIC_VOLUME: MUSIC_BUS,
}

## Applies fullscreen and vsync; tests replace it with a recording stand-in.
static var display: GameSettingsDisplay = GameSettingsDisplay.new()

static var _path: String = DEFAULT_PATH
static var _values: Dictionary[StringName, Variant] = {}
static var _loaded: bool = false
static var _dirty: bool = false
static var _notifier: Notifier = Notifier.new()


## Emits changed(key) after set_value() changed a setting.
class Notifier:
	extends RefCounted
	signal changed(key: StringName)


static func notifier() -> Notifier:
	return _notifier


static func path() -> String:
	return _path


## Switches the profile file and reloads from it (tests; DEFAULT_PATH switches back).
static func use_path(file_path: String) -> void:
	_path = file_path
	load_profile()


static func ensure_loaded() -> void:
	if not _loaded:
		load_profile()


## Reads the profile (defaults for anything missing or invalid) and applies every setting.
static func load_profile() -> void:
	_values = DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if FileAccess.file_exists(_path) and file.load(_path) == OK:
		for key: StringName in DEFAULTS:
			var raw: Variant = file.get_value(SECTIONS[key], key, null)
			if raw != null:
				_values[key] = _sanitize(key, raw)
	_loaded = true
	_dirty = false
	for key: StringName in DEFAULTS:
		_apply(key)


## Writes every setting to the profile file.
static func save_profile() -> Error:
	ensure_loaded()
	var file := ConfigFile.new()
	for key: StringName in DEFAULTS:
		file.set_value(SECTIONS[key], key, _values[key])
	var error := file.save(_path)
	if error == OK:
		_dirty = false
	return error


static func save_if_changed() -> void:
	if _dirty:
		save_profile()


static func is_dirty() -> bool:
	return _dirty


static func value(key: StringName) -> Variant:
	ensure_loaded()
	return _values.get(key)


## Sets one setting (clamped), applies it live and emits notifier().changed; saved later by
## save_if_changed(). Unknown keys are ignored.
static func set_value(key: StringName, new_value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("GameSettings: unknown setting %s" % key)
		return
	ensure_loaded()
	var clean: Variant = _sanitize(key, new_value)
	if clean == _values[key]:
		return
	_values[key] = clean
	_dirty = true
	_apply(key)
	_notifier.changed.emit(key)


## Multiplier on the config's mouse sensitivity (1 = the tuned default).
static func mouse_sensitivity() -> float:
	return float(value(MOUSE_SENSITIVITY))


static func invert_y() -> bool:
	return bool(value(INVERT_Y))


## Hip field of view in degrees (70..100).
static func fov() -> float:
	return float(value(FOV))


## 0..1: how much of the camera's motion (shake, bob, recoil climb) to show.
static func camera_motion() -> float:
	return float(value(CAMERA_MOTION))


static func master_volume() -> float:
	return float(value(MASTER_VOLUME))


static func effects_volume() -> float:
	return float(value(EFFECTS_VOLUME))


static func music_volume() -> float:
	return float(value(MUSIC_VOLUME))


static func fullscreen() -> bool:
	return bool(value(FULLSCREEN))


static func vsync() -> bool:
	return bool(value(VSYNC))


static func _sanitize(key: StringName, raw: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if fallback is bool:
		return raw if raw is bool else fallback
	if not (raw is float or raw is int):
		return fallback
	var number := float(raw)
	if is_nan(number) or is_inf(number):
		return fallback
	var bounds: Vector2 = RANGES[key]
	return clampf(number, bounds.x, bounds.y)


static func _apply(key: StringName) -> void:
	if VOLUME_BUSES.has(key):
		_apply_volume(VOLUME_BUSES[key], _values[key])
	elif key == FULLSCREEN:
		display.set_fullscreen(_values[key])
	elif key == VSYNC:
		display.set_vsync(_values[key])


static func _apply_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
