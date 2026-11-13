extends GdUnitTestSuite
## Integration: the Device component (ADR 0077) on minimal entities built in code
## (tests/objects/devices/device_fixtures.gd): state tags mirrored from Powered and Breakable, reach
## through cables and switches, commands delivered only when reached and blocked on an unpowered or
## broken target, incidents carrying their location to every device that accepts them.

const Wait := preload("res://tests/helpers/wait.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const RUNG: StringName = &"test.rung"

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


# A stand-in siren: `command.ring` adds RUNG (blocked while unpowered or broken, like the shipped
# receptrons).
func _bell(entity_name: String, position: Vector3, powered: bool = false, health: float = 0.0) -> Node3D:
	var ring := Devices.command_receptron(Siren.RING, [Fixtures.add_tag(RUNG)])
	return Devices.device(_root, entity_name, position, [ring], powered, health)


func test_state_tags_mirror_power_and_breaking() -> void:
	var entity := Devices.device(_root, "Box", Vector3.ZERO, [], true, 10.0)
	var device := Device.of(entity)
	var tags := Fixtures.tags_of(entity)
	assert_bool(device.is_up()).is_true()
	assert_bool(tags.has(Device.UNPOWERED)).is_false()

	Powered.of(entity).on = false
	assert_bool(tags.has(Device.UNPOWERED)).is_true()
	assert_bool(device.is_up()).is_false()
	Powered.of(entity).on = true
	assert_bool(tags.has(Device.UNPOWERED)).is_false()
	assert_bool(device.is_up()).is_true()

	Breakable.of(entity).take_damage(&"damage.ballistic", 25.0)
	assert_bool(tags.has(Device.BROKEN)).is_true()
	assert_bool(device.is_up()).is_false()
	# The husk stays (break_on_depleted off): a broken device is still there to be seen.
	assert_bool(is_instance_valid(entity) and not entity.is_queued_for_deletion()).is_true()
	var states := EventLog.find(&"device.state")
	assert_array(states.map(func(entry: EventLogEntry) -> bool: return entry.data["up"])).is_equal([false, true, false])


func test_without_power_or_breakable_a_device_is_always_up() -> void:
	var entity := Devices.device(_root, "Plain", Vector3.ZERO)
	assert_bool(Device.of(entity).is_up()).is_true()
	assert_bool(Fixtures.tags_of(entity).has(Device.UNPOWERED)).is_false()


func test_a_command_is_delivered_only_when_the_sender_reaches_the_target() -> void:
	var sender := Devices.device(_root, "Sender", Vector3.ZERO)
	var hub := Devices.device(_root, "Switch", Vector3(1, 0, 0), [], true, 40.0)
	var bell := _bell("Bell", Vector3(2, 0, 0))
	Devices.link(sender, hub)
	Devices.link(bell, hub)

	assert_bool(Device.of(sender).send_command(Siren.RING, bell)).is_true()
	await Wait.frames(get_tree(), 2)
	assert_bool(Fixtures.tags_of(bell).has(RUNG)).is_true()

	Fixtures.tags_of(bell).remove(RUNG)
	Powered.of(hub).on = false
	assert_bool(Device.of(sender).send_command(Siren.RING, bell)).is_false()
	await Wait.frames(get_tree(), 2)
	assert_bool(Fixtures.tags_of(bell).has(RUNG)).is_false()
	var attempts := EventLog.find(&"device.command")
	assert_array(attempts.map(func(entry: EventLogEntry) -> bool: return entry.data["sent"])).is_equal([true, false])
	assert_str(String(attempts[0].data["to"])).is_equal("Bell")


func test_a_broken_switch_cuts_reach_and_a_direct_cable_does_not_need_one() -> void:
	var sender := Devices.device(_root, "Sender", Vector3.ZERO)
	var hub := Devices.device(_root, "Switch", Vector3(1, 0, 0), [], false, 40.0)
	var behind := _bell("Behind", Vector3(2, 0, 0))
	var direct := _bell("Direct", Vector3(0, 0, 2))
	Devices.link(sender, hub)
	Devices.link(hub, behind)
	Devices.link(direct, sender)

	Breakable.of(hub).take_damage(&"damage.ballistic", 50.0)

	assert_bool(Device.of(sender).reaches(behind)).is_false()
	assert_bool(Device.of(sender).reaches(direct)).is_true()
	assert_bool(Device.of(direct).reaches(sender)).is_true()


func test_an_unpowered_or_broken_target_ignores_commands() -> void:
	var unpowered := _bell("Unpowered", Vector3.ZERO, true)
	var broken := _bell("Broken", Vector3(2, 0, 0), false, 10.0)
	Powered.of(unpowered).on = false
	Breakable.of(broken).take_damage(&"damage.ballistic", 25.0)
	# Sent straight at them (no network in between): their receptrons block on the state tags.
	StimulusSystem.emit(Device.command_stimulus(Siren.RING, unpowered))
	StimulusSystem.emit(Device.command_stimulus(Siren.RING, broken))
	await Wait.frames(get_tree(), 2)

	assert_bool(Fixtures.tags_of(unpowered).has(RUNG)).is_false()
	assert_bool(Fixtures.tags_of(broken).has(RUNG)).is_false()
	assert_array(EventLog.find(&"receptron.fired")).is_empty()
	# And a device does not reach a target that is down.
	var sender := Devices.device(_root, "Sender", Vector3(0, 0, 2))
	Devices.link(sender, unpowered)
	assert_bool(Device.of(sender).send_command(Siren.RING, unpowered)).is_false()


func test_reached_lists_only_devices_accepting_the_command() -> void:
	var sender := Devices.device(_root, "Sender", Vector3.ZERO)
	var bell := _bell("Bell", Vector3(1, 0, 0))
	var mute := Devices.device(_root, "Mute", Vector3(2, 0, 0))
	Devices.link(sender, bell)
	Devices.link(sender, mute)

	var accepting := Device.of(sender).reached(Siren.RING)
	assert_array(accepting).contains_exactly([Device.of(bell)])
	assert_array(Device.of(sender).reached()).contains_exactly_in_any_order([Device.of(bell), Device.of(mute)])
	assert_int(Device.of(sender).send_to_all(Siren.RING)).is_equal(1)


func test_an_incident_reaches_every_accepting_device_with_its_location() -> void:
	var sensor := Devices.device(_root, "Sensor", Vector3.ZERO)
	var first := Devices.device(_root, "First", Vector3(3, 0, 0), [Devices.action_receptron(Device.INCIDENT)])
	var second := Devices.device(_root, "Second", Vector3(6, 0, 0), [Devices.action_receptron(Device.INCIDENT)])
	var other := _bell("Bell", Vector3(9, 0, 0))
	Devices.link(sensor, first)
	Devices.link(first, second)
	Devices.link(second, other)
	var heard: Array[Vector3] = []
	for controller: Node3D in [first, second]:
		Device.of(controller).action_received.connect(
			func(action: StringName, stimulus: Stimulus) -> void:
				if action == Device.INCIDENT:
					heard.append(stimulus.origin)
		)

	var at := Vector3(1, 2, 3)
	assert_int(Device.of(sensor).report_incident(at)).is_equal(2)
	await Wait.frames(get_tree(), 2)

	assert_int(heard.size()).is_equal(2)
	for origin in heard:
		assert_vector(origin).is_equal(at)
	assert_bool(Fixtures.tags_of(other).has(RUNG)).is_false()
