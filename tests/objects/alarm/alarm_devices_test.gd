extends GdUnitTestSuite
## Integration: the shipped alarm device scenes (ADR 0077), wired in code without a level: alarm
## controller - network switch - siren, a radio base station and a panic button cabled to the
## controller. No guards here (tests/scenarios/alarm_devices_test.gd has them). The controller's
## ringing time is shortened to RING_TIME for speed (a duplicated config); the 45 s default is
## checked in the scenario test.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CONTROLLER_SCENE: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")
const SIREN_SCENE: PackedScene = preload("res://objects/alarm/siren.tscn")
const SWITCH_SCENE: PackedScene = preload("res://objects/network/switch_rack.tscn")
const STATION_SCENE: PackedScene = preload("res://objects/alarm/radio_base_station.tscn")
const BUTTON_SCENE: PackedScene = preload("res://objects/alarm/panic_button.tscn")
const RING_TIME := 4.0

var _root: Node3D
var _controller: Node3D
var _switch: Node3D
var _siren: Node3D
var _station: Node3D
var _button: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_controller = _add(CONTROLLER_SCENE, "Controller", Vector3(0, 1.4, 0))
	_switch = _add(SWITCH_SCENE, "Switch", Vector3(2, 1.4, 0))
	_siren = _add(SIREN_SCENE, "Siren", Vector3(4, 2.5, 0))
	_station = _add(STATION_SCENE, "Station", Vector3(-2, 1.4, 0))
	_button = _add(BUTTON_SCENE, "Button", Vector3(-4, 1.2, 0))
	_link(_controller, _switch)
	_link(_siren, _switch)
	_link(_station, _controller)
	_link(_button, _controller)
	var config := _behaviour().config.duplicate() as AlarmControllerConfig
	config.duration = RING_TIME
	_behaviour().config = config
	await Wait.frames(get_tree(), 1)


func after_test() -> void:
	StimulusSystem.clear()


func _add(scene: PackedScene, node_name: String, position: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = position
	_root.add_child(node)
	return node


func _link(a: Node3D, b: Node3D) -> void:
	var device := Device.of(a)
	device.links.append(device.get_path_to(b))


func _behaviour() -> AlarmController:
	return _controller.get_node("AlarmControllerBehaviour") as AlarmController


func _horn() -> Siren:
	return _siren.get_node("SirenBehaviour") as Siren


func _command(command: StringName, target: Node3D) -> void:
	StimulusSystem.emit(Device.command_stimulus(command, target))


func _pulses() -> int:
	return (
		EventLog
		. find(&"stimulus.emitted")
		. filter(func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"alarm.siren")
		. size()
	)


func test_the_panic_button_rings_the_siren_through_the_switch_and_dispatches_the_radio() -> void:
	var usable := Usable.of(_button)
	assert_str(usable.verb).is_equal("press")
	assert_str(usable.target_name()).is_equal("panic button")
	usable.use(null)
	await Wait.frames(get_tree(), 6)

	assert_bool(_behaviour().is_ringing()).is_true()
	assert_vector(_behaviour().point).is_equal_approx(_button.global_position, Vector3.ONE * 0.001)
	assert_bool(_horn().is_sounding()).is_true()
	var dispatches := EventLog.find(&"radio.dispatch")
	assert_array(dispatches).has_size(1)
	assert_vector(dispatches[0].data["point"]).is_equal_approx(_button.global_position, Vector3.ONE * 0.001)
	assert_int(EventLog.find(&"device.panic")[0].data["controllers"]).is_equal(1)
	# The dispatch spreads from the station and is about the incident.
	var sent := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"alert.dispatch"
	)
	assert_array(sent).has_size(1)
	assert_vector(sent[0].data["origin"]).is_equal_approx(_station.global_position, Vector3.ONE * 0.001)


func test_the_controller_keeps_the_siren_ringing_then_stops_and_silences_it() -> void:
	_command(AlarmController.TRIGGER, _controller)
	await _seconds(2.5)
	assert_bool(_horn().is_sounding()).is_true()
	# One pulse a second from the first ring: at 0, 1 and 2 s.
	assert_int(_pulses()).is_equal(3)

	await _seconds(RING_TIME)
	assert_bool(_behaviour().is_ringing()).is_false()
	assert_bool(_horn().is_sounding()).is_false()
	assert_str(String(EventLog.find(&"alarm.ended")[0].data["reason"])).is_equal("timeout")
	assert_str(String(EventLog.find(&"siren.stopped")[0].data["reason"])).is_equal("silenced")


