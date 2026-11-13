extends GdUnitTestSuite
## Gallery room 5 (security wing) on its own: its network in the M12a/M12b format
## (design/levels/hub-and-gallery.md "5 Security wing", "Network"). Two subnets joined by RTR-05 in
## the hall's linking bay (ADR 0130 step 3, with every switch and the rack alarm controller):
## Operations (the booth computer and the hall's wall jack on SW-OPS) and Security (every security
## device). Security spans an area switch per room with devices, each cabled up to SW-SECURITY
## (breaker B): SW-BOOTH, SW-LASERS, SW-CORRIDOR, SW-VAULT. Every device has an address, a display
## name and a kind (Map icon); the security devices trust the booth computer (sirens and the radio
## base station also the alarm controller). RTR-05's Weak admin login is in the booth computer's
## mail; a deck on the jack reaches only Operations and the router until it has an account there.
## The deck's Map of the whole network, from the jack and from the booth computer, reads well: two
## subnet boxes, no crossing. Room-local coordinates. The room is loaded once (its tests only query
## it).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const MountChecks := preload("res://tests/levels/device_mount_checks.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/security_wing/security_wing.tscn")
const ORIGIN := Vector3(320, 0, 300)
const OPS := &"wing_ops"
const SECURITY := &"wing_security"
## Entity path -> [subnet, address, display name].
const NETWORK: Dictionary[String, Array] = {
	"Devices/Jack": [OPS, "10.0.15.40", "WING-JACK"],
	"Devices/Bay/OpsSwitch": [OPS, "10.0.15.2", "SW-OPS"],
	"Devices/BoothComputer": [OPS, "10.0.15.10", "BOOTH-PC"],
	"Devices/Bay/Rtr05": [OPS, "10.0.15.1", "RTR-05"],
	"Devices/Bay/SecuritySwitch": [SECURITY, "10.0.25.2", "SW-SECURITY"],
	"Devices/Bay/BoothSwitch": [SECURITY, "10.0.25.3", "SW-BOOTH"],
	"Devices/Bay/LaserSwitch": [SECURITY, "10.0.25.4", "SW-LASERS"],
	"Devices/Bay/CorridorSwitch": [SECURITY, "10.0.25.5", "SW-CORRIDOR"],
	"Devices/Bay/VaultSwitch": [SECURITY, "10.0.25.6", "SW-VAULT"],
	"Devices/Bay/Controller": [SECURITY, "10.0.25.10", "ALARM-WING"],
	"Devices/BaseStation": [SECURITY, "10.0.25.11", "RADIO-WING"],
	"Devices/PanicButton": [SECURITY, "10.0.25.12", "PANIC-HALL"],
	"Devices/Camera": [SECURITY, "10.0.25.21", "CAM-CORRIDOR"],
	"Devices/Turret": [SECURITY, "10.0.25.22", "TURRET-VAULT"],
	"Devices/SirenHall": [SECURITY, "10.0.25.31", "SIREN-HALL"],
	"Devices/SirenCorridor": [SECURITY, "10.0.25.32", "SIREN-CORRIDOR"],
	"Devices/LaserLow": [SECURITY, "10.0.25.41", "LASER-LOW"],
	"Devices/LaserHigh": [SECURITY, "10.0.25.42", "LASER-HIGH"],
	"Devices/LaserPair": [SECURITY, "10.0.25.43", "LASER-PAIR"],
	"Doors/VaultDoor/Hardware/Controller": [SECURITY, "10.0.25.51", "DOOR-VAULT"],
	"Doors/D4Electronic/Hardware/Controller": [SECURITY, "10.0.25.52", "DOOR-D4"],
}
## Switch -> [the room it serves (Shell/...), the devices cabled to it]. Every switch stands in the
## hall's bay (ADR 0130 step 3).
const SWITCHES: Dictionary[String, Array] = {
	"Devices/Bay/OpsSwitch": ["Hall", ["Devices/Jack", "Devices/BoothComputer"]],
	"Devices/Bay/SecuritySwitch":
	[
		"Hall",
		[
			"Devices/Bay/BoothSwitch",
			"Devices/Bay/LaserSwitch",
			"Devices/Bay/CorridorSwitch",
			"Devices/Bay/VaultSwitch",
			"Devices/PanicButton",
			"Devices/SirenHall",
			"Doors/D4Electronic/Hardware/Controller",
		]
	],
	"Devices/Bay/BoothSwitch": ["Booth", ["Devices/Bay/Controller", "Devices/BaseStation"]],
	"Devices/Bay/LaserSwitch": ["LaserHall", ["Devices/LaserLow", "Devices/LaserHigh", "Devices/LaserPair"]],
	"Devices/Bay/CorridorSwitch": ["Corridor", ["Devices/Camera", "Devices/SirenCorridor"]],
	"Devices/Bay/VaultSwitch": ["Vault", ["Devices/Turret", "Doors/VaultDoor/Hardware/Controller"]],
}

