extends GdUnitTestSuite
## Warehouse network (M12a, design/levels/mission-warehouse.md "Network", hacking.md "Levels"): two
## subnets, Office 10.0.10.0/24 (the office switch, both office PCs, the office wall jack) and
## Security 10.0.20.0/24 (both security switches, the console and every security device), joined by
## the router RTR-01 in the basement store, which runs the one tracer (default tuning) watching both.
## RTR-01's admin login (Medium) is written nowhere in the level. Security devices trust the console
## (sirens and the radio base station also their alarm controllers): its Security app lists them all,
## the office PCs' list none. A deck (minimal user entity, network_fixtures.gd) plugs into the office
## jack and sees the office and RTR-01 only; hacking RTR-01 reveals the Security subnet. The level is
## loaded once (the tests leave it as they found it, design/tech/testing.md "Writing fast tests").

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const SECURITY := "Population/Security/"
## Entity paths under Population/Security, by subnet.
const OFFICE: Array[String] = [
	"Network/OfficeSwitch", "Network/OfficeWallJack", "Network/OfficePc1", "Network/OfficePc2"
]
const SECURITY_DEVICES: Array[String] = [
	"Devices/SecuritySwitch",
	"Devices/YardSwitch",
	"Devices/SecurityRoomSwitch",
	"Devices/VaultSwitch",
	"Devices/RoofSwitch",
	"Devices/SecurityConsole",
	"Devices/CameraGate",
	"Devices/CameraYard",
	"Devices/CameraHall",
	"Devices/CameraOffice",
	"Devices/CameraRoof",
	"Devices/VaultTurret",
	"Devices/AlarmController",
	"Devices/AlarmControllerYard",
	"Devices/RadioBaseStation",
	"Devices/PanicButtonSecurity",
	"Devices/PanicButtonBooth",
	"Devices/LaserRoofWest",
	"Devices/LaserRoofEast",
	"Devices/ApYard",
	"Devices/SirenDock",
	"Devices/SirenEastYard",
	"Devices/SirenBackStrip",
	"Devices/SirenWestYard",
	"Devices/SirenHallNorth",
	"Devices/SirenHallWest",
	"Devices/SirenOfficeGround",
	"Devices/SirenOfficeUpper",
	"Devices/SirenBasement",
	"Doors/FrontGate",
	"Doors/SecurityDoor",
	"Doors/BridgeDoor",
	"Doors/VaultDoor",
]
## In front of the office wall jack (second office, east wall x 19.75), on the upper floor.
const AT_JACK := Vector3(18.9, 4.5, 10)

var _level: Node3D


func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func _entity(path: String) -> Node3D:
	return _level.get_node(SECURITY + path) as Node3D


func _device(path: String) -> Device:
	return Device.of(_entity(path))


func _router() -> Node3D:
	return _entity("Network/Rtr01")


func test_two_subnets_with_addresses_and_names_joined_by_rtr01() -> void:
	var addresses: Dictionary[String, String] = {}
	for group: Array[String] in [OFFICE, SECURITY_DEVICES]:
		var subnet := &"office" if group == OFFICE else &"security"
		var prefix := "10.0.10." if group == OFFICE else "10.0.20."
		for path: String in group:
			var device := _device(path)
			assert_str(String(DeviceNetwork.subnet_of(device))).override_failure_message(path).is_equal(subnet)
			assert_str(device.address).override_failure_message(path).starts_with(prefix)
			assert_bool(addresses.has(device.address)).override_failure_message(path + " shares an address").is_false()
			addresses[device.address] = path
			assert_bool(device.entity.has_meta(&"display_name")).override_failure_message(path).is_true()
	# The router joins exactly the two subnets; it is on the office side (10.0.10.1).
	var router := Router.of(_router())
	assert_object(router).is_not_null()
	assert_array(router.subnets()).contains_exactly_in_any_order([&"office", &"security"])
	assert_str(Device.of(_router()).address).is_equal("10.0.10.1")
	assert_str(NetworkSource.display_name(Device.of(_router()))).is_equal("RTR-01")
	# The office jack is a real wall jack: the deck plugs in there.
	var jack := _device("Network/OfficeWallJack")
	assert_int(DeviceNetwork.port_kind(jack)).is_equal(Device.DeckPort.JACK)
	assert_bool(jack.accepts_tool(Device.DECK_TOOL)).is_true()


func test_rtr01_runs_the_one_tracer_and_its_medium_admin_login_is_written_nowhere() -> void:
	var tracers := Tracer.all(get_tree())
	assert_int(tracers.size()).is_equal(1)
	var tracer := tracers[0]
	assert_object(tracer.entity).is_same(_router())
	assert_array(tracer.watched).contains_exactly_in_any_order([&"office", &"security"])
	assert_object(tracer.config).is_same(Tracer.DEFAULT_CONFIG)
	for path: String in ["Network/OfficePc1", "Devices/SecurityConsole", "Devices/CameraYard"]:
		assert_array(Tracer.watching(_device(path))).override_failure_message(path).contains([tracer])
	var accounts := DeviceAccounts.of(_router()).accounts
	assert_int(accounts.size()).is_equal(1)
	assert_int(accounts[0].strength).is_equal(DeviceAccount.Strength.MEDIUM)
	assert_bool(accounts[0].admin).is_true()
	# No datapad, mail or file in the level gives the password away.
	var password := accounts[0].password
	for text in _level_texts():
		assert_str(text).override_failure_message("RTR-01's password is written in: " + text).not_contains(password)