func test_cutting_the_switch_stops_the_ring_reaching_the_siren() -> void:
	_behaviour().config.duration = 20.0
	var switch_power := Powered.of(_switch)
	switch_power.on = false
	_command(AlarmController.TRIGGER, _controller)
	await _seconds(1.0)
	assert_bool(_behaviour().is_ringing()).is_true()
	assert_bool(_horn().is_sounding()).is_false()
	assert_int(_pulses()).is_equal(0)

	# Reconnected while the controller rings: its next refresh rings the siren.
	switch_power.on = true
	await _seconds(1.5)
	assert_bool(_horn().is_sounding()).is_true()

	# Cut again: the siren falls silent within its ring hold (2.5 s).
	switch_power.on = false
	await _seconds(3.0)
	assert_bool(_behaviour().is_ringing()).is_true()
	assert_bool(_horn().is_sounding()).is_false()
	assert_str(String(EventLog.find(&"siren.stopped")[0].data["reason"])).is_equal("timeout")


func test_reset_disarm_and_enable() -> void:
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 3)
	_command(AlarmController.RESET, _controller)
	await Wait.frames(get_tree(), 3)
	assert_bool(_behaviour().is_ringing()).is_false()
	assert_str(String(EventLog.find(&"alarm.ended")[0].data["reason"])).is_equal("reset")

	_command(AlarmController.DISARM, _controller)
	await Wait.frames(get_tree(), 2)
	Usable.of(_button).use(null)
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 4)
	assert_bool(_behaviour().armed).is_false()
	# Disarmed shows as disabled on security screens (ADR 0099 amendment).
	assert_bool(DeviceStatus.is_disabled(_controller)).is_true()
	assert_bool(_behaviour().is_ringing()).is_false()
	assert_array(EventLog.find(&"alarm.ignored")).has_size(2)
	assert_array(EventLog.find(&"radio.dispatch")).is_empty()

	_command(DeviceSwitch.ENABLE, _controller)
	await Wait.frames(get_tree(), 2)
	assert_bool(DeviceStatus.is_disabled(_controller)).is_false()
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 3)
	assert_bool(_behaviour().is_ringing()).is_true()


func test_losing_power_or_breaking_stops_the_controller() -> void:
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 3)
	Powered.of(_controller).on = false
	assert_bool(_behaviour().is_ringing()).is_false()
	assert_str(String(EventLog.find(&"alarm.ended")[0].data["reason"])).is_equal("unpowered")
	# Unpowered, it ignores commands (its receptrons block on `state.unpowered`).
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 3)
	assert_bool(_behaviour().is_ringing()).is_false()

	Powered.of(_controller).on = true
	_command(AlarmController.TRIGGER, _controller)
	await Wait.frames(get_tree(), 3)
	assert_bool(_behaviour().is_ringing()).is_true()
	StimulusSystem.emit(Stimulus.make_contact(&"damage.ballistic", 100.0, _controller))
	await Wait.frames(get_tree(), 2)
	assert_bool(_behaviour().is_ringing()).is_false()
	assert_bool(ActorState.has(_controller, Device.BROKEN)).is_true()
	assert_str(String(EventLog.find(&"alarm.ended")[1].data["reason"])).is_equal("broken")


func test_siren_test_silence_and_power() -> void:
	_command(Siren.TEST, _siren)
	await _seconds(2.0)
	assert_bool(_horn().is_sounding()).is_true()
	await _seconds(1.5)
	assert_bool(_horn().is_sounding()).is_false()

	_command(Siren.TEST, _siren)
	await Wait.frames(get_tree(), 3)
	_command(Siren.SILENCE, _siren)
	await Wait.frames(get_tree(), 3)
	assert_bool(_horn().is_sounding()).is_false()

	_command(Siren.TEST, _siren)
	await Wait.frames(get_tree(), 3)
	Powered.of(_siren).on = false
	assert_bool(_horn().is_sounding()).is_false()
	var pulses := _pulses()
	_command(Siren.TEST, _siren)
	await _seconds(1.5)
	assert_int(_pulses()).is_equal(pulses)


func test_controller_and_siren_survive_save_and_load() -> void:
	_command(AlarmController.TRIGGER, _controller)
	await _seconds(1.0)
	var saved := _behaviour().save_state()
	var horn_saved := _horn().save_state()
	_command(AlarmController.RESET, _controller)
	await Wait.frames(get_tree(), 3)
	assert_bool(_behaviour().is_ringing()).is_false()

	_behaviour().load_state(saved)
	_horn().load_state(horn_saved)
	assert_bool(_behaviour().is_ringing()).is_true()
	assert_float(_behaviour().time_left()).is_equal_approx(RING_TIME - 1.0, 0.1)
	assert_vector(_behaviour().point).is_equal_approx(_controller.global_position, Vector3.ONE * 0.001)
	assert_bool(_horn().is_sounding()).is_true()

	var device_saved := Device.of(_siren).save_state()
	assert_bool(device_saved["broken"]).is_false()
	Device.of(_siren).load_state({"broken": true})
	assert_bool(ActorState.has(_siren, Device.BROKEN)).is_true()
	assert_bool((_siren.get_node("Model/Beacon") as Node3D).visible).is_false()


func _seconds(value: float) -> void:
	await Wait.frames(get_tree(), roundi(value * 60.0))