var _room: Node3D
var _user: Node


func before() -> void:
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)
	_user = auto_free(Node.new())
	_user.name = "WingNetworkUser"
	add_child(_user)
	await KitGeometry.settle(get_tree(), 5)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func _node(path: String) -> Node3D:
	return _room.get_node(path) as Node3D


func _device(path: String) -> Device:
	return Device.of(_node(path))


# Whether the world point `point` lies over `room`'s interior (5 cm margin into its walls).
func _inside(point: Vector3, room: Room) -> bool:
	var local := room.to_local(point)
	var half := room.size * 0.5
	return absf(local.x) <= half.x + 0.05 and absf(local.z) <= half.z + 0.05


func test_two_subnets_behind_rtr05_with_addresses_names_kinds_and_trust() -> void:
	for path: String in NETWORK:
		var device := _device(path)
		assert_str(String(DeviceNetwork.subnet_of(device))).override_failure_message(path).is_equal(
			String(NETWORK[path][0])
		)
		assert_str(device.address).override_failure_message(path).is_equal(NETWORK[path][1])
		assert_str(NetworkSource.display_name(device)).override_failure_message(path).is_equal(NETWORK[path][2])
		# Every device is of a kind the Map draws an icon for (ADR 0121).
		var kind := DeviceKinds.shipped().kind_for(device.entity)
		assert_object(kind).override_failure_message(path).is_not_null()
		assert_bool(kind.icon.is_empty()).override_failure_message(path).is_false()
	var router := Router.of(_node("Devices/Bay/Rtr05"))
	assert_array(router.subnets()).contains_exactly_in_any_order([OPS, SECURITY])
	assert_array(router.addresses()).is_equal(["10.0.15.1", "10.0.25.254"])
	var info := Router.subnet_info(get_tree())
	assert_str(info[OPS].title()).is_equal("OPERATIONS  10.0.15.0/24")
	assert_str(info[SECURITY].title()).is_equal("SECURITY  10.0.25.0/24")
	assert_float(absf(info[OPS].map_color.h - info[SECURITY].map_color.h)).is_greater(0.2)
	assert_int(DeviceNetwork.port_kind(_device("Devices/Jack"))).is_equal(NetworkSource.Kind.JACK)
	# The security devices trust the booth computer; sirens and the radio also the controller.
	var booth := _device("Devices/BoothComputer")
	var controller := _device("Devices/Bay/Controller")
	for path: String in NETWORK:
		if NETWORK[path][0] != SECURITY or DeviceNetwork.is_network_gear(_device(path)):
			continue
		var trusted := DeviceNetwork.trusted(_device(path))
		if path in ["Devices/SirenHall", "Devices/SirenCorridor", "Devices/BaseStation"]:
			assert_array(trusted).override_failure_message(path).contains_exactly_in_any_order([booth, controller])
		else:
			assert_array(trusted).override_failure_message(path).contains_exactly([booth])


func test_switches_stand_in_the_bay_and_area_switches_hang_on_the_security_switch() -> void:
	# ADR 0130 step 3: every switch, the router and the alarm controller stand in the hall's bay; an
	# area switch serves the devices of its room (those outside the bay stand in that room).
	var bay := _node("Devices/Bay") as LinkingBay
	assert_bool(_inside(bay.global_position, _room.get_node("Shell/Hall") as Room)).is_true()
	for path: String in ["Devices/Bay/Rtr05", "Devices/Bay/Controller"]:
		assert_object(MountChecks.bay_of(_node(path))).override_failure_message(path).is_same(bay)
	var cabled_once: Dictionary[Device, int] = {}
	for path: String in SWITCHES:
		assert_object(MountChecks.bay_of(_node(path))).override_failure_message(path).is_same(bay)
		var room := _room.get_node("Shell/" + String(SWITCHES[path][0])) as Room
		var expected: Array[Device] = []
		for child: String in SWITCHES[path][1]:
			expected.append(_device(child))
			# (The hall switches serve the whole wing; door controllers sit in the walls.)
			if room.name != &"Hall" and MountChecks.bay_of(_node(child)) == null and not child.begins_with("Doors/"):
				(
					assert_bool(_inside(_node(child).global_position, room))
					. override_failure_message("%s outside %s" % [child, room.name])
					. is_true()
				)
		assert_array(_device(path).linked()).override_failure_message(path).contains_exactly_in_any_order(expected)
		for device in expected:
			cabled_once[device] = cabled_once.get(device, 0) + 1
	# A tree: every device but the router and the switches is cabled to exactly one switch, the area
	# switches to SW-SECURITY only; the router joins SW-OPS and SW-SECURITY.
	for path: String in NETWORK:
		var device := _device(path)
		if path == "Devices/Bay/Rtr05" or path in ["Devices/Bay/OpsSwitch", "Devices/Bay/SecuritySwitch"]:
			continue
		assert_int(cabled_once.get(device, 0)).override_failure_message(path).is_equal(1)
		var cables := DeviceNetwork.cabled(device)
		if not SWITCHES.has(path):
			assert_int(cables.size()).override_failure_message(path).is_equal(1)
	assert_array(_device("Devices/Bay/Rtr05").linked()).contains_exactly_in_any_order(
		[_device("Devices/Bay/OpsSwitch"), _device("Devices/Bay/SecuritySwitch")]
	)
	# Breaker B powers the security switch only.
	var circuit := (_node("Devices/BreakerB").get_node("CircuitBreaker") as CircuitBreaker).circuit
	assert_str(String(Powered.of(_node("Devices/Bay/SecuritySwitch")).circuit)).is_equal(String(circuit))
	for path: String in SWITCHES:
		if path != "Devices/Bay/SecuritySwitch":
			assert_str(String(Powered.of(_node(path)).circuit)).override_failure_message(path).is_empty()


