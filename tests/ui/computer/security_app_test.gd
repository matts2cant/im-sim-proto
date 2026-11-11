extends GdUnitTestSuite
## Integration (ADR 0114): the Security app (SecurityApp) on a network built in code from the shipped
## device scenes, 400 m from the origin: a console computer and, on one switch, a camera, a turret, a
## door, an alarm controller, two sirens, a radio base station, a panic button, a laser array and a
## plain device with no kind; a camera cabled to nothing; an office PC on a switch of its own. The
## app groups the console's devices by kind (icons per kind), lists only what the computer controls,
## builds each device's actions from the commands it accepts (a camera disabled, a door locked and
## unlocked, the alarm disarmed, a laser array disabled), shows the live view of a device that has
## one, greys what goes offline, and says so when a computer controls nothing.

const COMPUTER: PackedScene = preload("res://objects/computer/computer.tscn")
const SWITCH: PackedScene = preload("res://objects/devices/network_switch.tscn")
const CAMERA: PackedScene = preload("res://objects/camera/security_camera.tscn")
const TURRET: PackedScene = preload("res://objects/turret/turret.tscn")
const DOOR: PackedScene = preload("res://objects/door/door.tscn")
const CONTROLLER: PackedScene = preload("res://objects/alarm/alarm_controller.tscn")
const SIREN: PackedScene = preload("res://objects/alarm/siren.tscn")
const RADIO: PackedScene = preload("res://objects/alarm/radio_base_station.tscn")
const PANIC: PackedScene = preload("res://objects/alarm/panic_button.tscn")
const LASER: PackedScene = preload("res://objects/laser/laser_array.tscn")
const DeviceFixtures := preload("res://tests/objects/devices/device_fixtures.gd")

var _root: Node3D
var _app: SecurityApp
var _console: Computer
var _nodes: Dictionary[String, Node3D] = {}


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_nodes.clear()
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = Vector3(400, 0, 400)
	add_child(_root)
	var console := _place(COMPUTER, "Console", Vector3(0, 1.45, 0))
	var switch := _place(SWITCH, "Switch", Vector3(2, 1.6, 0))
	DeviceFixtures.link(switch, console)
	var specs := [
		[CAMERA, "Camera", Vector3(4, 2.6, 0)],
		[TURRET, "Turret", Vector3(6, 0, 4)],
		[DOOR, "Door", Vector3(-4, 0, 4)],
		[CONTROLLER, "Controller", Vector3(8, 1.5, 0)],
		[SIREN, "Siren North", Vector3(10, 2.6, 0)],
		[SIREN, "Siren South", Vector3(12, 2.6, 0)],
		[RADIO, "Radio", Vector3(14, 1.2, 0)],
		[PANIC, "Panic", Vector3(16, 1.3, 0)],
		[LASER, "Laser", Vector3(-8, 0.4, 0)],
	]
	for spec: Array in specs:
		DeviceFixtures.link(switch, _place(spec[0], spec[1], spec[2]))
	var plain := DeviceFixtures.device(_root, "Plain", Vector3(18, 1, 0), [])
	DeviceFixtures.link(switch, plain)
	_place(CAMERA, "Loose camera", Vector3(20, 2.6, 0))
	var office := _place(COMPUTER, "Office", Vector3(0, 1.45, -6))
	DeviceFixtures.link(office, _place(SWITCH, "Office switch", Vector3(2, 1.6, -6)))
	_console = Computer.of(console)
	_app = auto_free(SecurityApp.new()) as SecurityApp
	add_child(_app)
	_app.size = Vector2(980, 540)
	_app.shown = true
	await _frames(3)
	_app.bind(_console, null)
	EventLog.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_devices_are_grouped_by_kind_with_an_icon_per_kind() -> void:
	assert_array(_app.group_names()).contains_exactly(["Cameras and turrets", "Doors", "Alarm", "Laser arrays"])
	assert_array(_app.device_names("Cameras and turrets")).contains_exactly_in_any_order(["Camera", "Turret"])
	assert_array(_app.device_names("Doors")).contains_exactly(["Door"])
	assert_array(_app.device_names("Alarm")).contains_exactly_in_any_order(
		["Controller", "Siren North", "Siren South", "Radio", "Panic"]
	)
	assert_array(_app.device_names("Laser arrays")).contains_exactly(["Laser"])
	# Only what the console controls: not itself, not a device without a kind, nothing off its network.
	for absent: String in ["Console", "Switch", "Plain", "Loose Camera", "Office", "Office Switch"]:
		assert_bool(_app.device_names().has(absent)).override_failure_message(absent).is_false()
	# Icons belong to the kind, not to the device.
	var config := _console.config
	assert_array(Array(_app.icon_of("Laser"))).is_equal(Array(config.kind_for(_nodes["Laser"]).icon))
	assert_array(Array(_app.icon_of("Siren North"))).is_equal(Array(_app.icon_of("Siren South")))
	assert_array(Array(_app.icon_of("Siren North"))).is_not_equal(Array(_app.icon_of("Radio")))
	# The list rows carry the short status.
	assert_str(_app.row_status("Controller")).is_equal("armed · silent")
	assert_str(_app.row_status("Siren North")).is_equal("silent")


