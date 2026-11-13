extends GdUnitTestSuite
## Contract (ADR 0136): the EventLog kinds gameplay consumers read about objects, devices and power
## (MissionTally's broken objects and commands, NetworkFeedback's drops and breaker switches) are
## recorded by the real components with the entities and data keys EventKinds documents.
## Characters, stimuli, alarms and awareness: event_contract_actor_test.gd.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const CRATE: PackedScene = preload("res://objects/small_crate/small_crate.tscn")
const BARREL: PackedScene = preload("res://objects/explosive_barrel/explosive_barrel.tscn")
const ORIGIN := Vector3(960, 0, -920)

var _root: Node3D
var _seen: Array[EventLogEntry] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_seen.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	EventLog.entry_added.connect(_on_entry)


func after_test() -> void:
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	StimulusSystem.clear()


func _on_entry(entry: EventLogEntry) -> void:
	_seen.append(entry)


func _last(kind: StringName) -> EventLogEntry:
	for i in range(_seen.size() - 1, -1, -1):
		if _seen[i].kind == kind:
			return _seen[i]
	return null


func _add(scene: PackedScene, offset: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = ORIGIN + offset
	_root.add_child(node)
	return node


# A stimulus with an id, as StimulusSystem gives one (a cause for the components below).
func _cause(target: Node3D) -> Stimulus:
	var stimulus := Stimulus.make_contact(&"damage.ballistic", 1.0, target, null)
	stimulus.id = 4242
	return stimulus


func test_object_damaged_and_broken_name_the_object_and_the_stimulus() -> void:
	var crate := _add(CRATE, Vector3.ZERO)
	await Wait.frames(get_tree(), 1)
	var cause := _cause(crate)
	var breakable := Breakable.of(crate)

	breakable.take_damage(&"ballistic", 1000.0, cause)

	var damaged := _last(EventKinds.OBJECT_DAMAGED)
	assert_object(damaged.target_entity()).is_same(crate)
	assert_bool(damaged.data["health"] is float).is_true()
	assert_float(damaged.data["health"] as float).is_less_equal(0.0)
	assert_int(damaged.data["by"] as int).is_equal(cause.id)
	var broken := _last(EventKinds.OBJECT_BROKEN)
	assert_object(broken.source_entity()).is_same(crate)
	assert_int(broken.data["by"] as int).is_equal(cause.id)
	assert_bool(broken.data.has("reason")).is_true()


func test_a_burnt_out_object_says_so() -> void:
	var crate := _add(CRATE, Vector3(2, 0, 0))
	await Wait.frames(get_tree(), 1)

	Breakable.of(crate).break_apart(&"burnt_out")

	var broken := _last(EventKinds.OBJECT_BROKEN)
	assert_object(broken.source_entity()).is_same(crate)
	assert_str(str(broken.data["reason"])).is_equal(MissionTally.BURNT_OUT)


func test_ignited_and_exploded_name_the_object_and_the_stimulus() -> void:
	var crate := _add(CRATE, Vector3(4, 0, 0))
	var barrel := _add(BARREL, Vector3(8, 0, 0))
	await Wait.frames(get_tree(), 1)
	var cause := _cause(crate)

	Flammable.of(crate).ignite(cause)
	Explosive.of(barrel).explode(cause)

	var ignited := _last(EventKinds.OBJECT_IGNITED)
	assert_object(ignited.source_entity()).is_same(crate)
	assert_int(ignited.data["by"] as int).is_equal(cause.id)
	var exploded := _last(EventKinds.OBJECT_EXPLODED)
	assert_object(exploded.source_entity()).is_same(barrel)
	assert_int(exploded.data["by"] as int).is_equal(cause.id)


func test_device_command_names_its_operator_and_stimulus() -> void:
	var receptrons: Array[Receptron] = [Devices.action_receptron(DeviceSwitch.DISABLE)]
	var sender := Devices.device(_root, "Sender", ORIGIN + Vector3(0, 0, 4))
	var target := Devices.device(_root, "Target", ORIGIN + Vector3(2, 0, 4), receptrons)
	Devices.link(sender, target)
	var operator := Fixtures.entity(_root, "Operator", ORIGIN + Vector3(0, 0, 5), [])
	await Wait.frames(get_tree(), 1)

	var sent := Device.of(sender).send_command(DeviceSwitch.DISABLE, target, Device.NO_POINT, operator)

	assert_bool(sent).is_true()
	var command := _last(EventKinds.DEVICE_COMMAND)
	assert_object(command.entity(MissionTally.BY)).is_same(operator)
	assert_bool(command.data["stimulus"] is int).is_true()
	assert_bool(command.data["sent"] as bool).is_true()


func test_device_state_names_the_device_entity() -> void:
	var device := Devices.device(_root, "Lamp", ORIGIN + Vector3(0, 0, 8), [], true)
	await Wait.frames(get_tree(), 1)

	(device.get_node("Powered") as Powered).on = false

	var state := _last(EventKinds.DEVICE_STATE)
	assert_object(state).is_not_null()
	assert_object(state.source_entity()).is_same(device)
	assert_bool(state.data["up"] as bool).is_false()


func test_power_switched_names_who_switched() -> void:
	var box := Node3D.new()
	box.name = "Box"
	var breaker := CircuitBreaker.new()
	breaker.name = "CircuitBreaker"
	breaker.circuit = &"contract_test"
	box.add_child(breaker)
	box.position = ORIGIN + Vector3(0, 0, 12)
	_root.add_child(box)
	var user := Fixtures.entity(_root, "User", ORIGIN + Vector3(0, 0, 13), [])

	breaker.set_closed(false, user)

	var switched := _last(EventKinds.POWER_SWITCHED)
	assert_object(switched.source_entity()).is_same(user)
	assert_bool(switched.data["on"] as bool).is_false()