func test_the_router_gates_the_security_subnet_until_the_deck_has_an_account() -> void:
	var accounts := DeviceAccounts.of(_node("Devices/Bay/Rtr05"))
	var source := NetworkSource.for_user(_user, _device("Devices/Jack"), NetworkSource.Kind.JACK)
	var reached := source.reached(get_tree())
	for path: String in NETWORK:
		var expected: bool = NETWORK[path][0] == OPS
		(
			assert_bool(reached.has(_device(path)))
			. override_failure_message("%s reached: %s" % [path, reached.has(_device(path))])
			. is_equal(expected)
		)
	# Its login: Weak (the Icebreaker cracks it Untrained) and in the booth computer's mail.
	var account := accounts.accounts[0]
	assert_bool(account.admin).is_true()
	assert_int(account.strength).is_equal(DeviceAccount.Strength.WEAK)
	var mails := Computer.of(_node("Devices/BoothComputer")).data.mail.filter(
		func(mail: ComputerDocument) -> bool: return mail.codes.has(accounts.code_id())
	)
	assert_int(mails.size()).is_equal(1)
	var known := LoginCredentials.parse((mails[0] as ComputerDocument).codes[accounts.code_id()])
	assert_str(known.user).is_equal(account.user)
	assert_str(known.password).is_equal(account.password)

	accounts.grant(_user, account.user)

	reached = source.reached(get_tree())
	for path: String in NETWORK:
		if path != "Devices/Jack":
			assert_bool(reached.has(_device(path))).override_failure_message(path).is_true()


# The deck's Map of the whole wing network (network_map_checks.gd: readable, no cable crossing,
# nothing off the tree), from the jack and from the booth computer: two subnet boxes in their
# colours, RTR-05 between them with both addresses.
func test_the_deck_map_from_the_jack_and_the_booth_computer_reads_well() -> void:
	for start: String in ["Devices/Jack", "Devices/BoothComputer"]:
		var rows := MapChecks.rows_from(_node(start))
		assert_int(rows.size()).override_failure_message(start).is_equal(NETWORK.size())
		var result := MapChecks.check(self, rows, MapChecks.cables(rows))
		assert_int(result["crossings"]).override_failure_message(start).is_equal(0)
		assert_int(result["extra"]).override_failure_message(start).is_equal(0)
		var zoom: float = result["zoom"]
		assert_float(zoom).override_failure_message("%s fitted zoom %.2f" % [start, zoom]).is_greater(0.45)
		var boxes: Dictionary = result["boxes"]
		assert_array(boxes.keys()).override_failure_message(start).contains_exactly_in_any_order([OPS, SECURITY])
		var layout := result["layout"] as NetworkLayout
		var by_name := {}
		for i in rows.size():
			by_name[rows[i].name] = i
		var router := layout.rects[by_name["RTR-05"]]
		var ops: Rect2 = boxes[OPS]["rect"]
		var security: Rect2 = boxes[SECURITY]["rect"]
		var between := (
			(ops.end.x < router.position.x and router.end.x < security.position.x)
			or (security.end.x < router.position.x and router.end.x < ops.position.x)
		)
		assert_bool(between).override_failure_message(start).is_true()
		assert_str(rows[by_name["RTR-05"]].address).is_equal("10.0.15.1 · 10.0.25.254")
