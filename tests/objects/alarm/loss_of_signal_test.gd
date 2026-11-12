extends GdUnitTestSuite
## Loss-of-signal alarms (M12c, ADR 0115): the pure LossOfSignal model, and the shipped alarm
## controller supervising minimal devices built in code (device_fixtures). Plan (metres from ORIGIN):
##
##   Siren (-2,0) ── Controller (0,0) ── SwitchA (2,0) ── A1 (4,-1), A2 (4,0), A3 (4,1)
##                        └── B1 (0,2), B2 (1,2), B3 (2,2): cabled straight to the controller
##
## Time between drops is set on the controller's clock (the model only reads it), so "10 s" costs
## no simulated seconds; supervision checks every CHECK seconds.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const CONTROLLER_SCENE: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")
const SIREN_SCENE: PackedScene = preload("res://objects/alarm/siren.tscn")
const ORIGIN := Vector3(-300, 0, 340)
const CHECK := 0.05

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n.clear()
	_n["Controller"] = _instance(CONTROLLER_SCENE, "Controller", Vector3.ZERO)
	_n["Siren"] = _instance(SIREN_SCENE, "Siren", Vector3(-2, 2.5, 0))
	_n["SwitchA"] = Devices.device(_root, "SwitchA", ORIGIN + Vector3(2, 1, 0), [], true)
	_n["SwitchA"].set_meta(&"display_name", "SW-A")
	Devices.link(_n["Siren"], _n["Controller"])
	Devices.link(_n["SwitchA"], _n["Controller"])
	for i in 3:
		var a := "A%d" % (i + 1)
		_n[a] = Devices.device(_root, a, ORIGIN + Vector3(4, 1, i - 1), [], true, 10.0)
		Devices.link(_n[a], _n["SwitchA"])
		var b := "B%d" % (i + 1)
		_n[b] = Devices.device(_root, b, ORIGIN + Vector3(i, 1, 2), [], true, 10.0)
		Devices.link(_n[b], _n["Controller"])
		_n[a].set_meta(&"display_name", "CAM-" + a)
		_n[b].set_meta(&"display_name", "CAM-" + b)
	var config := _controller().config.duplicate() as AlarmControllerConfig
	config.supervision_interval = CHECK
	config.duration = 4.0
	_controller().config = config
	await _checks(2)


func after_test() -> void:
	StimulusSystem.clear()


