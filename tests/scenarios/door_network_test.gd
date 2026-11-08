extends GdUnitTestSuite
## Scenario across M8a and M8b (ADR 0077, ADR 0078): a console device cabled through a network
## switch (`objects/devices/network_switch.tscn`) to a locked door sends `command.unlock` and
## `command.open` with Device.send_command(). They work while the door is reached; they do not when
## the switch is unpowered, the door itself is unpowered or the door is broken, or nothing is
## cabled.

const DeviceFixtures := preload("res://tests/objects/devices/device_fixtures.gd")
const SWITCH: PackedScene = preload("res://objects/devices/network_switch.tscn")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const BREAKABLE_DOOR: PackedScene = preload("res://objects/door/breakable_door.tscn")

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
	assert_bool(Device.of(_console).reaches(door)).is_true()

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, door)).is_true()
	await _frames(2)
	assert_bool(Door.of(door).is_locked()).is_false()
	assert_bool(Device.of(_console).send_command(Device.OPEN, door)).is_true()
	await _frames(2)

	assert_bool(Door.of(door).is_open()).is_true()
	assert_str(String(EventLog.find(&"door.command")[0].source)).is_equal("Console")


func test_remote_open_opens_a_locked_door_and_keeps_it_locked() -> void:
	var door := _door(DOOR)

	Device.of(_console).send_command(Device.OPEN, door)
	await _frames(2)

	assert_bool(Door.of(door).is_open()).is_true()
	assert_bool(Door.of(door).is_locked()).is_true()


func test_unpowered_switch_cuts_the_door_off() -> void:
	var door := _door(DOOR)
	Powered.of(_switch).on = false

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, door)).is_false()
	assert_bool(Device.of(_console).send_command(Device.OPEN, door)).is_false()
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()
	assert_bool(Door.of(door).is_open()).is_false()
	var sent := EventLog.find(&"device.command").map(func(entry: EventLogEntry) -> bool: return entry.data["sent"])
	assert_array(sent).is_equal([false, false])


func test_unpowered_door_ignores_commands() -> void:
	var door := _door(DOOR, true)
	Powered.of(door).on = false
	assert_bool(ActorState.has(door, Device.UNPOWERED)).is_true()

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, door)).is_false()
	# Even a command that reaches its entity directly is blocked by its receptrons.
	StimulusSystem.emit(Device.command_stimulus(Device.OPEN, door, _console))
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()
	assert_bool(Door.of(door).is_open()).is_false()


func test_broken_door_ignores_commands() -> void:
	var door := _door(BREAKABLE_DOOR)
	StimulusSystem.emit(Stimulus.make_contact(&"damage.explosive", 80.0, door, _root))
	await _frames(2)
	assert_bool(ActorState.has(door, Device.BROKEN)).is_true()

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, door)).is_false()
	StimulusSystem.emit(Device.command_stimulus(Device.UNLOCK, door, _console))
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()
	assert_array(EventLog.find(&"lock.unlocked")).is_empty()


func test_uncabled_door_is_not_reached() -> void:
	var door := _door(DOOR, false, false)

	assert_bool(Device.of(_console).send_command(Device.UNLOCK, door)).is_false()
	await _frames(2)

	assert_bool(Door.of(door).is_locked()).is_true()


# A locked door 4 m from the switch, cabled to it unless `cabled` is false; with a Powered when asked.
func _door(scene: PackedScene, powered: bool = false, cabled: bool = true) -> StaticBody3D:
	var door := scene.instantiate() as StaticBody3D
	door.name = "Door"
	if powered:
		var power := Powered.new()
		power.name = "Powered"
		door.add_child(power)
	_root.add_child(door)
	door.position = Vector3(2, 0, -1)
	Lockable.of(door).lock(null, &"test")
	if cabled:
		DeviceFixtures.link(_switch, door)
	return door


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