func test_security_devices_trust_the_console_and_the_office_pcs_control_nothing() -> void:
	var console := Computer.of(_entity("Devices/SecurityConsole"))
	var listed: Array[String] = []
	for row in console.devices():
		listed.append(String(_level.get_node(SECURITY).get_path_to(row.device.entity)))
	for path: String in SECURITY_DEVICES:
		var device := _device(path)
		# Network gear (switches, AP-YARD) carries traffic and takes no orders.
		if path.contains("Switch") or path.ends_with("ApYard") or path.ends_with("SecurityConsole"):
			continue
		assert_array(DeviceNetwork.trusted(device)).override_failure_message(path).contains([console.device])
		assert_array(listed).override_failure_message(path + " not listed").contains([path])
	for path: String in ["Network/OfficePc1", "Network/OfficePc2"]:
		var pc := Computer.of(_entity(path))
		assert_array(pc.devices()).override_failure_message(path).is_empty()
		# M12b: RTR-01's rules keep the office off the Security subnet (but for the console), and the
		# door obeys the console only anyway.
		assert_bool(pc.device.reaches(_entity("Doors/VaultDoor"))).is_false()
		assert_bool(pc.send(Device.OPEN, _device("Doors/VaultDoor"))).is_false()
	# The console's known login (the audit note) works bare-handed; it opens the vault door remotely.
	assert_bool(console.log_in("dmarsh", "harbor77")).is_true()
	assert_bool(console.send(Device.UNLOCK, _device("Doors/VaultDoor"))).is_true()
	await _frames(3)
	assert_bool(Door.of(_entity("Doors/VaultDoor")).is_locked()).is_false()
	assert_bool(console.send(Device.LOCK, _device("Doors/VaultDoor"))).is_true()
	await _frames(3)
	assert_bool(Door.of(_entity("Doors/VaultDoor")).is_locked()).is_true()
	console.log_out()


func test_an_area_switch_cuts_only_its_own_devices_from_the_security_subnet() -> void:
	var console := Computer.of(_entity("Devices/SecurityConsole"))
	var vault: Array[String] = ["Devices/VaultTurret", "Doors/VaultDoor", "Doors/BridgeDoor", "Devices/CameraOffice"]
	# M12b: the roof lasers link by radio to AP-YARD (on the yard's switch): the roof's switch feeds
	# only the roof camera.
	var roof: Array[String] = ["Devices/CameraRoof"]
	var others: Array[String] = [
		"Devices/AlarmController",
		"Devices/CameraHall",
		"Devices/CameraGate",
		"Doors/FrontGate",
		"Devices/LaserRoofWest",
		"Devices/LaserRoofEast",
	]
	# The vault's switch unpowered: the vault and upper corridor devices go offline, the rest of the
	# subnet (the security room, the hall, the yard and the roof) stays reachable.
	var powered := Powered.of(_entity("Devices/VaultSwitch"))
	powered.on = false
	await _frames(2)
	_assert_reached(console, vault, false)
	_assert_reached(console, roof + others, true)
	powered.on = true
	await _frames(2)
	_assert_reached(console, vault, true)
	# The roof's switch broken: the roof's devices go offline, the yard's switch above it does not.
	var roof_switch := _device("Devices/RoofSwitch")
	roof_switch.load_state({"broken": true})
	await _frames(2)
	_assert_reached(console, roof, false)
	_assert_reached(console, vault + others, true)
	roof_switch.load_state({"broken": false})
	await _frames(2)
	_assert_reached(console, roof, true)


func _assert_reached(console: Computer, paths: Array[String], expected: bool) -> void:
	for path: String in paths:
		(
			assert_bool(console.device.reaches(_entity(path)))
			. override_failure_message("console reaches %s: %s" % [path, not expected])
			. is_equal(expected)
		)


func test_the_deck_on_the_office_jack_sees_the_office_and_hacking_rtr01_reveals_security() -> void:
	var user := Net.user(_level, AT_JACK)
	var session := DeckSession.of(user)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	assert_bool(session.plug(_device("Network/OfficeWallJack"), Net.deck_stack())).is_true()
	assert_str(session.source.address).is_equal("10.0.10.40")
	await _frames(15)
	var seen := _map(session)
	assert_array(seen).contains_exactly_in_any_order(OFFICE + ["Network/Rtr01"])
	# Hacking the router (an account on it: the Icebreaker at Trained, or a login) opens Security.
	DeviceAccounts.of(_router()).grant(user, "admin")
	session.refresh()
	await _frames(15)
	seen = _map(session)
	for path: String in SECURITY_DEVICES:
		assert_array(seen).override_failure_message(path + " not on the map").contains([path])
	# Only the scan behind the router added trace on the Sentry tracer (the office, the jack's own
	# subnet, shows without a scan: ADR 0121).
	var tracer := _router().get_node("Tracer") as Tracer
	assert_float(tracer.trace_of(user)).is_between(5.0, 10.5)
	session.unplug()
	DeviceAccounts.of(_router()).set_password("admin", DeviceAccounts.of(_router()).account("admin").password)
	user.free()


# Entity paths (under Population/Security) of the devices on the deck's map.
func _map(session: DeckSession) -> Array[String]:
	var found: Array[String] = []
	var root := _level.get_node(SECURITY)
	for each in session.map_devices():
		found.append(String(root.get_path_to(each.entity)))
	return found


# Every text the level can teach: datapads (Readable text and codes) and computer mail and files.
func _level_texts() -> Array[String]:
	var texts: Array[String] = []
	for node in _level.find_children("*", "Readable", true, false):
		var readable := node as Readable
		texts.append(readable.text)
		texts.append(str(readable.codes))
	for node in _level.find_children("*", "Computer", true, false):
		var computer := node as Computer
		if computer.data == null:
			continue
		for document in computer.data.mail + computer.data.files:
			texts.append(document.text)
			texts.append(str(document.codes))
	return texts


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
