extends GdUnitTestSuite
## Scenario across M8a and M8b (ADR 0077, ADR 0078, ADR 0130): a console device cabled through a
## rack switch (`objects/network/switch_rack.tscn`) to a locked door's controller
## (`objects/door/door_controller.tscn` under the door's hardware) sends `command.unlock` and
## `command.open` with Device.send_command(). They work while the controller is reached; they do not
## when the switch is unpowered, the controller is unpowered, or nothing is cabled; a broken door
## stays open whatever its controller is told.

const DeviceFixtures := preload("res://tests/objects/devices/device_fixtures.gd")
const SWITCH: PackedScene = preload("res://objects/network/switch_rack.tscn")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const BREAKABLE_DOOR: PackedScene = preload("res://objects/door/breakable_door.tscn")
const CONTROLLER: PackedScene = preload("res://objects/door/door_controller.tscn")

var _root: Node3D
var _console: Node3D
var _switch: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	_root.position = Vector3(300, 0, -300)
	add_child(_root)
	_console = DeviceFixtures.device(_root, "Console", Vector3(0, 1, 3))
	_switch = SWITCH.instantiate() as Node3D
	_switch.name = "Switch"
	_root.add_child(_switch)
	_switch.position = Vector3(2, 1, 3)
	DeviceFixtures.link(_console, _switch)


func test_reached_door_unlocks_and_opens_on_command() -> void:
	var door := _door(DOOR)
	var controller := _controller(door)
	assert_bool(Device.of(_console).reaches(controller)).is_true()
	# The door itself is not on the network: only its controller is.
	assert_bool(Device.of(_console).reaches(door)).is_false()

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, controller)).is_true()
	await _frames(2)
	assert_bool(Door.of(door).is_locked()).is_false()
	assert_bool(Device.of(_console).send_command(Device.OPEN, controller)).is_true()
	await _frames(2)

	assert_bool(Door.of(door).is_open()).is_true()
	assert_str(String(EventLog.find(&"door.command")[0].source)).is_equal("Console")


func test_remote_open_opens_a_locked_door_and_keeps_it_locked() -> void:
	var door := _door(DOOR)

	Device.of(_console).send_command(Device.OPEN, _controller(door))
	await _frames(2)

	assert_bool(Door.of(door).is_open()).is_true()
	assert_bool(Door.of(door).is_locked()).is_true()


func test_unpowered_switch_cuts_the_door_off() -> void:
	var door := _door(DOOR)
	Powered.of(_switch).on = false

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, _controller(door))).is_false()
	assert_bool(Device.of(_console).send_command(Device.OPEN, _controller(door))).is_false()
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()
	assert_bool(Door.of(door).is_open()).is_false()
	var sent := EventLog.find(&"device.command").map(func(entry: EventLogEntry) -> bool: return entry.data["sent"])
	assert_array(sent).is_equal([false, false])


func test_unpowered_controller_ignores_commands() -> void:
	var door := _door(DOOR, true)
	var controller := _controller(door)
	Powered.of(controller).on = false
	assert_bool(ActorState.has(controller, Device.UNPOWERED)).is_true()
	# The door's lock has no power either (its power rule: no fail-safe tag, it stays locked).
	assert_bool(ActorState.has(door, Device.UNPOWERED)).is_true()

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, controller)).is_false()
	# Even a command that reaches its entity directly is blocked by its receptrons.
	StimulusSystem.emit(Device.command_stimulus(Device.OPEN, controller, _console))
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()
	assert_bool(Door.of(door).is_open()).is_false()


func test_a_broken_door_stays_open_whatever_its_controller_is_told() -> void:
	var door := _door(BREAKABLE_DOOR)
	StimulusSystem.emit(Stimulus.make_contact(&"damage.explosive", 80.0, door, _root))
	await _frames(2)
	assert_bool(ActorState.has(door, Device.BROKEN)).is_true()

	assert_bool(Device.of(_console).send_command(Device.CLOSE, _controller(door))).is_true()
	await _frames(2)

	assert_bool(Door.of(door).is_open()).is_true()
	assert_bool(EventLog.find(&"door.command")[0].data["done"]).is_false()


func test_uncabled_door_is_not_reached() -> void:
	var door := _door(DOOR, false, false)

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, _controller(door))).is_false()
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()


# A locked door 4 m from the switch with a controller under its hardware (a Powered on the controller
# when asked), cabled to the switch unless `cabled` is false.
func _door(scene: PackedScene, powered: bool = false, cabled: bool = true) -> StaticBody3D:
	var door := scene.instantiate() as StaticBody3D
	door.name = "Door"
	var controller := CONTROLLER.instantiate() as Node3D
	if powered:
		var power := Powered.new()
		power.name = "Powered"
		controller.add_child(power)
	door.get_node("Hardware").add_child(controller)
	_root.add_child(door)
	door.position = Vector3(2, 0, -1)
	Lockable.of(door).lock(null, &"test")
	if cabled:
		DeviceFixtures.link(_switch, controller)
	return door


# The door's controller entity.
func _controller(door: Node) -> Node3D:
	return Door.of(door).hardware.controller.entity


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
