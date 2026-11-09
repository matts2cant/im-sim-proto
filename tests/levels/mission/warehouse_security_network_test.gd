extends GdUnitTestSuite
## Warehouse security network (design/levels/mission-warehouse.md "Security network"): the security
## console reaches every device cabled to the security switch and loses them when the switch is
## broken or unpowered (breaker B); a camera that sees a lit intruder rings every siren through the
## alarm controller, and once the switch is broken it tells nobody; every guard (as placed by the
## people population), its patrol points and the layout's markers are within earshot of a siren (31
## m of path, 3 m inside the 34 m a siren carries); doors and devices keep their state through a
## save and load.

const Helpers := preload("res://tests/levels/mission/warehouse_security_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## Devices on the security switch (besides the switch and the console itself).
const NETWORK: Array[String] = [
	"CameraGate",
	"CameraYard",
	"CameraHall",
	"CameraOffice",
	"VaultTurret",
	"AlarmController",
	"RadioBaseStation",
	"PanicButtonSecurity",
	"PanicButtonBooth",
	"SirenDock",
	"SirenEastYard",
	"SirenBackStrip",
	"SirenWestYard",
	"SirenHallNorth",
	"SirenHallWest",
	"SirenOfficeGround",
	"SirenOfficeUpper",
	"SirenBasement",
	"FrontGate",
	"SecurityDoor",
	"BridgeDoor",
	"VaultDoor",
]
const HEARD: StringName = &"test.heard_siren"
## A siren is heard at intensity 35 x (1 - d / 35): 4 or more means 31 m of path or less.
const EARSHOT_MIN_INTENSITY := 4.0

var _helpers: Helpers


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_helpers = Helpers.new()


func after_test() -> void:
	_helpers.teardown()
	StimulusSystem.clear()


func test_the_console_reaches_its_devices_and_loses_them_with_the_switch() -> void:
	await _helpers.load_level(self)
	var console := _helpers.console()
	var rows := _rows(console)
	for device_name: String in NETWORK + ["SecuritySwitch"]:
		assert_bool(rows.has(device_name)).override_failure_message("missing " + device_name).is_true()
		assert_bool(rows.get(device_name, false)).override_failure_message(device_name + " offline").is_true()

	# Breaker B (building power) unpowers the switch: everything behind it goes offline.
	var breaker := _helpers.device_entity("BreakerB").get_node("CircuitBreaker") as CircuitBreaker
	breaker.use(null)
	await _helpers.frames(2)
	rows = _rows(console)
	for device_name: String in NETWORK:
		assert_bool(rows[device_name]).override_failure_message(device_name + " still online").is_false()
	breaker.use(null)
	await _helpers.frames(2)
	assert_bool(_rows(console)["CameraYard"]).is_true()

	# Breaking the switch (a pistol round's worth and more) cuts it for good.
	Breakable.of(_helpers.device_entity("SecuritySwitch")).take_damage(&"damage.ballistic", 100.0)
	await _helpers.frames(2)
	rows = _rows(console)
	for device_name: String in NETWORK:
		assert_bool(rows[device_name]).override_failure_message(device_name + " still online").is_false()
	assert_bool(console.device.reaches(_helpers.door_entity("VaultDoor"))).is_false()


func test_a_camera_seeing_an_intruder_rings_the_sirens_until_the_switch_is_cut() -> void:
	await _helpers.load_level(self, true)
	var camera := SecurityCamera.of(_helpers.device_entity("CameraHall"))
	camera.model.stop_sweep()
	# A lit intruder (no light component: fully lit) 6 m south of the hall camera, 1 m up.
	_helpers.stand_in("Intruder", Vector3(-1, 1, -4), [&"actor.player"])

	assert_bool(await _helpers.wait_for(&"alarm.raised", 4.0)).is_true()
	await _helpers.seconds(1.5)
	var detected := EventLog.find(&"camera.detected")
	assert_int(int(detected[0].data["controllers"])).is_equal(1)
	var rung := {}
	for entry in EventLog.find(&"siren.started"):
		rung[entry.data["siren"]] = true
	for device_name: String in NETWORK:
		if device_name.begins_with("Siren"):
			assert_bool(rung.has(device_name)).override_failure_message(device_name + " silent").is_true()

	# Reset from the console, then break the switch: the gate camera still sees an intruder but
	# reaches no controller, and nothing rings.
	var console := _helpers.console()
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	assert_bool(console.send(Device.RESET, _helpers.device("AlarmController"))).is_true()
	await _helpers.seconds(3.0)
	Breakable.of(_helpers.device_entity("SecuritySwitch")).take_damage(&"damage.ballistic", 100.0)
	EventLog.clear()
	var gate := SecurityCamera.of(_helpers.device_entity("CameraGate"))
	gate.model.stop_sweep()
	var axis := gate.entity.global_basis.z
	_helpers.stand_in(
		"Intruder2",
		gate.entity.global_position + Vector3(axis.x, 0, axis.z).normalized() * 5.0 - Vector3(0, 1.35, 0),
		[&"actor.player"]
	)

	assert_bool(await _helpers.wait_for(&"camera.detected", 4.0)).is_true()
	await _helpers.seconds(1.5)
	assert_int(int(EventLog.find(&"camera.detected")[0].data["controllers"])).is_equal(0)
	assert_array(EventLog.find(&"alarm.raised")).is_empty()
	assert_array(EventLog.find(&"siren.started")).is_empty()


func test_every_guard_post_and_patrol_point_hears_a_siren() -> void:
	await _helpers.load_level(self, true)
	# The guards as the people population placed them and their patrol points, and the layout's
	# markers.
	var spots: Dictionary[String, Vector3] = _helpers.guard_spots.duplicate()
	assert_int(spots.size()).is_greater_equal(16)
	for group: String in ["Guards", "PatrolPoints"]:
		for marker: Node3D in _helpers.level.get_node("LayoutMarkers/" + group).get_children():
			spots["Marker" + marker.name] = marker.global_position
	var listeners: Dictionary[String, Node3D] = {}
	for spot: String in spots:
		var heard := Fixtures.receptron(&"alarm.siren", [Fixtures.add_tag(HEARD)])
		heard.min_intensity = EARSHOT_MIN_INTENSITY
		var ear := spots[spot] + Vector3.UP * 1.6
		listeners[spot] = _helpers.stand_in("Ear" + spot, ear, [], [heard])

	var console := _helpers.console()
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	assert_bool(console.send(Device.TRIGGER, _helpers.device("AlarmController"))).is_true()
	await _helpers.seconds(2.5)

	var deaf: PackedStringArray = []
	for marker_name: String in listeners:
		if not ActorState.has(listeners[marker_name], HEARD):
			deaf.append(marker_name)
	assert_array(deaf).is_empty()


func test_save_and_load_keep_doors_and_devices() -> void:
	await _helpers.load_level(self)
	var level := _helpers.level
	_helpers.door("SideDoor").open()
	Lockable.of(_helpers.door_entity("BackGate")).unlock(null, &"test")
	(_helpers.device_entity("BreakerA").get_node("CircuitBreaker") as CircuitBreaker).use(null)
	var console := _helpers.console()
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	console.send(Device.DISABLE, _helpers.device("CameraYard"))
	console.send(Device.DISARM, _helpers.device("AlarmController"))
	await _helpers.seconds(1.0)
	Breakable.of(_helpers.device_entity("SecuritySwitch")).take_damage(&"damage.ballistic", 100.0)
	await _helpers.frames(2)
	var snapshot := LevelSnapshot.capture(level)

	var fresh := Helpers.new()
	await fresh.load_level(self)
	LevelSnapshot.apply(fresh.level, snapshot)
	await fresh.frames(2)

	assert_bool(fresh.door("SideDoor").is_open()).is_true()
	assert_bool(fresh.door("BackGate").is_locked()).is_false()
	assert_bool(fresh.door("VaultDoor").is_locked()).is_true()
	assert_bool((fresh.device_entity("BreakerA").get_node("CircuitBreaker") as CircuitBreaker).closed).is_false()
	assert_bool(fresh.console().logged_in).is_true()
	assert_bool(SecurityCamera.of(fresh.device_entity("CameraYard")).disabled).is_true()
	var controller := fresh.device_entity("AlarmController").get_node("AlarmControllerBehaviour") as AlarmController
	assert_bool(controller.armed).is_false()
	assert_bool(fresh.device("SecuritySwitch").broken).is_true()
	assert_bool(fresh.console().device.reaches(fresh.door_entity("VaultDoor"))).is_false()


# Device name -> online, from the console's device list.
func _rows(console: Terminal) -> Dictionary:
	var rows := {}
	for row in console.devices():
		rows[String(row.device.entity.name)] = row.online
	return rows