func test_actions_are_the_commands_each_device_accepts_and_send_them() -> void:
	assert_bool(_app.select("Camera")).is_true()
	assert_array(_app.action_labels()).contains_exactly(
		["Enable", "Disable", "Stop sweep", "Resume sweep", "Pan left", "Pan right"]
	)
	await _press("Disable")
	assert_str(_app.status_of("Camera")).contains("disabled")
	assert_str(_app.result_label.text).is_equal("Camera: Disable sent.")
	# A door locked, then unlocked.
	_app.select("Door")
	assert_array(_app.action_labels()).contains_exactly(["Open", "Close", "Lock", "Unlock"])
	await _press("Lock")
	assert_str(_app.status_of("Door")).contains("locked")
	await _press("Unlock")
	assert_str(_app.status_of("Door")).contains("unlocked")
	# The alarm disarmed.
	_app.select("Controller")
	await _press("Disarm")
	assert_str(_app.status_of("Controller")).contains("disarmed")
	assert_bool(DeviceStatus.is_disabled(_nodes["Controller"])).is_true()
	# A laser array disabled.
	_app.select("Laser")
	assert_array(_app.action_labels()).contains_exactly(["Enable", "Disable"])
	await _press("Disable")
	assert_bool(DeviceStatus.is_disabled(_nodes["Laser"])).is_true()
	# Every press went over the network from the console.
	for entry: EventLogEntry in EventLog.find(&"device.command"):
		assert_str(String(entry.data["from"])).is_equal("Console")
		assert_bool(entry.data["sent"]).is_true()


func test_the_live_view_follows_a_device_that_sees() -> void:
	_app.select("Camera")
	_app.update_feed()
	assert_bool(_app.feed_live()).is_true()
	assert_bool(_app.feed_frame.visible).is_true()
	assert_object(_app.feed_rect.texture).is_instanceof(ViewportTexture)
	assert_vector(Vector2(_app.feed_viewport.size)).is_equal(Vector2(480, 270))
	var eye := DeviceStatus.view_of(_nodes["Camera"])
	assert_vector(_app.feed_camera.global_position).is_equal_approx(eye.global_position, Vector3.ONE * 0.001)
	assert_float((-_app.feed_camera.global_basis.z).dot(-eye.global_basis.z)).is_greater(0.999)
	# The turret has a view too; a door has none.
	_app.select("Turret")
	assert_bool(_app.feed_frame.visible).is_true()
	_app.select("Door")
	assert_bool(_app.feed_frame.visible).is_false()
	_app.update_feed()
	assert_bool(_app.feed_live()).is_false()
	# Disabled: no signal. Hidden app: nothing renders.
	_app.select("Camera")
	await _press("Disable")
	_app.update_feed()
	assert_bool(_app.feed_live()).is_false()
	assert_bool(_app.no_signal_label.visible).is_true()
	await _press("Enable")
	_app.update_feed()
	assert_bool(_app.feed_live()).is_true()
	_app.shown = false
	_app.update_feed()
	assert_int(_app.feed_viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_a_cut_switch_greys_its_devices_without_actions() -> void:
	Powered.of(_root.get_node("Switch")).on = false
	await _frames(2)
	_app.refresh()
	assert_int(_app.device_names().size()).is_equal(9)
	for device_name in _app.device_names():
		assert_str(_app.row_status(device_name)).override_failure_message(device_name).is_equal("offline")
	_app.select("Laser")
	assert_array(_app.action_labels()).is_empty()
	assert_str(_app.status_of("Laser")).is_equal("offline")
	_app.select("Camera")
	_app.update_feed()
	assert_bool(_app.feed_live()).is_false()


func test_a_computer_that_controls_nothing_says_so_and_points_to_the_deck() -> void:
	_app.bind(Computer.of(_root.get_node("Office")), null)
	assert_array(_app.device_names()).is_empty()
	assert_bool(_app.none_box.is_visible_in_tree()).is_true()
	var texts := ""
	for node in _app.none_box.find_children("*", "Label", true, false):
		texts += (node as Label).text + "\n"
	assert_str(texts).contains(SecurityApp.NONE_TITLE)
	assert_str(texts).contains("deck")
	# Back on the console: the list again.
	_app.bind(_console, null)
	assert_bool(_app.none_box.is_visible_in_tree()).is_false()


func _press(label: String) -> void:
	var button := _app.action_button(label)
	assert_object(button).override_failure_message(label).is_not_null()
	if button == null:
		return
	button.pressed.emit()
	await _frames(3)
	_app.refresh()


func _place(scene: PackedScene, node_name: String, at: Vector3) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.name = node_name.replace(" ", "")
	node.position = at
	_root.add_child(node)
	_nodes[node_name] = node
	return node


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
