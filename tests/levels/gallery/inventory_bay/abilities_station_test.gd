extends GdUnitTestSuite
## Integration in the real inventory bay (inside the hub) with the player: the abilities station.
## The 2.3 m ledge is refused without Speed Enhancement and mantled with it (F3); the dais biocells
## (x10) are picked up with E; the 60 kg crate is lifted only with Combat Strength on (F5); sprinting
## along the metal strip makes metal footsteps, none with Run Silent (F2).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
## Room-local feet 0.6 m (centre to face) in front of the Speed ledge's lip (z -17.5).
const LEDGE_FOOT := Vector3(-5.1, 0, -16.9)
const LEDGE_TOP := Vector3(-5.1, 2.3, -18.6)
## Room-local start of the Run Silent strip (z -6 to -14 at x -3.4), and a point down it.
const STRIP_START := Vector3(-3.4, 0.02, -6.4)
const STRIP_END := Vector3(-3.4, 1.65, -14.0)

var _driver: PlayerDriver
var _player: Player
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_speed_ledge_is_refused_without_speed_and_mantled_with_it() -> void:
	await _load_hub()
	await _face(LEDGE_FOOT, LEDGE_TOP)

	await _driver.hold(&"jump", 40)
	await _driver.frames(40)
	assert_array(EventLog.find(&"player.mantled")).is_empty()
	assert_float(_local_feet().y).is_less(0.1)

	await _face(LEDGE_FOOT, LEDGE_TOP)
	await _driver.press(&"aug_3")
	await _driver.hold(&"jump", 40)
	await _driver.frames(30)

	assert_array(EventLog.find(&"player.mantled")).has_size(1)
	assert_float(_local_feet().y).is_equal_approx(2.3, 0.05)


func test_dais_biocells_are_ten_in_one_pickup() -> void:
	await _load_hub()
	var biocells := _room.get_node("AbilitiesDais/Biocells") as RigidBody3D
	await _driver.frames(30)
	assert_float(_room.to_local(biocells.global_position).y).is_between(0.3, 0.4)
	await _face(Vector3(-2.15, 0.3, -17.6), _room.to_local(biocells.global_position))

	await _driver.press(&"use")

	assert_int(_player.inventory.inventory.count_of(&"biocell")).is_equal(10)


func test_heavy_crate_needs_combat_strength() -> void:
	await _load_hub()
	var crate := _room.get_node("AbilitiesDais/LargeCrate") as RigidBody3D
	await _face(Vector3(5.2, 0, -16.9), _room.to_local(crate.global_position))

	await _driver.press(&"use")
	assert_bool(_player.carry.is_carrying()).is_false()
	assert_array(EventLog.find(&"player.pickup_refused")).has_size(1)

	await _driver.press(&"aug_5")
	await _driver.press(&"use")
	assert_object(_player.carry.held).is_same(crate)


func test_run_silent_strip_footsteps_are_metal_and_silenced_by_run_silent() -> void:
	await _load_hub()
	await _face(STRIP_START, STRIP_END)
	await _sprint(60)
	var loud := _player_steps()
	assert_array(loud).is_not_empty()
	for step in loud:
		assert_str(String(step.data["surface"])).is_equal("metal")

	await _face(STRIP_START, STRIP_END)
	await _driver.press(&"aug_2")
	EventLog.clear()
	await _sprint(60)

	assert_array(_player_steps()).is_empty()


func _local_feet() -> Vector3:
	return _room.to_local(_player.global_position)


# Stands the player at room-local `feet` looking at room-local `target`; clears the log.
func _face(feet: Vector3, target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, _room.to_global(feet), _room.to_global(target)))
	await _driver.frames(5)
	StimulusSystem.clear()
	EventLog.clear()


func _sprint(frames: int) -> void:
	_driver.runner.simulate_action_press(&"sprint")
	_driver.runner.simulate_action_press(&"move_forward")
	await _driver.frames(frames)
	_driver.runner.simulate_action_release(&"move_forward")
	_driver.runner.simulate_action_release(&"sprint")
	await _driver.frames(5)


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_player = _driver.player
	_room = _driver.runner.find_child("InventoryBayRoom") as Node3D
	await _driver.settle()
	EventLog.clear()


# The player's own footsteps: the hub's guards log theirs too (EventLog source = body name).
func _player_steps() -> Array[EventLogEntry]:
	var steps: Array[EventLogEntry] = []
	for step in EventLog.find(&"actor.footstep"):
		if step.source == String(_player.name):
			steps.append(step)
	return steps
