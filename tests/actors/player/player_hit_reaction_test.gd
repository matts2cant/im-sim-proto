extends GdUnitTestSuite
## Integration (ADR 0127): the player's HitReaction (player.tscn, player_hit_reaction.tres) on the
## flat floor fixture. A 5-damage `damage.ballistic` RAY at the player's torso from 4 m in front
## (centre to centre, horizontal) kicks the view up: with camera motion 1 (default) the camera turns
## by the punch and comes back by itself within half a second; with camera motion 0 the camera
## stays still and the crosshair and the shots take the whole punch instead. The player neither
## flinches nor staggers (its tuning turns those off).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	GameSettings.use_path("user://test_hit_reaction_settings.cfg")
	_driver = PlayerDriver.new(scene_runner(FLOOR))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 1.0)
	GameSettings.use_path(GameSettings.DEFAULT_PATH)
	StimulusSystem.clear()


func test_a_hit_kicks_the_camera_up_and_it_returns_by_itself() -> void:
	var camera := _player.weapons.eye as Camera3D
	_hit()
	var kicked := 0.0
	for i in 4:
		await _driver.frames(1)
		kicked = maxf(kicked, rad_to_deg(camera.rotation.x))
	assert_array(EventLog.find(&"actor.hit_reacted")).has_size(1)
	assert_float(kicked).is_greater(0.4)
	# The camera follows the whole punch: nothing of it is left for the crosshair.
	assert_float(_player.weapons.recoil.unfollowed().length()).is_less(0.0001)
	await _driver.frames(30)
	assert_float(camera.rotation.length()).is_less(0.0001)
	var reaction := HitReaction.of(_player)
	assert_bool(reaction.is_flinching() or reaction.is_staggered()).is_false()


func test_with_camera_motion_off_the_crosshair_takes_the_punch() -> void:
	GameSettings.set_value(GameSettings.CAMERA_MOTION, 0.0)
	var camera := _player.weapons.eye as Camera3D
	_hit()
	var moved := 0.0
	var crosshair := 0.0
	for i in 4:
		await _driver.frames(1)
		moved = maxf(moved, camera.rotation.length())
		crosshair = maxf(crosshair, _player.weapons.aim_offset().y)
	assert_float(moved).is_equal(0.0)
	assert_float(crosshair).is_greater(0.4)


func _hit() -> void:
	var target := Hitboxes.of(_player).box(BodyDamageModel.TORSO).global_position
	var origin := target + Vector3(0, 0, -4)
	var ray := Stimulus.make_ray(&"damage.ballistic", 5.0, origin, (target - origin).normalized(), 6.0)
	ray.collision_mask = PhysicsLayers.WEAPON_MASK
	StimulusSystem.emit(ray)
