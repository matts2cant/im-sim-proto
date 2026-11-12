extends GdUnitTestSuite
## Integration (ADR 0079): the camera behaviour is generic. A minimal entity built in code (Tags,
## receiver, Device; a plain turning Node3D carrying a PerceptionSensor with the camera's config; a
## SecurityCamera) watches for a static entity tagged `actor.player` (no light component: fully lit)
## 6 m in front and reports to a minimal "controller" device cabled to it (it accepts
## `device.incident`). Built 500 m south of the origin, away from other suites' leftovers.

const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const PERCEPTION: PerceptionConfig = preload("res://objects/camera/security_camera_perception.tres")
const CONFIG: SecurityCameraConfig = preload("res://objects/camera/security_camera.tres")

var _root: Node3D
var _watcher: Node3D
var _camera: SecurityCamera
var _incidents: Array[Vector3] = []


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_incidents.clear()
	_root = auto_free(Node3D.new())
	_root.position = Vector3(0, 0, 500)
	add_child(_root)
	var receptrons: Array[Receptron] = [
		Devices.action_receptron(Device.DISABLE), Devices.action_receptron(Device.PAN_LEFT)
	]
	_watcher = Devices.device(_root, "Watcher", Vector3(0, 2.5, 0), receptrons)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	_watcher.add_child(pivot)
	var sensor := PerceptionSensor.new()
	sensor.name = "PerceptionSensor"
	sensor.config = PERCEPTION
	pivot.add_child(sensor)
	_camera = SecurityCamera.new()
	_camera.config = CONFIG
	_camera.pivot_path = ^"../Pivot"
	_camera.sensor_path = ^"../Pivot/PerceptionSensor"
	_camera.sound_path = ^""
	_watcher.add_child(_camera)
	_camera.model.stop_sweep()
	var incident: Array[Receptron] = [Devices.action_receptron(Device.INCIDENT)]
	var controller := Devices.device(_root, "Recorder", Vector3(3, 1, 0), incident)
	Device.of(controller).action_received.connect(_on_incident)
	Devices.link(_watcher, controller)


func after_test() -> void:
	StimulusSystem.clear()


func test_any_entity_with_the_components_detects_and_reports() -> void:
	var decoy := Fixtures.entity(_root, "Decoy", Vector3(0, 0, -6), [], [&"actor.player"])
	await _frames(70)
	assert_array(EventLog.find(&"camera.detected")).is_empty()
	# 0.8 x 0.95 per second: about 1.3 s.
	await _frames(30)
	var detected := EventLog.find(&"camera.detected")
	assert_array(detected).has_size(1)
	assert_str(String(detected[0].data["target"])).is_equal("Decoy")
	await _frames(3)
	assert_int(_incidents.size()).is_equal(1)
	assert_float(_incidents[0].distance_to(decoy.global_position)).is_less(0.01)


func test_an_entity_without_a_hostile_tag_is_ignored() -> void:
	Fixtures.entity(_root, "Bystander", Vector3(0, 0, -6), [], [&"actor.guard"])
	await _frames(150)
	assert_array(EventLog.find(&"camera.detected")).is_empty()


func test_its_own_commands_turn_and_blind_it() -> void:
	StimulusSystem.emit(Device.command_stimulus(Device.PAN_LEFT, _watcher))
	await _frames(3)
	assert_float(_camera.yaw()).is_equal(15.0)
	assert_float(rad_to_deg((_watcher.get_node("Pivot") as Node3D).rotation.y)).is_equal_approx(15.0, 0.01)
	StimulusSystem.emit(Device.command_stimulus(Device.DISABLE, _watcher))
	await _frames(3)
	assert_bool(_camera.is_watching()).is_false()
	Fixtures.entity(_root, "Decoy", Vector3(0, 0, -6), [], [&"actor.player"])
	await _frames(150)
	assert_array(EventLog.find(&"camera.detected")).is_empty()


func _on_incident(action: StringName, stimulus: Stimulus) -> void:
	if action == Device.INCIDENT:
		_incidents.append(stimulus.origin)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
