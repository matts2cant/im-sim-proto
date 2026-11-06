extends GdUnitTestSuite
## Integration: walking and sprinting into crates pushes them with a bounded force and never
## launches, scatters or tunnels through them (ADR 0054). Flat floor fixture, player at the origin
## facing -Z; crates spawned after the player is placed.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"

var _driver: PlayerDriver
var _player: Player
var _watch: CrateWatch


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_walking_into_two_crate_column_keeps_it_together() -> void:
	await _assert_column_survives_run_in(false)


func test_sprinting_into_two_crate_column_keeps_it_together() -> void:
	await _assert_column_survives_run_in(true)


func test_walking_into_small_crate_pushes_it_at_most_at_push_max_speed() -> void:
	await _load()
	# Crate face at z = -1.7: a 1.35 m gap (surface to surface) from the capsule, reached in ~0.4 s.
	var crate := _watch.small(_driver.runner.scene(), 0.0, 0.3, -2.0)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	await _hold(&"move_forward", 90)
	await _watch.frames(_tree(), 60)

	print(_watch.summary("push small crate") + " moved %.3f" % _watch.drift(0))
	assert_float(crate.global_position.z).is_less(-2.5)
	assert_float(_watch.peak_speed[0]).is_less(_player.config.push_max_speed + 0.3)
	assert_float(_watch.max_tilt()).is_less(5.0)
	assert_float(_player.global_position.z - crate.global_position.z).is_greater(0.6)


func test_walking_into_large_crate_does_not_move_it() -> void:
	await _load()
	# 60 kg: floor friction (~590 N) is more than the push force.
	var crate := Objects.spawn(_driver.runner.scene(), Objects.LARGE_CRATE, Vector3(0, 0.6, -2.5)) as RigidBody3D
	await _watch.frames(_tree(), 30)
	var start := crate.global_position

	await _hold(&"move_forward", 90)

	assert_float(crate.global_position.distance_to(start)).is_less(0.05)
	assert_float(_player.global_position.z).is_greater(-1.95 + 0.05)


func _assert_column_survives_run_in(sprint: bool) -> void:
	await _load()
	# Column face at z = -2.7: a 2.35 m gap (surface to surface) from the capsule, reached at full speed.
	_watch.column(_driver.runner.scene(), 0.0, -3.0, 2)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	if sprint:
		_driver.runner.simulate_action_press(&"sprint")
	await _hold(&"move_forward", 90)
	_driver.runner.simulate_action_release(&"sprint")
	await _watch.frames(_tree(), 60)

	var bottom := _watch.crates[0]
	var top := _watch.crates[1]
	var offset := Vector2(
		top.global_position.x - bottom.global_position.x, top.global_position.z - bottom.global_position.z
	)
	print(_watch.summary("sprint into column" if sprint else "walk into column") + " top offset %.3f" % offset.length())
	assert_float(_watch.peak_speed[1]).is_less(3.0)
	assert_float(_watch.peak_up_speed[0]).is_less(0.5)
	assert_float(_watch.peak_up_speed[1]).is_less(0.5)
	assert_float(offset.length()).is_less(0.15)
	assert_float(top.global_position.y).is_equal_approx(0.9, 0.05)
	assert_float(_watch.max_tilt()).is_less(5.0)
	# Not tunnelled: still behind the column (capsule radius 0.35 + half crate 0.3).
	assert_float(_player.global_position.z - bottom.global_position.z).is_greater(0.6)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FLOOR))
	_player = _driver.player
	_watch = CrateWatch.new(_player)
	await _driver.settle()


func _hold(action: StringName, count: int) -> void:
	_driver.runner.simulate_action_press(action)
	await _watch.frames(_tree(), count)
	_driver.runner.simulate_action_release(action)


func _tree() -> SceneTree:
	return _player.get_tree()
