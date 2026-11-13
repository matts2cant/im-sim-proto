extends GdUnitTestSuite
## Integration (ADR 0130): a door controller built from components (Tags, the command receptrons,
## Powered, Breakable, Device, DeviceLamp, DoorController) under a plain door's hardware, as a level
## places one. Its wall boxes on both faces are one device (the same Device, status and light from
## either box); commands reach the door; the lock light shows the network state (blinking amber when
## cut off); the controller's power loss or breakage follows the door's power rule (fail-secure stays
## locked, fail-safe unlocks); a door without a box has no Device. No navigation: far from the origin.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const COMMANDS: Array[String] = ["open", "close", "lock", "unlock"]
const ORIGIN := Vector3(520, 0, 520)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	_root.position = ORIGIN
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_both_boxes_are_one_device_with_one_status() -> void:
	var door := _door("Vault", Vector3.ZERO, [&"door.fail_secure"], true)
	await _frames(3)
	var controller := door.hardware.controller
	var device := Device.of(controller.entity)
	var front := door.hardware.controls(true)[0]
	var back := door.hardware.controls(false)[0]
	# One Device under the door, reached from either box (and the deck plugs in from either).
	assert_int(_devices_under(door.entity).size()).is_equal(1)
	assert_object(Device.of(door.entity)).is_null()
	assert_object(Device.of(front)).is_same(device)
	assert_object(Device.of(back)).is_same(device)
	assert_object(DoorController.of(back)).is_same(controller)
	assert_object((ToolUse.find_target(back, Device.DECK_TOOL) as DevicePanel).target()).is_same(device)
	# Its status words are the door's, the same from either box; its name is the door's.
	var words := DeviceStatus.of(Device.of(front).entity, true)
	assert_array(Array(words)).contains_exactly(["online", "locked", "closed"])
	assert_array(Array(DeviceStatus.of(Device.of(back).entity, true))).is_equal(Array(words))
	assert_str(NetworkSource.display_name(device)).is_equal("Vault")
	assert_bool(ActorState.has(controller.entity, &"object.door_controller")).is_true()
	# It sits at the front face's box (the cable's end).
	assert_vector(controller.entity.global_position).is_equal_approx(front.global_position, Vector3.ONE * 0.001)


func test_commands_reach_the_door_unless_the_controller_is_down() -> void:
	var door := _door("Door", Vector3.ZERO, [&"door.fail_secure"], false)
	await _frames(3)
	var entity := door.hardware.controller.entity
	# Blocked while the controller is unpowered or broken (its own tags).
	for tag: StringName in [Device.UNPOWERED, Device.BROKEN]:
		ActorState.set_tag(entity, tag, true)
		await _command(entity, Device.OPEN)
		await _command(entity, Device.LOCK)
		assert_bool(door.is_open()).override_failure_message(tag).is_false()
		assert_bool(door.is_locked()).override_failure_message(tag).is_false()
		ActorState.set_tag(entity, tag, false)
	assert_array(EventLog.find(&"door.command")).is_empty()
	await _command(entity, Device.LOCK)
	assert_bool(door.is_locked()).is_true()
	# A remote open opens a locked door without unlocking it.
	await _command(entity, Device.OPEN)
	assert_bool(door.is_open()).is_true()
	assert_bool(door.is_locked()).is_true()
	await _frames(45)
	await _command(entity, Device.CLOSE)
	await _command(entity, Device.UNLOCK)
	assert_bool(door.is_open()).is_false()
	assert_bool(door.is_locked()).is_false()
	assert_array(EventLog.find(&"door.command")).has_size(2)
	var hows := EventLog.find(&"lock.locked") + EventLog.find(&"lock.unlocked")
	(
		assert_array(hows.map(func(entry: EventLogEntry) -> String: return String(entry.data["how"])))
		. contains_exactly(["command", "command"])
	)


