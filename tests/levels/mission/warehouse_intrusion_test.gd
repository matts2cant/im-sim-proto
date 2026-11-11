extends GdUnitTestSuite
## Warehouse intrusion data (M12b, design/levels/mission-warehouse.md "Wireless and intrusion
## (M12b)", ADR 0116): every networked device runs software the deck's Map shows (vendor, product,
## version); two exploits are found in the level: "Helix default service login" (Helix CAM-3
## 2.0-2.1, admin) in office PC 1's mail "Camera firmware", and "Vigil AC debug port" (Vigil AC-200
## 3.0-3.2, admin) on the field service datapad on the water tower deck. The Helix one matches four
## cameras, not the roof camera (2.2, just out of range); the Vigil one matches the yard's alarm
## controller (3.1), not the building's (3.4). A run seen by the Sentry tracer (RTR-01, watching
## Security) patches every Helix CAM-3 on the subnet. RTR-01's rules: Security -> Office allow,
## Office -> SEC-CONSOLE allow, Office -> Security deny; a deck with access to RTR-01 still passes
## (only rules from "you" judge it). The sirens and both alarm controllers are on the Security
## subnet, so no RTR-01 rule silences them. The level is loaded once.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const SECURITY := "Population/Security/"
const HELIX := &"helix_default_login"
const VIGIL := &"vigil_ac_debug"
## Every camera: the Helix exploit matches all but the roof's (firmware 2.2).
const CAMERAS: Dictionary[String, String] = {
	"Devices/CameraGate": "2.1",
	"Devices/CameraYard": "2.0",
	"Devices/CameraHall": "2.1",
	"Devices/CameraOffice": "2.1",
	"Devices/CameraRoof": "2.2",
}
## On the roof 6.4 m from AP-YARD (Untrained Wi-Fi range), the user's eye (warehouse_ap_yard_test.gd).
const ROOF_EYE := Vector3(0, 11.15, -4.2)
## In front of the office wall jack, upper floor (warehouse_hacking_test.gd).
const AT_JACK := Vector3(18.9, 4.5, 10)

var _level: Node3D
var _tracer_state: Dictionary


func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)
	_tracer_state = _tracer().save_state()


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	_tracer().load_state(_tracer_state)
	for device in _security_devices():
		device.intrusion.from_dict({"patched": [], "log": [], "exploit_access": {}})
	StimulusSystem.clear()


func _entity(path: String) -> Node3D:
	return _level.get_node(SECURITY + path) as Node3D


func _device(path: String) -> Device:
	return Device.of(_entity(path))


func _tracer() -> Tracer:
	return _entity("Network/Rtr01").get_node("Tracer") as Tracer


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_every_networked_device_runs_software() -> void:
	var missing: PackedStringArray = []
	for node in _level.get_node(SECURITY).find_children("*", "Device", true, false):
		var device := node as Device
		# Passive gear without software: wall jacks, and the guest access point placeholder (no subnet).
		if device.address.is_empty() or DeviceNetwork.port_kind(device) == Device.DeckPort.JACK:
			continue
		if device.software == null or device.software.version.is_empty():
			missing.append(String(_level.get_node(SECURITY).get_path_to(device.entity)))
	assert_array(Array(missing)).is_empty()
	for path: String in CAMERAS:
		assert_str(_device(path).software.label()).is_equal("Helix CAM-3 " + CAMERAS[path])
	assert_str(_device("Devices/AlarmController").software.label()).is_equal("Vigil AC-200 3.4")
	assert_str(_device("Devices/AlarmControllerYard").software.label()).is_equal("Vigil AC-200 3.1")
	assert_str(_device("Devices/ApYard").software.label()).is_equal("Skylink AP-5 2.2")


func test_the_mail_and_the_datapad_teach_their_exploits() -> void:
	var user := Net.user(_level, AT_JACK)
	# Office PC 1's mail "Camera firmware".
	var pc := Computer.of(_entity("Network/OfficePc1"))
	var mail: ComputerDocument = null
	for document in pc.data.mail:
		if document.title == "Camera firmware":
			mail = document
	assert_object(mail).is_not_null()
	assert_bool(pc.read(mail, user, "Mail")).is_true()
	# The field service notes on the water tower deck (20 m), beside the sniper rifle.
	var pad := _entity("Items/TowerNotes")
	assert_float(pad.global_position.y).is_between(20.0, 20.1)
	var readable := pad.get_node("Readable") as Readable
	PersonalLog.of(user).read(readable.entry(), "Datapad")
	var known := _ids(PersonalLog.of(user).known_exploits())
	assert_array(known).contains_exactly_in_any_order([HELIX, VIGIL])
	var helix := _known(user, HELIX)
	assert_str(helix.vendor + " " + helix.product).is_equal("Helix CAM-3")
	assert_bool(helix.is_admin()).is_true()
	var vigil := _known(user, VIGIL)
	assert_str(vigil.vendor + " " + vigil.product).is_equal("Vigil AC-200")
	assert_bool(vigil.is_admin()).is_true()
	# Only these two documents teach exploits.
	var teaching := 0
	for text_holder in _level.find_children("*", "Readable", true, false):
		teaching += 1 if not (text_holder as Readable).exploits.is_empty() else 0
	for node in _level.find_children("*", "Computer", true, false):
		var computer := node as Computer
		if computer.data != null:
			for document in computer.data.mail + computer.data.files:
				teaching += 1 if not document.exploits.is_empty() else 0
	assert_int(teaching).is_equal(2)
	user.free()


