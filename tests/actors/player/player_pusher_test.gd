extends GdUnitTestSuite
## Integration: PlayerPusher finds the bodies under the feet and the bodies walked into (ADR 0054).
## The player stands on crate A (top 0.6 m); in front (-Z) crate C on the floor carries crate B,
## whose face is a 0.01 m gap (surface to surface) from the capsule.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"

var _driver: PlayerDriver
var _player: Player
var _pusher: PlayerPusher
var _a: RigidBody3D
var _b: RigidBody3D
var _c: RigidBody3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	_driver = PlayerDriver.new(scene_runner(FLOOR))
	_player = _driver.player
	await _driver.settle()
	_player.load_state(PlayerDriver.state(Vector3(0, 0.61, -2), 0.0))
	await _driver.frames(1)
	var watch := CrateWatch.new()
	var scene := _driver.runner.scene()
	_a = watch.small(scene, 0.0, 0.3, -2.0)
	# Centres 0.66 m from A: B's face at z = -2.36, the capsule front at -2.35.
	_c = watch.small(scene, 0.0, 0.3, -2.66)
	_b = watch.small(scene, 0.0, 0.9, -2.66)
	await _driver.frames(20)
	_pusher = PlayerPusher.new(_player, _player.config)


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_finds_only_the_crate_underfoot() -> void:
	assert_bool(_player.is_on_floor()).is_true()
	var under := _pusher.bodies_underfoot(_player.global_position, [_player.get_rid()])
	assert_array(under).contains_exactly([_a])


func test_finds_crate_walked_into_above_the_feet() -> void:
	var ahead := _ahead(Vector3.FORWARD, [_player.get_rid()])
	# Not A (stood on) nor C (its top is level with the feet).
	assert_array(ahead).contains_exactly([_b])


func test_finds_nothing_when_walking_away() -> void:
	assert_array(_ahead(Vector3.BACK, [_player.get_rid()])).is_empty()


func test_excluded_bodies_are_left_alone() -> void:
	assert_array(_ahead(Vector3.FORWARD, [_player.get_rid(), _b.get_rid()])).is_empty()


func test_walking_into_crate_on_crate_moves_only_the_top_one() -> void:
	var start_b := _b.global_position
	var start_c := _c.global_position
	await _driver.hold(&"move_forward", 20)

	assert_float(start_b.z - _b.global_position.z).is_greater(0.1)
	assert_float(_c.global_position.distance_to(start_c)).is_less(0.02)
	assert_float(_a.global_position.distance_to(Vector3(0, 0.3, -2))).is_less(0.02)


func _ahead(direction: Vector3, exclude: Array[RID]) -> Array[RigidBody3D]:
	return _pusher.bodies_ahead(_player.global_position, _player.capsule_height(), direction, exclude)
