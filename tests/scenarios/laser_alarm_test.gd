extends GdUnitTestSuite
## Scenario (EventLog, ADR 0096, ADR 0100): the shipped laser array with three beams on a network
## built in code at (400, 0, -400): a switch cabled to the array (beams at 0.4, 0.9 and 1.4 m, each
## 3 m along +X from x -1.5, at z 0), an alarm controller, a siren and a terminal (all shipped
## scenes). A walker (1.8 m) tagged `actor.player` crosses the beams at 4 m/s: one incident goes
## through the switch to the controller, which rings the siren through the same switch. The terminal
## lists the array as one device with its status words and its commands, one Disable darkens every
## beam, and it shows offline once the switch loses power.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const LASER: PackedScene = preload("res://objects/laser/laser_array.tscn")
const BEAM: PackedScene = preload("res://objects/laser/laser_beam.tscn")
const CONTROLLER: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")
const SIREN: PackedScene = preload("res://objects/alarm/siren.tscn")
const TERMINAL: PackedScene = preload("res://objects/terminal/terminal.tscn")
const SWITCH: PackedScene = preload("res://objects/devices/network_switch.tscn")

var _root: Node3D
var _laser: Node3D
var _switch: Node3D
var _terminal: Terminal


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	_root.position = Vector3(400, 0, -400)
	add_child(_root)
	Characters.floor_box(_root)
	_laser = LASER.instantiate() as Node3D
	_laser.name = "Laser"
	_laser.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.5, 0.4, 0))
	(_laser.get_node("Beam1") as LaserBeam).length = 3.0
	for index: int in [2, 3]:
		var beam := BEAM.instantiate() as LaserBeam
		beam.name = "Beam%d" % index
		beam.position = Vector3(0, 0.5 * (index - 1), 0)
		beam.length = 3.0
		_laser.add_child(beam)
	_root.add_child(_laser)
	_switch = _place(SWITCH, "Switch", Transform3D(Basis.IDENTITY, Vector3(3, 1.4, -3)))
	var controller := _place(CONTROLLER, "Controller", Transform3D(Basis.IDENTITY, Vector3(4, 1.4, -3)))
	var siren := _place(SIREN, "Siren", Transform3D(Basis.IDENTITY, Vector3(5, 2.5, -3)))
	var terminal := TERMINAL.instantiate() as Node3D
	terminal.name = "Terminal"
	terminal.position = Vector3(6, 1.45, -3)
	_terminal = Terminal.of(terminal)
	_terminal.username = "tester"
	_terminal.password = "pass"
	_root.add_child(terminal)
	for device: Node3D in [_laser, controller, siren, terminal]:
		Devices.link(_switch, device)
	await _frames(3)
	EventLog.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_crossing_the_beam_rings_the_siren_through_the_controller() -> void:
	await _cross()
	var tripped := EventLog.find(&"laser.tripped")
	assert_array(tripped).has_size(1)
	assert_str(String(tripped[0].data["by"])).is_equal("Walker")
	assert_int(int(tripped[0].data["controllers"])).is_equal(1)
	var raised := EventLog.find(&"alarm.raised")
	assert_array(raised).has_size(1)
	var point: Vector3 = raised[0].data["point"]
	assert_float(point.y).is_equal_approx(0.4, 0.01)
	assert_float(_root.to_local(point).z).is_equal_approx(0.0, 0.01)
	var started := EventLog.find(&"siren.started")
	assert_array(started).has_size(1)
	assert_int(raised[0].tick).is_greater_equal(tripped[0].tick)
	assert_int(started[0].tick).is_greater_equal(raised[0].tick)


func test_the_terminal_lists_its_status_and_commands_and_disables_it() -> void:
	assert_int(LaserArray.of(_laser).beams.size()).is_equal(3)
	# One row for the array (and one per other device), not one per beam.
	var listed := _terminal.devices().filter(func(entry: Terminal.Row) -> bool: return entry.device.entity == _laser)
	assert_array(listed).has_size(1)
	var names: Array[String] = []
	for entry in _terminal.devices():
		names.append(String(entry.device.entity.name))
	assert_array(names).contains_exactly_in_any_order(["Switch", "Laser", "Controller", "Siren", "Terminal"])
	var row := _row()
	assert_bool(row.online).is_true()
	assert_array(Array(row.status)).contains_exactly(["online", "enabled", "clear"])
	assert_array(row.commands).contains_exactly_in_any_order([Device.ENABLE, Device.DISABLE])
	assert_bool(row.has_view).is_false()
	await _cross()
	assert_array(Array(_row().status)).contains_exactly(["online", "enabled", "tripped"])
	assert_bool(_terminal.log_in("tester", "pass")).is_true()
	assert_bool(_terminal.send(Device.DISABLE, Device.of(_laser))).is_true()
	await _frames(3)
	assert_array(Array(_row().status)).contains_exactly(["online", "disabled"])
	for beam in LaserArray.of(_laser).beams:
		assert_bool(beam.ray_visible()).override_failure_message(String(beam.name)).is_false()
	EventLog.clear()
	await _cross(-1)
	assert_array(EventLog.find(&"laser.tripped")).is_empty()
	# The switch unpowered: the laser is offline (never "broken"), and still dark.
	Powered.of(_switch).on = false
	await _frames(2)
	assert_bool(_row().online).is_false()
	assert_array(Array(_row().status)).contains_exactly(["offline"])


# A walker tagged actor.player crossing the beam (along z 0) at 4 m/s: from z 2 to -2
# (`direction` 1) or back.
func _cross(direction: int = 1) -> void:
	var walker := Characters.character(_root, "Walker", Vector3(0, 0, 2.0 * direction), [])
	Characters.tags_of(walker).add(&"actor.player")
	walker.set(&"drive", Vector3(0, 0, -4.0 * direction))
	await _frames(60)
	walker.set(&"drive", Vector3.ZERO)
	walker.queue_free()
	await _frames(3)


func _row() -> Terminal.Row:
	for row in _terminal.devices():
		if row.device == Device.of(_laser):
			return row
	return null


func _place(scene: PackedScene, node_name: String, where: Transform3D) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name
	node.transform = where
	_root.add_child(node)
	return node


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