func test_the_exploits_match_as_designed() -> void:
	var user := Net.user(_level, AT_JACK)
	_learn_all(user)
	var helix := _known(user, HELIX)
	var vigil := _known(user, VIGIL)
	for path: String in CAMERAS:
		var expected := CAMERAS[path] != "2.2"
		assert_bool(helix.matches(_device(path).software)).override_failure_message(path).is_equal(expected)
	assert_bool(vigil.matches(_device("Devices/AlarmControllerYard").software)).is_true()
	assert_bool(vigil.matches(_device("Devices/AlarmController").software)).is_false()
	# No other device on either subnet matches either exploit.
	for device in _security_devices():
		if CAMERAS.has(_path(device)) or _path(device).begins_with("Devices/AlarmController"):
			continue
		(
			assert_bool(helix.matches(device.software) or vigil.matches(device.software))
			. override_failure_message(_path(device))
			. is_false()
		)
	user.free()


func test_a_seen_helix_run_over_ap_yard_patches_every_helix_camera() -> void:
	var user := Net.user(_level, ROOF_EYE)
	_learn_all(user)
	var session := DeckSession.of(user)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	session.config.exploit_time = 0.5
	AccessPoint.of(_entity("Devices/ApYard")).grant_key(user)
	assert_bool(session.plug(_device("Devices/ApYard"), Net.deck_stack())).is_true()
	await _frames(10)
	var tool := ExploitTool.of(user)
	var camera := _device("Devices/CameraYard")
	assert_array(_ids(tool.matching(camera))).contains_exactly([HELIX])
	assert_array(tool.matching(_device("Devices/CameraRoof"))).is_empty()
	tool.select(camera)
	assert_bool(tool.start(_known(user, HELIX))).is_true()
	await _frames(45)
	assert_str(String(tool.last_end)).is_equal("done")
	# The run works once: admin on the camera without an account.
	assert_bool(camera.is_admin(user)).is_true()
	# The Sentry tracer saw it: every Helix CAM-3 on the Security subnet is patched, the rest not.
	for path: String in CAMERAS:
		assert_bool(_device(path).intrusion.is_patched(_known(user, HELIX))).override_failure_message(path).is_true()
	assert_bool(_device("Devices/AlarmControllerYard").intrusion.is_patched(_known(user, HELIX))).is_false()
	assert_array(tool.matching(_device("Devices/CameraGate"))).contains_exactly([_known(user, HELIX)])
	assert_bool(tool.can_run(_device("Devices/CameraGate"), _known(user, HELIX))).is_false()
	session.unplug()
	user.free()


func test_rtr01_keeps_the_office_off_security_except_the_console() -> void:
	var router := Router.of(_entity("Network/Rtr01"))
	assert_int(router.rules.size()).is_equal(3)
	assert_bool(router.default_allow).is_true()
	var pc := _device("Network/OfficePc1")
	# Office devices reach the console only; the security devices reach the office.
	assert_bool(pc.reaches(_entity("Devices/SecurityConsole"))).is_true()
	for path: String in ["Doors/VaultDoor", "Devices/CameraHall", "Devices/AlarmController"]:
		assert_bool(pc.reaches(_entity(path))).override_failure_message(path).is_false()
	assert_bool(_device("Devices/SecurityConsole").reaches(_entity("Network/OfficePc1"))).is_true()
	# RTR-01 itself sends freely: its tracer's incidents reach the alarm controllers.
	for path: String in ["Devices/AlarmController", "Devices/AlarmControllerYard"]:
		assert_bool(_device("Network/Rtr01").reaches(_entity(path))).override_failure_message(path).is_true()
	# A deck on the office jack with access to RTR-01 passes (no rule names "you").
	var user := Net.user(_level, AT_JACK)
	var jack := NetworkSource.for_user(user, _device("Network/OfficeWallJack"), NetworkSource.Kind.JACK)
	assert_bool(jack.reaches(get_tree(), _device("Devices/CameraHall"))).is_false()
	DeviceAccounts.of(_entity("Network/Rtr01")).grant(user, "admin")
	assert_bool(jack.reaches(get_tree(), _device("Devices/CameraHall"))).is_true()
	DeviceAccounts.of(_entity("Network/Rtr01")).set_password(
		"admin", DeviceAccounts.of(_entity("Network/Rtr01")).account("admin").password
	)
	# Every siren and both alarm controllers are on Security: no rule at RTR-01 stands between them.
	for node in _level.find_children("Siren*", "", true, false):
		var siren := Device.of(node)
		if siren != null:
			assert_str(String(DeviceNetwork.subnet_of(siren))).override_failure_message(node.name).is_equal("security")
	user.free()


func _learn_all(user: Node) -> void:
	var exploits: Array[Exploit] = []
	exploits.append_array((_entity("Items/TowerNotes").get_node("Readable") as Readable).exploits)
	for document in Computer.of(_entity("Network/OfficePc1")).data.mail:
		exploits.append_array(document.exploits)
	Net.learn(user, exploits)


func _known(user: Node, exploit_id: StringName) -> Exploit:
	for exploit in PersonalLog.of(user).known_exploits():
		if exploit.id == exploit_id:
			return exploit
	return null


func _ids(list: Array[Exploit]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for exploit in list:
		ids.append(exploit.id)
	return ids


func _path(device: Device) -> String:
	return String(_level.get_node(SECURITY).get_path_to(device.entity))


# Every device with an address under Population/Security.
func _security_devices() -> Array[Device]:
	var found: Array[Device] = []
	for node in _level.get_node(SECURITY).find_children("*", "Device", true, false):
		if not (node as Device).address.is_empty():
			found.append(node as Device)
	return found
