extends GdUnitTestSuite
## Integration (ADR 0123, ADR 0124): the player's camera and the recoil climb, in the skill range
## (tests/items/weapons/fixtures/skill_range.tscn: a 12 x 8 m wall moved 15 m in front of the
## player, centre to centre from the player's feet to the wall centre at eye height). Untrained
## assault rifle, a 10-shot spray (trigger held, not pulled).
## - Camera motion 1 (default): the camera turns up with the climb while mouse look (`pitch`) stays
##   where it was, and comes back by itself within 0.5 s of the release.
## - Camera motion 0 (GameSettings, a test profile): the camera does not move at all during the spray,
##   while the bullets keep the whole pattern (they climb as far as with the camera following) and
##   the crosshair moves up with them.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/skill_range.tscn"
const RIFLE: ItemData = preload("res://items/weapons/assault_rifle/assault_rifle_item.tres")
const EYE := 1.65
const FAR := Vector3(0, EYE, -400)
const SHOTS := 10

var _driver: PlayerDriver
var _player: Player
var _hits: Array[Vector3] = []
var _camera_moved: float = 0.0


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	GameSettings.use_path("user://test_settings.cfg")
	_hits.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	GameSettings.use_path(GameSettings.DEFAULT_PATH)


func test_camera_climbs_with_the_spray_and_returns_by_itself() -> void:
	await _load()
	var pitch := _player.pitch
	var climb := await _spray()
	var camera := _player.weapons.eye as Camera3D
	print("MEASURED Untrained rifle 10-shot climb (deg): %.2f up, %.2f right" % [climb.y, climb.x])
	assert_float(climb.y).is_greater(3.0)
	assert_float(_player.pitch).is_equal(pitch)
	var frames := 0
	while absf(rad_to_deg(camera.rotation.x)) > climb.y * 0.1 and frames < 60:
		await _driver.frames(1)
		frames += 1
	print("MEASURED camera 90 %% back after the spray: %.2f s" % (frames / 60.0))
	assert_float(frames / 60.0).is_less(0.5)
	await _driver.frames(30)
	assert_float(camera.rotation.length()).is_less(0.0001)


func test_camera_motion_zero_keeps_the_camera_still_and_the_bullets_on_the_pattern() -> void:
	await _load()
	await _spray()
	var followed_rise := _hits[-1].y - _hits[0].y
	await _driver.frames(60)
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.0)
	_hits.clear()
	var climb := await _spray(true)
	var still_rise := _hits[-1].y - _hits[0].y
	print("MEASURED 10-shot rise at 15 m (m): camera following %.3f, camera still %.3f" % [followed_rise, still_rise])
	assert_float(_camera_moved).is_equal(0.0)
	assert_float(followed_rise).is_greater(0.5)
	# The same pattern (the noise and the cone differ a little between the two sprays).
	assert_float(still_rise).is_between(followed_rise * 0.8, followed_rise * 1.2)
	# The crosshair follows the bullets up the screen instead of the camera.
	assert_float(_player.weapons.aim_offset().y).is_greater(climb.y * 0.8)


# Holds the trigger for SHOTS shots at the wall's centre and returns the climb (degrees) right after
# the last one; the recoil seeded. `watch_camera`: records how far the camera turned (radians).
func _spray(watch_camera: bool = false) -> Vector2:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, Vector3(0, EYE, -15)))
	await _driver.frames(5)
	_player.weapons.settle()
	_player.weapons.seed_rng(31)
	_player.weapons.state().magazine = 30
	_camera_moved = 0.0
	var camera := _player.weapons.eye as Camera3D
	_driver.runner.simulate_action_press(&"fire")
	var frames := 0
	while _hits.size() < SHOTS and frames < 120:
		await _driver.frames(1)
		frames += 1
		if watch_camera:
			_camera_moved = maxf(_camera_moved, camera.rotation.length())
	_driver.runner.simulate_action_release(&"fire")
	var climb := _player.weapons.recoil.offset
	await _driver.frames(1)
	return climb


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind == &"weapon.fired" and not _player.weapons.last_hit.is_empty():
		_hits.append(_player.weapons.last_hit["position"] as Vector3)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	(_driver.runner.find_child("Plate") as Node3D).position = FAR
	(_driver.runner.find_child("Wall") as Node3D).position = Vector3(0, EYE, -15)
	await _driver.settle()
	var inventory := _player.inventory
	inventory.give(RIFLE, 1)
	inventory.give(inventory.catalog.find(RIFLE.weapon.ammo_item), 60)
	inventory.select_slot(0)
	await _driver.frames(2)
	EventLog.entry_added.connect(_on_entry)
