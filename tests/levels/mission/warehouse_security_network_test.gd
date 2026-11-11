extends GdUnitTestSuite
## Warehouse security network (design/levels/mission-warehouse.md "Security network", ADR 0092; M12a:
## the Security subnet spans several switches): the building's main switch (basement store, breaker
## B) with the security room's, the vault's, the yard's (gate booth, breaker A) and the roof's (at the
## camera mast's foot, breaker A) area switches cabled up to it. The security console (a computer, on
## the security room's switch) reaches every cabled device, lists them in its Security app (ADR 0114)
## and loses a part when a switch is broken or unpowered; the yard's part keeps working on its own
## alarm controller. A camera
## that sees a lit intruder rings every siren through both controllers; with the building switch
## broken a yard camera still rings the yard's sirens, and with both switches broken it tells
## nobody. Every guard (as placed by the people population), its patrol points and the layout's
## markers are within earshot of a siren (31 m of path, 3 m inside the 34 m a siren carries); doors
## and devices keep their state through a save and load.

const Helpers := preload("res://tests/levels/mission/warehouse_security_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
## Devices on the building's switches, SecuritySwitch and its area switches (besides the switches and
## the console itself).
const BUILDING: Array[String] = [
	"CameraHall",
	"CameraOffice",
	"VaultTurret",
	"AlarmController",
	"RadioBaseStation",
	"PanicButtonSecurity",
	"SirenHallNorth",
	"SirenHallWest",
	"SirenOfficeGround",
	"SirenOfficeUpper",
	"SirenBasement",
	"SecurityDoor",
	"BridgeDoor",
	"VaultDoor",
]
## Devices on the security room's area switch (cabled up to SecuritySwitch).
const SECURITY_ROOM: Array[String] = ["AlarmController", "RadioBaseStation", "PanicButtonSecurity", "SecurityDoor"]
## Devices on the yard's switch, YardSwitch, and the roof's, RoofSwitch (both on breaker A's circuit).
const YARD: Array[String] = [
	"CameraGate",
	"CameraYard",
	"CameraRoof",
	"LaserRoofWest",
	"LaserRoofEast",
	"PanicButtonBooth",
	"AlarmControllerYard",
	"SirenDock",
	"SirenEastYard",
	"SirenBackStrip",
	"SirenWestYard",
	"FrontGate",
]
## Cable crossings the deck's Map layout leaves on this network (see _assert_graph_readable()).
const MAP_CROSSINGS := 3
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


func test_the_console_reaches_both_parts_and_each_switch_cuts_only_its_own() -> void:
	await _helpers.load_level(self)
	var console := _helpers.console()
	var rows := _rows(console)
	for device_name: String in BUILDING + YARD:
		assert_bool(rows.has(device_name)).override_failure_message("missing " + device_name).is_true()
		assert_bool(rows.get(device_name, false)).override_failure_message(device_name + " offline").is_true()
	assert_int(rows.size()).is_equal(BUILDING.size() + YARD.size())
	for switch_name: String in ["SecuritySwitch", "YardSwitch"]:
		assert_bool(console.device.reaches(_helpers.device_entity(switch_name))).is_true()
	_assert_graph_readable(console)

	# Breaker B (building power) unpowers the building's switch: the console reaches nothing, but the
	# yard's cameras still reach the yard's controller and it its sirens.
	var breaker_b := _helpers.device_entity("BreakerB").get_node("CircuitBreaker") as CircuitBreaker
	breaker_b.use(null)
	await _helpers.frames(2)
	rows = _rows(console)
	for device_name: String in BUILDING + YARD:
		assert_bool(rows[device_name]).override_failure_message(device_name + " still online").is_false()
	_assert_yard_works(true)
	breaker_b.use(null)
	await _helpers.frames(2)
	assert_bool(_rows(console)["CameraYard"]).is_true()

	# Breaker A (yard lights) unpowers the yard's switch: the yard's part goes offline, the
	# building's stays.
	var breaker_a := _helpers.device_entity("BreakerA").get_node("CircuitBreaker") as CircuitBreaker
	breaker_a.use(null)
	await _helpers.frames(2)
	rows = _rows(console)
	for device_name: String in YARD:
		assert_bool(rows[device_name]).override_failure_message(device_name + " still online").is_false()
	for device_name: String in BUILDING:
		assert_bool(rows[device_name]).override_failure_message(device_name + " offline").is_true()
	_assert_yard_works(false)
	breaker_a.use(null)
	await _helpers.frames(2)

	# Breaking the building's main switch (a pistol round's worth and more) cuts it for good: the
	# console keeps only its own room's switch; the yard still works until its own switch is broken too.
	Breakable.of(_helpers.device_entity("SecuritySwitch")).take_damage(&"damage.ballistic", 100.0)
	await _helpers.frames(2)
	rows = _rows(console)
	for device_name: String in BUILDING + YARD:
		var online := SECURITY_ROOM.has(device_name)
		assert_bool(rows[device_name]).override_failure_message("%s online: %s" % [device_name, not online]).is_equal(
			online
		)
	assert_bool(console.device.reaches(_helpers.door_entity("VaultDoor"))).is_false()
	_assert_yard_works(true)
	Breakable.of(_helpers.device_entity("YardSwitch")).take_damage(&"damage.ballistic", 100.0)
	await _helpers.frames(2)
	_assert_yard_works(false)


func test_a_camera_rings_the_sirens_until_both_switches_are_cut() -> void:
	await _helpers.load_level(self, true)
	var camera := SecurityCamera.of(_helpers.device_entity("CameraHall"))
	camera.model.stop_sweep()
	# A lit intruder (no light component: fully lit) 6 m south of the hall camera, 1 m up.
	_helpers.stand_in("Intruder", Vector3(-1, 1, -4), [&"actor.player"])

	assert_bool(await _helpers.wait_for(&"alarm.raised", 4.0)).is_true()
	await _helpers.seconds(1.5)
	var detected := EventLog.find(&"camera.detected")
	assert_int(int(detected[0].data["controllers"])).is_equal(2)
	var rung := _sirens_started()
	for device_name: String in BUILDING + YARD:
		if device_name.begins_with("Siren"):
			assert_bool(rung.has(device_name)).override_failure_message(device_name + " silent").is_true()

	# Reset both controllers from the console, then break the building's switch: the gate camera
	# still reaches the yard's controller, which rings the yard's sirens only.
	var console := _helpers.console()
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	assert_bool(console.send(Device.RESET, _helpers.device("AlarmController"))).is_true()
	assert_bool(console.send(Device.RESET, _helpers.device("AlarmControllerYard"))).is_true()
	await _helpers.seconds(3.0)
	Breakable.of(_helpers.device_entity("SecuritySwitch")).take_damage(&"damage.ballistic", 100.0)
	EventLog.clear()
	_stand_in_view("Intruder2", "CameraGate", 5.0, 1.35)

	assert_bool(await _helpers.wait_for(&"alarm.raised", 4.0)).is_true()
	await _helpers.seconds(1.5)
	assert_int(int(EventLog.find(&"camera.detected")[0].data["controllers"])).is_equal(1)
	rung = _sirens_started()
	for device_name: String in YARD:
		if device_name.begins_with("Siren"):
			assert_bool(rung.has(device_name)).override_failure_message(device_name + " silent").is_true()
	for device_name: String in BUILDING:
		if device_name.begins_with("Siren"):
			assert_bool(rung.has(device_name)).override_failure_message(device_name + " rang").is_false()

	# Break the yard's switch too: the yard camera sees an intruder but reaches no controller.
	Breakable.of(_helpers.device_entity("YardSwitch")).take_damage(&"damage.ballistic", 100.0)
	EventLog.clear()
	_stand_in_view("Intruder3", "CameraYard", 8.0, 3.0)

	assert_bool(await _helpers.wait_for(&"camera.detected", 4.0)).is_true()
	await _helpers.seconds(1.5)
	assert_int(int(EventLog.find(&"camera.detected")[0].data["controllers"])).is_equal(0)
	assert_array(EventLog.find(&"alarm.raised")).is_empty()
	assert_array(EventLog.find(&"siren.started")).is_empty()


# The deck's Map of the console's whole network (ADR 0099, network_map_checks.gd): boxes apart, no cable
# under a box, every node shown when fitted, deterministic; six groups (one per switch: the main one,
# the security room, the vault, the yard, the roof and, through RTR-01, the office; M12a). Known
# layout limit (open question for the deck's Map, M12a levels report): the main switch's cables to
# four area switches in the other row share lanes and cross (MAP_CROSSINGS), and the fitted zoom of
# this 45-device network in the old 1050 x 440 panel drops to about 0.68 (the deck's panel is larger;
# the player zooms).
func _assert_graph_readable(console: Computer) -> void:
	var rows := MapChecks.rows_from(console.entity)
	var result := MapChecks.check(self, rows, MapChecks.cables(rows), MapChecks.DECK_CONFIG, MAP_CROSSINGS)
	var zoom: float = result["zoom"]
	assert_float(zoom).override_failure_message("fitted zoom %.2f" % zoom).is_greater(0.6)
	assert_int((result["layout"] as NetworkLayout).hubs.size()).is_equal(6)


# The yard's part on its own: the yard cameras reach the yard's controller and it a yard siren.
func _assert_yard_works(expected: bool) -> void:
	var controller := _helpers.device_entity("AlarmControllerYard")
	for camera: String in ["CameraGate", "CameraYard"]:
		(
			assert_bool(_helpers.device(camera).reaches(controller))
			. override_failure_message("%s reaches the yard controller: %s" % [camera, not expected])
			. is_equal(expected)
		)
	assert_bool(Device.of(controller).reaches(_helpers.device_entity("SirenDock"))).is_equal(expected)


# A stand-in intruder `distance` m in front of camera `camera_name` (horizontally), `below` m under it.
func _stand_in_view(entity_name: String, camera_name: String, distance: float, below: float) -> void:
	var camera := SecurityCamera.of(_helpers.device_entity(camera_name))
	camera.model.stop_sweep()
	var axis := camera.entity.global_basis.z
	var at := camera.entity.global_position + Vector3(axis.x, 0, axis.z).normalized() * distance
	_helpers.stand_in(entity_name, at - Vector3(0, below, 0), [&"actor.player"])


# Siren name -> true, for every siren that started since the log was cleared.
func _sirens_started() -> Dictionary:
	var rung := {}
	for entry in EventLog.find(&"siren.started"):
		rung[entry.data["siren"]] = true
	return rung


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
	var console := _helpers.console()
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	console.send(Device.DISABLE, _helpers.device("CameraYard"))
	console.send(Device.DISARM, _helpers.device("AlarmController"))
	await _helpers.seconds(1.0)
	# Breaker A after the commands: it unpowers the yard's switch, which carries the yard camera.
	(_helpers.device_entity("BreakerA").get_node("CircuitBreaker") as CircuitBreaker).use(null)
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
	assert_bool(fresh.console().is_logged_in()).is_true()
	assert_bool(SecurityCamera.of(fresh.device_entity("CameraYard")).disabled).is_true()
	var controller := fresh.device_entity("AlarmController").get_node("AlarmControllerBehaviour") as AlarmController
	assert_bool(controller.armed).is_false()
	assert_bool(fresh.device("SecuritySwitch").broken).is_true()
	assert_bool(fresh.console().device.reaches(fresh.door_entity("VaultDoor"))).is_false()


# Device name -> online, from the console's Security app list.
func _rows(console: Computer) -> Dictionary:
	var rows := {}
	for row in console.devices():
		rows[String(row.device.entity.name)] = row.online
	return rows
