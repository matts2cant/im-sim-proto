extends GdUnitTestSuite
## Integration: the player standing on, jumping on, landing on, walking over and mantling onto
## stacks of small crates (0.6 m, 10 kg) leaves them in place (ADR 0054). Flat floor fixture,
## player facing -Z. Crates are spawned after the player is placed: a placement is a teleport.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const FLOOR := "res://tests/actors/player/fixtures/flat_floor.tscn"
## Frames between jump presses on a crate: the jump lasts 2 x 6.26 / 19.6 s = 0.64 s = 38 frames.
const JUMP_PERIOD := 60

var _driver: PlayerDriver
var _player: Player
var _watch: CrateWatch


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_jumping_in_place_on_one_crate() -> void:
	await _assert_jumps_in_place(1)


func test_jumping_in_place_on_two_crate_column() -> void:
	await _assert_jumps_in_place(2)


func test_landing_on_crate_from_one_metre_drop() -> void:
	await _load()
	# Feet 1.0 m above the crate top (0.6 m).
	await _stand_then_spawn_column(Vector3(0, 1.6, -2), -2.0, 1)

	await _watch.frames(_tree(), 90)

	print(_watch.summary("land from 1 m drop"))
	assert_float(_player.global_position.y).is_equal_approx(0.6, 0.03)
	assert_bool(_player.is_on_floor()).is_true()
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(2.0)


func test_jumping_from_floor_onto_crate() -> void:
	await _load()
	# Capsule front 0.45 m (gap, surface to surface) from the crate face at z = -1.7.
	await _driver.place(Vector3(0, 0, -0.9))
	_watch.column(_driver.runner.scene(), 0.0, -2.0, 1)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	# Forward for 8 frames (~2.3 m/s with air control), jump on the first: lands near the crate centre.
	_driver.runner.simulate_action_press(&"move_forward")
	_driver.runner.simulate_action_press(&"jump")
	await _watch.frames(_tree(), 3)
	_driver.runner.simulate_action_release(&"jump")
	await _watch.frames(_tree(), 5)
	_driver.runner.simulate_action_release(&"move_forward")
	await _watch.frames(_tree(), 90)

	print(_watch.summary("jump onto crate") + " z %.3f" % _player.global_position.z)
	assert_float(_player.global_position.y).is_equal_approx(0.6, 0.03)
	assert_float(_player.global_position.z).is_between(-2.3, -1.7)
	assert_float(_watch.player_high).is_equal_approx(1.0, 0.15)
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(2.0)


func test_walking_across_top_of_column() -> void:
	await _load()
	# On the back half of a 2-crate column (top at 1.2 m); walks forward and steps off the front.
	await _stand_then_spawn_column(Vector3(0, 1.21, -2.15), -2.0, 2)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	await _hold(&"move_forward", 60)
	await _watch.frames(_tree(), 60)

	print(_watch.summary("walk across top"))
	assert_float(_player.global_position.z).is_less(-3.0)
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(0.5)


func test_jumping_back_and_forth_on_top_of_column() -> void:
	await _load()
	# On the back half of the top (0.15 m behind its centre).
	var top := await _stand_then_spawn_column(Vector3(0, 1.21, -1.85), -2.0, 2)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	# Hops forward then back with one tick of move input on the take-off: 0.67 m/s for the 0.64 s
	# jump = 0.43 m, between the back and front halves of the 0.6 m top.
	for i in 4:
		var direction := &"move_forward" if i % 2 == 0 else &"move_back"
		_driver.runner.simulate_action_press(direction)
		_driver.runner.simulate_action_press(&"jump")
		await _watch.frames(_tree(), 1)
		_driver.runner.simulate_action_release(direction)
		await _watch.frames(_tree(), 2)
		_driver.runner.simulate_action_release(&"jump")
		await _watch.frames(_tree(), JUMP_PERIOD)

	print(_watch.summary("hop on top") + " z %.3f" % _player.global_position.z)
	assert_array(EventLog.find(&"actor.landed")).has_size(4)
	assert_float(_watch.player_low).is_greater(top - 0.05)
	assert_float(_player.global_position.y).is_equal_approx(top, 0.03)
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(1.0)


func test_mantling_onto_column_while_holding_forward() -> void:
	await _load()
	# Column face at z = -0.7: 0.35 m gap (surface to surface) from the capsule, within mantle reach.
	_watch.column(_driver.runner.scene(), 0.0, -1.0, 2)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	_driver.runner.simulate_action_press(&"move_forward")
	await _hold(&"jump", 40)
	await _watch.frames(_tree(), 10)
	_driver.runner.simulate_action_release(&"move_forward")
	await _watch.frames(_tree(), 60)

	print(_watch.summary("mantle onto column"))
	assert_array(EventLog.find(&"player.mantled")).has_size(1)
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(1.0)


func test_teleporting_through_column_leaves_it_alone() -> void:
	await _load()
	_watch.column(_driver.runner.scene(), 0.0, -2.0, 2)
	await _watch.frames(_tree(), 30)
	_watch.reset()

	# A load or respawn moves the body in one tick straight through the column.
	_player.load_state(PlayerDriver.state(Vector3(0, 0, -4), 0.0))
	await _watch.frames(_tree(), 30)

	print(_watch.summary("teleport through column"))
	assert_float(_watch.max_drift()).is_less(0.01)
	assert_float(_watch.max_peak_speed()).is_less(0.1)
	assert_array(EventLog.find(&"object.broken")).is_empty()


func _assert_jumps_in_place(count: int) -> void:
	await _load()
	var top := await _stand_then_spawn_column(Vector3(0, count * 0.6 + 0.01, -2), -2.0, count)
	await _watch.frames(_tree(), 30)
	assert_float(_player.global_position.y).is_equal_approx(top, 0.02)
	_watch.reset()

	for i in 5:
		await _hold(&"jump", 3)
		await _watch.frames(_tree(), JUMP_PERIOD)

	print(_watch.summary("jump x5 on %d crate(s)" % count))
	assert_array(EventLog.find(&"actor.landed")).has_size(5)
	assert_float(_player.global_position.y).is_equal_approx(top, 0.02)
	# Never sinks into the crate; the apex is the 1.0 m jump above the crate top.
	assert_float(_watch.player_low).is_greater(top - 0.05)
	assert_float(_watch.player_high - top).is_equal_approx(1.0, 0.15)
	assert_float(_watch.max_drift()).is_less(0.05)
	assert_float(_watch.max_peak_speed()).is_less(2.0)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(FLOOR))
	_player = _driver.player
	_watch = CrateWatch.new(_player)
	await _driver.settle()


# Puts the player at `feet` and, one tick later (once the teleport is done), a column of `count`
# small crates at (feet.x, column_z) under it. Returns the column top.
func _stand_then_spawn_column(feet: Vector3, column_z: float, count: int) -> float:
	_player.load_state(PlayerDriver.state(feet, 0.0))
	await _driver.frames(1)
	var top := _watch.column(_driver.runner.scene(), feet.x, column_z, count)
	EventLog.clear()
	return top


func _hold(action: StringName, count: int) -> void:
	_driver.runner.simulate_action_press(action)
	await _watch.frames(_tree(), count)
	_driver.runner.simulate_action_release(action)


func _tree() -> SceneTree:
	return _player.get_tree()