func test_the_lock_light_shows_the_network_state() -> void:
	var switch := _switch(Vector3(3, 1.5, 0))
	var door := _door("Door", Vector3.ZERO, [&"door.fail_secure"], true, switch)
	await _frames(3)
	var lamp := DeviceLamp.of(door.hardware.controller.entity)
	# The model's LED on every box is the lamp: one light per device, no extra LED.
	var leds: Array[MeshInstance3D] = []
	for box in door.hardware.controls(true) + door.hardware.controls(false):
		leds.append(_led_of(box))
	assert_array(lamp.meshes()).contains_exactly_in_any_order(leds)
	assert_array(StatusLight.of(door.hardware.controller.entity).indicators()).contains_exactly_in_any_order(leds)
	# On its network: the lock's colour (red: closed and locked).
	assert_bool(lamp.blinking()).is_false()
	assert_bool(lamp.color().is_equal_approx(Door.LOCKED_COLOUR)).is_true()
	# Its switch down: cut off, blinking amber on both boxes.
	Powered.of(switch).on = false
	await _frames(2)
	assert_bool(lamp.blinking()).is_true()
	assert_bool(lamp.color().is_equal_approx(StatusLight.COLORS[StatusLight.State.CUT_OFF])).is_true()
	# Back up, unlocked: green.
	Powered.of(switch).on = true
	Lockable.of(door.entity).unlock()
	await _frames(2)
	assert_bool(lamp.blinking()).is_false()
	assert_bool(lamp.color().is_equal_approx(Door.UNLOCKED_COLOUR)).is_true()


func test_power_loss_or_breakage_follows_the_doors_power_rule() -> void:
	var secure := _door("Secure", Vector3.ZERO, [&"door.fail_secure"], true)
	var safe := _door("Safe", Vector3(4, 0, 0), [&"door.fail_safe"], true)
	var broken := _door("Broken", Vector3(8, 0, 0), [&"door.fail_safe"], true)
	await _frames(3)
	for door: Door in [secure, safe, broken]:
		assert_bool(ActorState.has(door.entity, Device.UNPOWERED)).override_failure_message(door.entity.name).is_false()
	Powered.of(secure.hardware.controller.entity).on = false
	Powered.of(safe.hardware.controller.entity).on = false
	Breakable.of(broken.hardware.controller.entity).take_damage(&"damage.ballistic", 100.0)
	await _frames(2)
	# Fail-secure stays locked, fail-safe unlocks; the controller's breakage counts as power loss.
	assert_bool(secure.is_locked()).is_true()
	assert_bool(safe.is_locked()).is_false()
	assert_bool(broken.is_locked()).is_false()
	for door: Door in [secure, safe, broken]:
		assert_bool(ActorState.has(door.entity, Device.UNPOWERED)).override_failure_message(door.entity.name).is_true()
		var lamp := DeviceLamp.of(door.hardware.controller.entity)
		assert_bool(lamp.color().is_equal_approx(StatusLight.COLORS[StatusLight.State.DARK])).is_true()
	# Power back: the door has power again (fail-safe stays unlocked until someone locks it).
	Powered.of(safe.hardware.controller.entity).on = true
	await _frames(2)
	assert_bool(ActorState.has(safe.entity, Device.UNPOWERED)).is_false()
	assert_bool(safe.is_locked()).is_false()


