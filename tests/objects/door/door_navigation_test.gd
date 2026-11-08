extends GdUnitTestSuite
## Integration (ADR 0078): a guard (DoorOpener) walking from z = 4 to z = -4 through the doorway of
## tests/objects/fixtures/door_wall_guard.tscn (the wall spans the whole floor: the door is the only
## way). It paths through a closed unlocked door and opens it on the way; a locked door blocks its
## path; a locked door whose keycard lock it has access to (`access.vault`) lets it through, still
## locked.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const TARGET := Vector3(0, 0, -4)

var _guards: GuardHelpers
var _entity: StaticBody3D
var _door: Door


func before_test() -> void:
	await GuardHelpers.let_old_scenes_go(get_tree())
	_guards = GuardHelpers.new()
	await _guards.setup(scene_runner(Helpers.WALL_GUARD))
	_entity = Helpers.door_entity(_guards.scene)
	_door = Door.of(_entity)


func after_test() -> void:
	_guards.teardown()


func test_guard_paths_through_an_unlocked_door_and_opens_it() -> void:
	await _walk_to_target(9.0)

	assert_float(_guards.guard.global_position.z).is_less(-3.0)
	assert_bool(_door.is_open()).is_true()
	var opened := EventLog.find(&"door.opened")
	assert_array(opened).has_size(1)
	assert_str(opened[0].source).is_equal("Guard")


func test_locked_door_blocks_the_guards_path() -> void:
	Helpers.add_keypad(_entity, &"vault", "1234")
	Helpers.lock(_entity)
	await _guards.frames(2)

	await _walk_to_target(9.0)

	assert_float(_guards.guard.global_position.z).is_greater(0.3)
	assert_bool(_door.is_open()).is_false()
	assert_array(EventLog.find(&"door.opened")).is_empty()


func test_guard_with_access_passes_a_locked_keycard_door() -> void:
	Helpers.add_keycard(_entity, &"vault")
	Helpers.lock(_entity)
	ActorState.set_tag(_guards.guard, &"access.vault", true)
	await _guards.frames(2)
	assert_int(_guards.guard.agent.navigation_layers & AccessLayers.access_layer(&"vault")).is_not_equal(0)

	await _walk_to_target(9.0)

	assert_float(_guards.guard.global_position.z).is_less(-3.0)
	assert_bool(_door.is_locked()).is_true()


func _walk_to_target(seconds: float) -> void:
	_guards.guard.take_control(self)
	_guards.guard.move_to(TARGET, 1.8)
	await _guards.seconds(seconds)
