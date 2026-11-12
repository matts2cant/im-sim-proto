extends GdUnitTestSuite
## Integration (ADR 0128, ADR 0124): the player's camera shake on firing, in the skill range
## (tests/items/weapons/fixtures/skill_range.tscn; its wall 15 m ahead, centre to centre from the
## player's feet). The shotgun, Untrained.
## - Camera motion 1 (default): a shot turns the camera by about the shotgun's shake on top of the
##   recoil climb, and the shake is gone after its time; shots fired while it shakes still leave
##   along the unshaken aim (the holder takes the shake back out).
## - Camera motion 0: the camera does not turn at all (no shake, no climb).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const RANGE := "res://tests/items/weapons/fixtures/skill_range.tscn"
const SHOTGUN: ItemData = preload("res://items/weapons/shotgun/shotgun_item.tres")
const EYE := 1.65

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	GameSettings.use_path("user://test_settings.cfg")


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.use_path(GameSettings.DEFAULT_PATH)


func test_a_shot_shakes_the_camera_and_never_the_shots() -> void:
	await _load()
	var camera := _player.weapons.eye as Camera3D
	var shake := SHOTGUN.weapon.motion
	await _fire()
	var largest := 0.0
	var largest_aim_error := 0.0
	var frames := 0
	while frames < roundi(shake.shake_time * 60.0) + 2:
		var climb := _climb()
		var shaken := Vector2(rad_to_deg(-camera.rotation.y) - climb.x, rad_to_deg(camera.rotation.x) - climb.y)
		largest = maxf(largest, shaken.length())
		largest_aim_error = maxf(largest_aim_error, _aim_error())
		await _driver.frames(1)
		frames += 1
	print("MEASURED shotgun camera shake: %.2f deg (shake_deg %.2f)" % [largest, shake.shake_deg])
	# Seeded, so the direction is fixed: the first sampled frame is already a few frames into the
	# oscillation (0.46 of 0.8 measured), well inside this band and away from its edges.
	assert_float(largest).is_between(shake.shake_deg * 0.35, shake.shake_deg * 1.05)
	assert_float(largest_aim_error).is_less(0.05)
	assert_vector(_player.camera_shake()).is_equal(Vector3.ZERO)


func test_camera_motion_zero_keeps_the_camera_still() -> void:
	await _load()
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.0)
	var camera := _player.weapons.eye as Camera3D
	await _fire()
	var moved := 0.0
	for i in 20:
		moved = maxf(moved, camera.rotation.length())
		await _driver.frames(1)
	assert_float(moved).is_equal(0.0)


# Degrees between where a shot would leave now and the aim without the shake: the head's view turned
# by the recoil climb the camera follows, plus the aim sway.
func _aim_error() -> float:
	var weapons := _player.weapons
	var head := (weapons.eye as Node3D).get_parent() as Node3D
	var climb := _climb()
	var unshaken := head.global_basis * Basis.from_euler(Vector3(deg_to_rad(climb.y), -deg_to_rad(climb.x), 0.0))
	# The sway and the climb the camera does not follow: the aim offset without the shake taken out.
	var expected := -AimModel.swayed(unshaken, weapons.aim_offset() + weapons.eye_shake).z
	var actual := -weapons.aim_transform().basis.z
	return rad_to_deg(expected.angle_to(actual))


# The recoil climb the camera follows now (degrees, x right, y up).
func _climb() -> Vector2:
	return _player.weapons.recoil.offset * _player.weapons.recoil.view_share


func _fire() -> void:
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, Vector3(0, EYE, -15)))
	await _driver.frames(5)
	_player.weapons.settle()
	_player.weapons.view_pivot().settle_motion()
	_player.weapons.seed_rng(17)
	_player.view_shake.rng.seed = 17
	await _driver.hold(&"fire", 2)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(RANGE))
	_player = _driver.player
	await _driver.settle()
	var inventory := _player.inventory
	inventory.give(SHOTGUN, 1)
	inventory.give(inventory.catalog.find(SHOTGUN.weapon.ammo_item), 12)
	inventory.select_slot(0)
	await _driver.frames(2)