func test_a_door_without_a_box_is_mechanical_and_a_box_makes_a_controller() -> void:
	var plain := DOOR.instantiate() as StaticBody3D
	plain.name = "Plain"
	_root.add_child(plain)
	var pinned := DOOR.instantiate() as StaticBody3D
	pinned.name = "Pinned"
	pinned.position = Vector3(4, 0, 0)
	Helpers.add_mechanical(pinned, 3)
	_root.add_child(pinned)
	var keypad := DOOR.instantiate() as StaticBody3D
	keypad.name = "Keypad"
	keypad.position = Vector3(8, 0, 0)
	Helpers.add_keypad(keypad, &"test_keypad", "1234")
	_root.add_child(keypad)
	await _frames(2)
	# No wall box: no controller, no Device (a pin lock sits on the leaf).
	for entity: Node in [plain, pinned]:
		assert_array(_devices_under(entity)).override_failure_message(entity.name).is_empty()
		assert_object(Door.of(entity).hardware.controller).override_failure_message(entity.name).is_null()
	# A keypad's box is a controller (a default one): one Device, a maintenance port for the deck.
	var built := Door.of(keypad).hardware.controller
	assert_object(built).is_not_null()
	assert_array(_devices_under(keypad)).has_size(1)
	assert_bool(Device.of(built.entity).accepts_tool(Device.DECK_TOOL)).is_true()
	# A controller added to a door without a lock gets a plain control box on each face.
	Helpers.add_controller(plain)
	await _frames(2)
	var hardware := Door.of(plain).hardware
	assert_int(hardware.controls(true).size()).is_equal(1)
	assert_int(hardware.controls(false).size()).is_equal(1)
	assert_object((Usable.of(hardware.controls(true)[0]) as DoorControl).lock).is_null()


# A door at `at` (under the root) with an ElectronicLock (locked when `locked`), `tags`, and a
# controller built from components under its hardware before it enters the tree, cabled to
# `switch` when given.
func _door(door_name: String, at: Vector3, tags: Array[StringName], locked: bool, switch: Node3D = null) -> Door:
	var entity := DOOR.instantiate() as StaticBody3D
	entity.name = door_name
	entity.position = at
	var tag_node := entity.get_node("Tags") as Tags
	var all_tags := tag_node.initial_tags.duplicate()
	all_tags.append_array(tags)
	tag_node.initial_tags = all_tags
	(entity.get_node("Lockable") as Lockable).locked = locked
	var lock := ElectronicLock.new()
	lock.name = "ElectronicLock"
	entity.add_child(lock)
	entity.get_node("Hardware").add_child(_controller(switch))
	_root.add_child(entity)
	return Door.of(entity)


# A door controller entity built from components (not the scene).
func _controller(switch: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Controller"
	var tags := Tags.new()
	tags.name = "Tags"
	tags.initial_tags = [&"object.device", &"object.door_controller"]
	root.add_child(tags)
	var attributes := Attributes.new()
	attributes.name = "Attributes"
	attributes.base_values = {&"health": 10.0}
	root.add_child(attributes)
	var receiver := StimulusReceiver.new()
	receiver.name = "StimulusReceiver"
	for command in COMMANDS:
		receiver.receptrons.append(load("res://objects/devices/receptrons/command_%s.tres" % command) as Receptron)
	root.add_child(receiver)
	var power := Powered.new()
	power.name = "Powered"
	root.add_child(power)
	var breakable := Breakable.new()
	breakable.name = "Breakable"
	breakable.break_on_depleted = false
	root.add_child(breakable)
	var device := Device.new()
	device.name = "Device"
	if switch != null:
		device.links = [switch.get_path()]
	root.add_child(device)
	var lamp := DeviceLamp.new()
	lamp.name = "DeviceLamp"
	root.add_child(lamp)
	var controller := DoorController.new()
	controller.name = "DoorController"
	root.add_child(controller)
	return root


# A powered network switch: an entity tagged network gear with a Device.
func _switch(at: Vector3) -> Node3D:
	var switch := Fixtures.entity(_root, "Switch", at, [], [&"object.device", &"object.network_gear"])
	var power := Powered.new()
	power.name = "Powered"
	switch.add_child(power)
	var device := Device.new()
	device.name = "Device"
	switch.add_child(device)
	return switch


func _command(entity: Node3D, type: StringName) -> void:
	StimulusSystem.emit(Stimulus.make_contact(type, 1.0, entity, _root))
	await _frames(2)


static func _devices_under(entity: Node) -> Array[Device]:
	var found: Array[Device] = []
	for node in entity.find_children("*", "", true, false):
		if node is Device:
			found.append(node as Device)
	return found


static func _led_of(box: Node) -> MeshInstance3D:
	for node in box.find_children("*", "", true, false):
		if node is StatusLed:
			return (node as StatusLed).led
	return null


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
