extends GdUnitTestSuite
## Integration (ADR 0078): the sliding door in its doorway (tests/objects/fixtures/door_wall.tscn).
## It opens and closes in 0.6 s, blocks sight and bodies while closed, adds 6 m to noise paths only
## while closed, will not close on something in the doorway, is no device itself (remote commands go
## to its controller: door_controller_test.gd), keeps open / locked across save and load, and puts
## its navigation link on the layers its lock state allows.

const Wait := preload("res://tests/helpers/wait.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## Noise source and listener 3 m either side of the doorway (centre to centre), relative to the
## fixture.
const SOURCE := Vector3(0, 0.5, 3)
const LISTENER := Vector3(0, 0.5, -3)

var _helpers: Helpers
var _scene: Node3D
var _entity: StaticBody3D
var _door: Door


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	await Helpers.GuardHelpers.let_old_scenes_go(get_tree())
	_helpers = Helpers.new()
	_scene = auto_free(load(Helpers.WALL).instantiate())
	_scene.position = Helpers.ORIGIN
	add_child(_scene)
	await Wait.frames(get_tree(), 5)
	await _helpers.sync_navigation(_scene)
	_entity = Helpers.door_entity(_scene)
	_door = Door.of(_entity)
	EventLog.clear()


func after_test() -> void:
	_helpers.teardown()


func test_opens_and_closes_in_0_6_seconds() -> void:
	assert_bool(_door.is_open()).is_false()
	assert_bool(_door.open()).is_true()

	await Wait.frames(get_tree(), 18)
	assert_float(_door.openness).is_between(0.4, 0.6)
	await Wait.frames(get_tree(), 24)
	assert_float(_door.openness).is_equal(1.0)
	var panel := _entity.get_node("Panel") as CollisionShape3D
	assert_float(panel.position.x).is_equal_approx(1.3, 0.001)

	assert_bool(_door.close()).is_true()
	await Wait.frames(get_tree(), 42)
	assert_float(_door.openness).is_equal(0.0)
	assert_float(panel.position.x).is_equal_approx(0.0, 0.001)
	assert_array(EventLog.find(&"door.opened")).has_size(1)
	assert_array(EventLog.find(&"door.closed")).has_size(1)


func test_closed_door_blocks_sight_and_open_door_does_not() -> void:
	var from := Helpers.ORIGIN + Vector3(0, 1.5, 2)
	var to := Helpers.ORIGIN + Vector3(0, 1.5, -2)
	var space := _entity.get_world_3d().direct_space_state
	assert_bool(PhysicsLayers.segment_clear(space, from, to)).is_false()

	_door.open()
	await Wait.frames(get_tree(), 45)

	assert_bool(PhysicsLayers.segment_clear(space, from, to)).is_true()


func test_closed_door_adds_6_m_to_noise_paths_and_open_door_does_not() -> void:
	var listener := Fixtures.entity(_scene, "Listener", LISTENER, [Fixtures.receptron(&"noise")])
	await Wait.frames(get_tree(), 2)
	var closed := await _noise_distance(listener)

	_door.open()
	await Wait.frames(get_tree(), 45)
	var open := await _noise_distance(listener)

	# Straight through the doorway when open: 6 m, plus 0.4 m down to the navmesh at each end.
	assert_float(open).is_between(6.5, 7.1)
	assert_float(closed - open).is_equal_approx(6.0, 0.01)


func test_locked_door_still_carries_noise_with_the_6_m() -> void:
	Helpers.add_keypad(_entity, &"vault", "1234")
	Helpers.lock(_entity)
	var listener := Fixtures.entity(_scene, "Listener", LISTENER, [Fixtures.receptron(&"noise")])
	await Wait.frames(get_tree(), 2)

	var distance := await _noise_distance(listener)

	assert_float(distance).is_between(12.5, 13.1)


func test_does_not_close_on_a_body_in_the_doorway() -> void:
	_door.open()
	await Wait.frames(get_tree(), 45)
	var crate := StaticBody3D.new()
	crate.collision_layer = PhysicsLayers.OBJECTS
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	shape.shape = box
	crate.add_child(shape)
	_scene.add_child(crate)
	crate.global_position = Helpers.ORIGIN + Vector3(0, 0.2, 0)
	await Wait.frames(get_tree(), 2)

	assert_bool(_door.close()).is_false()
	await Wait.frames(get_tree(), 10)

	assert_float(_door.openness).is_equal(1.0)
	assert_array(EventLog.find(&"door.blocked")).has_size(1)


func test_a_door_is_not_a_device_and_ignores_commands() -> void:
	# A door without a controller (no wall box) is mechanical: no Device, commands reach nothing.
	assert_object(Device.of(_entity)).is_null()
	assert_object(_door.hardware.controller).is_null()
	await _command(&"command.open")
	assert_bool(_door.is_open()).is_false()
	assert_array(EventLog.find(&"door.command")).is_empty()


func test_fail_safe_electronic_lock_unlocks_the_door_on_power_loss() -> void:
	var power := Powered.new()
	power.name = "Powered"
	_entity.add_child(power)
	ActorState.set_tag(_entity, &"door.fail_safe", true)
	_entity.add_child(ElectronicLock.new())
	Helpers.lock(_entity)
	assert_str(_door.prompt(null)).is_equal("Locked: electronic")

	power.on = false

	assert_bool(_door.is_locked()).is_false()
	# Unlocked, not opened.
	assert_bool(_door.is_open()).is_false()


func test_save_and_load_keep_open_and_locked() -> void:
	Helpers.add_keypad(_entity, &"vault", "1234")
	_door.open()
	await Wait.frames(get_tree(), 45)
	Helpers.lock(_entity)
	var door_state := _door.save_state()
	var lock_state := Lockable.of(_entity).save_state()

	_door.close()
	Lockable.of(_entity).unlock()
	await Wait.frames(get_tree(), 45)
	assert_bool(_door.is_open()).is_false()
	_door.load_state(door_state)
	Lockable.of(_entity).load_state(lock_state)

	assert_bool(_door.is_open()).is_true()
	assert_float(_door.openness).is_equal(1.0)
	assert_bool(_door.is_locked()).is_true()
	assert_bool(_door.is_in_group(LevelSnapshot.GROUP)).is_true()


func test_navigation_link_layers_follow_the_lock() -> void:
	var link := _entity.get_node("NavigationLink3D") as NavigationLink3D
	assert_int(link.navigation_layers).is_equal(AccessLayers.WALK)
	Helpers.add_keycard(_entity, &"vault")

	Helpers.lock(_entity)
	assert_int(link.navigation_layers).is_equal(AccessLayers.LOCKED | AccessLayers.access_layer(&"vault"))
	_door.open()
	assert_int(link.navigation_layers).is_equal(AccessLayers.WALK)
	_door.close()
	assert_int(link.navigation_layers & AccessLayers.WALK).is_equal(0)
	Lockable.of(_entity).unlock()
	assert_int(link.navigation_layers).is_equal(AccessLayers.WALK)


func _command(type: StringName) -> void:
	StimulusSystem.emit(Stimulus.make_contact(type, 1.0, _entity, _scene))
	await Wait.frames(get_tree(), 2)


func _noise_distance(listener: Node3D) -> float:
	EventLog.clear()
	StimulusSystem.emit(Stimulus.make_noise(30.0, Helpers.ORIGIN + SOURCE))
	await Wait.frames(get_tree(), 2)
	var received := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == listener.name
	)
	assert_int(received.size()).is_equal(1)
	if received.is_empty():
		return -1.0
	assert_str(String(received[0].data["propagation"])).is_equal("path")
	return float(received[0].data["distance"])