func _instance(scene: PackedScene, node_name: String, offset: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.position = ORIGIN + offset
	_root.add_child(node)
	return node


func _controller() -> AlarmController:
	return AlarmController.of(_n["Controller"])


func _siren() -> Siren:
	return _n["Siren"].get_node("SirenBehaviour") as Siren


# Waits for `count` supervision checks (and two frames for the commands they send).
func _checks(count: int) -> void:
	for i in int(ceil(CHECK * 60.0)) * count + 2:
		await get_tree().physics_frame


func _break(key: String) -> void:
	Breakable.of(_n[key]).take_damage(&"damage.ballistic", 50.0)


func _faults() -> Array[EventLogEntry]:
	return EventLog.find(&"alarm.network_fault")


func test_the_model_notes_each_drop_and_raises_once_for_three_within_the_window() -> void:
	var model := LossOfSignal.new()
	var all: Dictionary[int, String] = {1: "CAM-1", 2: "CAM-2", 3: "CAM-3", 4: "CAM-4"}
	assert_array(Array(model.update(all, 0.0))).is_empty()
	var left := all.duplicate()
	left.erase(1)
	assert_array(Array(model.update(left, 1.0))).contains_exactly([1])
	left.erase(2)
	model.update(left, 3.0)
	assert_array(Array(model.fault_due(3.0))).is_empty()
	left.erase(3)
	model.update(left, 5.0)
	assert_array(Array(model.fault_due(5.0))).contains_exactly([1, 2, 3])
	# Handed over once; the notes stay, newest first.
	assert_array(Array(model.fault_due(5.5))).is_empty()
	assert_array(Array(model.lines())).contains_exactly(
		["00:05  CAM-3  lost signal", "00:03  CAM-2  lost signal", "00:01  CAM-1  lost signal"]
	)


func test_the_model_ignores_three_drops_spread_over_25_seconds() -> void:
	var model := LossOfSignal.new()
	var present: Dictionary[int, String] = {1: "A", 2: "B", 3: "C"}
	model.update(present, 0.0)
	for step: Array in [[1, 0.5], [2, 12.5], [3, 24.5]]:
		present.erase(int(step[0]))
		model.update(present, float(step[1]))
		assert_array(Array(model.fault_due(float(step[1])))).is_empty()
	assert_int(model.notes.size()).is_equal(3)


func test_one_or_two_drops_are_trouble_notes_only() -> void:
	_break("B1")
	await _checks(2)
	assert_array(Array(_controller().trouble_lines())).has_size(1)
	assert_str(_controller().trouble_lines()[0]).ends_with("CAM-B1  lost signal")
	_controller().clock += 2.0
	Powered.of(_n["B2"]).on = false
	await _checks(2)
	assert_array(Array(_controller().trouble_lines())).has_size(2)
	assert_bool(_controller().is_ringing()).is_false()
	assert_array(_faults()).is_empty()
	assert_array(EventLog.find(&"alarm.trouble")).has_size(2)


func test_a_switch_cutting_three_devices_raises_one_network_fault_at_the_switch() -> void:
	Powered.of(_n["SwitchA"]).on = false
	await _checks(3)
	# The switch and its three devices dropped; the shared down device upstream is the switch.
	assert_array(Array(_controller().trouble_lines())).has_size(4)
	assert_array(_faults()).has_size(1)
	assert_str(str(_faults()[0].data["at"])).is_equal("SW-A")
	assert_bool(_controller().is_ringing()).is_true()
	assert_bool(_controller().is_fault()).is_true()
	assert_vector(_controller().point).is_equal_approx(_n["SwitchA"].global_position, Vector3.ONE * 0.001)
	var raised := EventLog.find(&"alarm.raised")
	assert_int(raised.size()).is_equal(1)
	assert_bool(raised[0].data["fault"]).is_true()
	# Sirens announce it with the fault pattern; an intruder incident turns it back.
	assert_bool(_siren().is_sounding()).is_true()
	assert_bool(_siren().fault).is_true()
	_controller().raise(_n["B1"].global_position, "Camera", true)
	await _checks(2)
	assert_bool(_controller().is_fault()).is_false()


func test_three_drops_within_ten_seconds_raise_one_fault_at_the_first_dropped_device() -> void:
	_break("B1")
	await _checks(2)
	_controller().clock += 2.5
	_break("B2")
	await _checks(2)
	_controller().clock += 2.5
	_break("B3")
	await _checks(2)
	# Sampled about 5 s after the first drop: one fault, at the first dropped device (no shared cut).
	assert_array(_faults()).has_size(1)
	assert_str(str(_faults()[0].data["at"])).is_empty()
	assert_vector(_controller().point).is_equal_approx(_n["B1"].global_position, Vector3.ONE * 0.001)
	assert_int(EventLog.find(&"alarm.raised").size()).is_equal(1)


func test_three_drops_spread_over_25_seconds_raise_nothing() -> void:
	for key: String in ["B1", "B2", "B3"]:
		_break(key)
		await _checks(2)
		_controller().clock += 12.0
	assert_array(Array(_controller().trouble_lines())).has_size(3)
	assert_array(_faults()).is_empty()
	assert_bool(_controller().is_ringing()).is_false()


func test_a_controller_that_goes_down_counts_no_drops_and_takes_stock_again() -> void:
	var power := Powered.of(_n["Controller"])
	power.on = false
	await _checks(2)
	power.on = true
	await _checks(2)
	# Everything "dropped" while it was down, from its side: nothing counted.
	assert_array(Array(_controller().trouble_lines())).is_empty()
	assert_array(_faults()).is_empty()
	_break("B1")
	await _checks(2)
	assert_array(Array(_controller().trouble_lines())).has_size(1)


func test_notes_are_saved_and_loaded() -> void:
	_break("B1")
	await _checks(2)
	var saved := _controller().save_state()
	_controller().supervision.notes.clear()
	_controller().load_state(saved)
	assert_array(Array(_controller().trouble_lines())).has_size(1)
	await _checks(2)
	assert_array(Array(_controller().trouble_lines())).has_size(1)
