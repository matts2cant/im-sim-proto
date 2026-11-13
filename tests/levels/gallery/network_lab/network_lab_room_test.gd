extends GdUnitTestSuite
## Network lab (gallery room 8) alone, design/levels/hub-and-gallery.md "8 Network lab": the shell
## (a 3.5 m corridor from the hub wall, a 14 x 14 m hall, a closet behind the far wall, walls shared
## as in ADR 0043; the M12b annex: network_lab_annex_test.gd), clear doorways, no coplanar faces,
## wall devices clear of doorways, door sweeps and signs and flush on their walls, signs inside their
## walls; the M12a network data (three subnets, RTR-01 with the Sentry tracer between Office and
## Security, RTR-02 between Security and Servers, the closet's room switch on the Security subnet,
## trust, accounts) and fair clues. The room is loaded once (its tests only query it).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
const MountChecks := preload("res://tests/levels/device_mount_checks.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/network_lab/network_lab.tscn")
const ORIGIN := Vector3(-300, 0, -500)
## Hall interior (lab-local): x -2..12, z -18..-4, 4 m high.
const HALL := Rect2(-2, -18, 14, 14)
const HALL_HEIGHT := 4.0
## The M12b annex's interior (lab-local): x 7.75..21.75, z -32.5..-18.5, 3.5 m high.
const ANNEX := Rect2(7.75, -32.5, 14, 14)
const ANNEX_HEIGHT := 3.5
const WEAK := DeviceAccount.Strength.WEAK
const MEDIUM := DeviceAccount.Strength.MEDIUM
## Entity path -> [subnet, address].
const NETWORK: Dictionary[String, Array] = {
	"Devices/Jack": [&"office", "10.0.10.40"],
	"Devices/OfficeSwitch": [&"office", "10.0.10.2"],
	"Devices/OfficePc1": [&"office", "10.0.10.11"],
	"Devices/OfficePc2": [&"office", "10.0.10.12"],
	"Devices/BayA/Rtr01": [&"office", "10.0.10.1"],
	"Devices/BayA/SecuritySwitch": [&"security", "10.0.20.2"],
	"Devices/BayA/ClosetSwitch": [&"security", "10.0.20.3"],
	"Devices/Console": [&"security", "10.0.20.5"],
	"Devices/ClosetCamera": [&"security", "10.0.20.21"],
	"Doors/ClosetDoor/Hardware/Controller": [&"security", "10.0.20.51"],
	"Devices/BayB/Rtr02": [&"security", "10.0.20.1"],
	"Devices/BayB/ServerSwitch": [&"servers", "10.0.30.2"],
	"Devices/BayB/FileServer": [&"servers", "10.0.30.8"],
}
## Entity path -> [user, strength, admin].
const ACCOUNTS: Dictionary[String, Array] = {
	"Devices/OfficePc1": ["achen", WEAK, false],
	"Devices/OfficePc2": ["jnovak", WEAK, false],
	"Devices/Console": ["ops", MEDIUM, false],
	"Devices/BayA/Rtr01": ["admin", WEAK, true],
	"Devices/BayB/Rtr02": ["admin", MEDIUM, true],
	"Devices/BayB/FileServer": ["archive", WEAK, false],
}

var _room: Node3D


func before() -> void:
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)
	await KitGeometry.settle(get_tree(), 5)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func _node(path: String) -> Node3D:
	return _room.get_node(path) as Node3D


func test_corridor_hall_and_closet_share_walls_and_their_doorways_line_up() -> void:
	var corridor := _node("Shell/Corridor") as Room
	var hall := _node("Shell/Hall") as Room
	var closet := _node("Shell/Closet") as Room
	for room: Room in [corridor, hall, closet]:
		assert_float(room.wall_thickness).is_equal(0.5)
	# The corridor runs from the hub wall's outer face (z 0) to the hall's near wall (z -3.5).
	assert_vector(corridor.position).is_equal(Vector3(0, 0, -1.75))
	assert_vector(corridor.size).is_equal(Vector3(2, 3, 3.5))
	assert_vector(hall.position).is_equal(Vector3(HALL.get_center().x, 0, HALL.get_center().y))
	assert_vector(hall.size).is_equal(Vector3(HALL.size.x, HALL_HEIGHT, HALL.size.y))
	# Hall near wall z -3.5..-4 is the corridor's far wall; the closet's near wall is the hall's far wall.
	assert_float(hall.position.z + hall.size.z * 0.5 + 0.5).is_equal_approx(
		corridor.position.z - corridor.size.z * 0.5, 0.001
	)
	assert_float(closet.position.z + closet.size.z * 0.5).is_equal_approx(HALL.position.y - 0.5, 0.001)
	# Openings: 2 x 3 m from the hub and into the hall at x 0; the closet's 1.2 x 2.2 m doorway at the door.
	var hall_door := _opening(hall, &"FromCorridor")
	assert_float(hall.position.x + hall_door.offset).is_equal_approx(0.0, 0.001)
	assert_vector(Vector2(hall_door.width, hall_door.height)).is_equal(Vector2(2, 3))
	var to_closet := _opening(hall, &"ToCloset")
	var from_hall := _opening(closet, &"Doorway")
	var door := _node("Doors/ClosetDoor")
	assert_float(hall.position.x + to_closet.offset).is_equal_approx(door.position.x, 0.001)
	assert_float(closet.position.x + from_hall.offset).is_equal_approx(door.position.x, 0.001)
	assert_float(door.position.z).is_equal_approx(HALL.position.y - 0.25, 0.001)
	assert_float(Door.of(door).wall_thickness).is_equal(0.5)


func test_doorways_are_clear_and_walls_block() -> void:
	var world := _room.get_world_3d()
	# A standing capsule's width and height through the hub doorway and the corridor into the hall.
	for x: float in [-0.3, 0.0, 0.3]:
		for y: float in [0.3, 1.0, 1.75]:
			var hit := KitGeometry.ray(world, ORIGIN + Vector3(x, y, 1.0), ORIGIN + Vector3(x, y, -6.0))
			assert_dict(hit).override_failure_message("corridor blocked at x %.1f y %.1f" % [x, y]).is_empty()
	# Plain walls block: the hall's near wall beside the corridor, the far wall beside the closet door.
	assert_dict(KitGeometry.ray(world, ORIGIN + Vector3(5, 1, -3), ORIGIN + Vector3(5, 1, -5))).is_not_empty()
	assert_dict(KitGeometry.ray(world, ORIGIN + Vector3(9, 1, -17), ORIGIN + Vector3(9, 1, -20))).is_not_empty()
	# The closed closet door blocks its doorway.
	assert_dict(KitGeometry.ray(world, ORIGIN + Vector3(5.85, 1, -17), ORIGIN + Vector3(5.85, 1, -20))).is_not_empty()


func test_no_coplanar_faces_with_different_materials() -> void:
	assert_array(KitGeometry.coplanar_material_overlaps(_room)).is_empty()


func test_wall_devices_sit_on_the_walls_clear_of_doorways_and_signs() -> void:
	assert_array(WallDeviceChecks.problems(_room)).is_empty()
	# ADR 0130 step 3: the routers and switches stand in bays A and B, the office switch and the
	# computers on desks; every other network device but the door hangs on a hall wall, its back
	# within 2 cm of a wall face.
	var mounts: Dictionary[String, int] = {}
	for path: String in NETWORK:
		if path.begins_with("Doors/"):
			continue
		mounts[path] = MountChecks.mount(_node(path))
		if mounts[path] != MountChecks.Mount.WALL:
			continue
		var box := _room.global_transform.affine_inverse() * WallDeviceChecks.visual_box(_node(path))
		var gaps: Array[float] = [
			box.position.x - HALL.position.x,
			HALL.end.x - box.end.x,
			box.position.z - HALL.position.y,
			HALL.end.y - box.end.z,
		]
		var nearest := gaps.min() as float
		assert_float(nearest).override_failure_message("%s: %.3f m off its wall" % [path, nearest]).is_between(
			-0.001, 0.02
		)
		assert_float(box.position.y).override_failure_message(path).is_greater(0.2)
		assert_float(box.end.y).override_failure_message(path).is_less(HALL_HEIGHT - 0.5)
	var bay := MountChecks.Mount.BAY
	var desk := MountChecks.Mount.DESK
	var expected: Dictionary[String, int] = {
		"Devices/Jack": MountChecks.Mount.WALL,
		"Devices/OfficeSwitch": desk,
		"Devices/OfficePc1": desk,
		"Devices/OfficePc2": desk,
		"Devices/Console": desk,
		"Devices/ClosetCamera": MountChecks.Mount.WALL,
		"Devices/BayA/Rtr01": bay,
		"Devices/BayA/SecuritySwitch": bay,
		"Devices/BayA/ClosetSwitch": bay,
		"Devices/BayB/Rtr02": bay,
		"Devices/BayB/ServerSwitch": bay,
		"Devices/BayB/FileServer": bay,
	}
	assert_dict(mounts).is_equal(expected)
	for path: String in ["Devices/MailPc", "Devices/EdgeRouter"]:
		assert_int(MountChecks.mount(_node(path))).override_failure_message(path).is_equal(desk)


func test_signs_fit_their_walls_and_do_not_overlap() -> void:
	var signs: Array[Sign] = []
	for node in _node("Labels").get_children():
		signs.append(node as Sign)
	# 22 until M12c added the mail route station's sign.
	assert_int(signs.size()).is_equal(23)
	for sign in signs:
		var box := _room.global_transform.affine_inverse() * WallDeviceChecks.sign_box(sign)
		var where := String(sign.name)
		# Inside the hall's or the annex's walls (5 cm margin), under the ceiling, above the floor.
		var in_annex := ANNEX.has_point(Vector2(sign.position.x, sign.position.z))
		var room := ANNEX if in_annex else HALL
		var height := ANNEX_HEIGHT if in_annex else HALL_HEIGHT
		assert_float(box.position.x).override_failure_message(where).is_greater(room.position.x - 0.1)
		assert_float(box.end.x).override_failure_message(where).is_less(room.end.x + 0.1)
		assert_float(box.position.z).override_failure_message(where).is_greater(room.position.y - 0.1)
		assert_float(box.end.z).override_failure_message(where).is_less(room.end.y + 0.1)
		var along := sign.basis.x
		var start := box.position.x if absf(along.x) > 0.5 else box.position.z
		var end := box.end.x if absf(along.x) > 0.5 else box.end.z
		var span := (
			Vector2(room.position.x, room.end.x) if absf(along.x) > 0.5 else Vector2(room.position.y, room.end.y)
		)
		assert_float(start).override_failure_message(where).is_greater(span.x + 0.05)
		assert_float(end).override_failure_message(where).is_less(span.y - 0.05)
		assert_float(box.end.y).override_failure_message(where).is_less(height - 0.1)
		assert_float(box.position.y).override_failure_message(where).is_greater(1.0)
		for other in signs:
			if other != sign:
				var other_box := WallDeviceChecks.sign_box(other)
				(
					assert_bool(WallDeviceChecks.sign_box(sign).intersects(other_box))
					. override_failure_message("%s overlaps %s" % [where, other.name])
					. is_false()
				)


func test_three_subnets_behind_two_routers_with_trust_and_accounts() -> void:
	for path: String in NETWORK:
		var device := Device.of(_node(path))
		assert_str(String(DeviceNetwork.subnet_of(device))).override_failure_message(path).is_equal(
			String(NETWORK[path][0])
		)
		assert_str(device.address).override_failure_message(path).is_equal(NETWORK[path][1])
		assert_bool(_node(path).has_meta(&"display_name")).override_failure_message(path).is_true()
	assert_array(Router.of(_node("Devices/BayA/Rtr01")).subnets()).contains_exactly_in_any_order(
		[&"office", &"security"]
	)
	assert_array(Router.of(_node("Devices/BayB/Rtr02")).subnets()).contains_exactly_in_any_order(
		[&"security", &"servers"]
	)
	assert_int(DeviceNetwork.port_kind(Device.of(_node("Devices/Jack")))).is_equal(Device.DeckPort.JACK)
	# One tracer on the M12a network, default tuning, on RTR-01, watching Office and Security (not
	# Servers); the annex's RTR-03 runs the other (network_lab_annex_test.gd).
	var tracers := Tracer.all(get_tree()).filter(
		func(t: Tracer) -> bool: return _room.is_ancestor_of(t) and t.entity != _node("Devices/BayC/Rtr03")
	)
	assert_int(tracers.size()).is_equal(1)
	var tracer := tracers[0] as Tracer
	assert_object(tracer.entity).is_same(_node("Devices/BayA/Rtr01"))
	assert_array(tracer.watched).contains_exactly_in_any_order([&"office", &"security"])
	assert_object(tracer.config).is_same(Tracer.DEFAULT_CONFIG)
	# The camera and the door trust the console only.
	var console := Device.of(_node("Devices/Console"))
	for path: String in ["Devices/ClosetCamera", "Doors/ClosetDoor/Hardware/Controller"]:
		assert_array(DeviceNetwork.trusted(Device.of(_node(path)))).contains_exactly([console])
	for path: String in ACCOUNTS:
		var accounts := DeviceAccounts.of(_node(path)).accounts
		assert_int(accounts.size()).override_failure_message(path).is_equal(1)
		assert_str(accounts[0].user).override_failure_message(path).is_equal(ACCOUNTS[path][0])
		assert_int(accounts[0].strength).override_failure_message(path).is_equal(ACCOUNTS[path][1])
		assert_bool(accounts[0].admin).override_failure_message(path).is_equal(ACCOUNTS[path][2])
	# A subnet can span several switches: the closet's room switch carries the camera and the door and
	# hangs on the main security switch (on no circuit); the breaker beside it cuts its circuit and
	# the closet door is fail-secure on it.
	assert_array(Device.of(_node("Devices/BayA/ClosetSwitch")).linked()).contains_exactly_in_any_order(
		[Device.of(_node("Devices/ClosetCamera")), Device.of(_node("Doors/ClosetDoor/Hardware/Controller"))]
	)
	assert_array(Device.of(_node("Devices/BayA/SecuritySwitch")).linked()).contains(
		[Device.of(_node("Devices/BayA/ClosetSwitch"))]
	)
	assert_str(String(Powered.of(_node("Devices/BayA/SecuritySwitch")).circuit)).is_empty()
	var circuit := (_node("Devices/Breaker").get_node("CircuitBreaker") as CircuitBreaker).circuit
	assert_str(String(Powered.of(_node("Devices/BayA/ClosetSwitch")).circuit)).is_equal(String(circuit))
	assert_str(String(Powered.of(_node("Doors/ClosetDoor/Hardware/Controller")).circuit)).is_equal(String(circuit))
	assert_bool(ActorState.has(_node("Doors/ClosetDoor"), ElectronicLock.FAIL_SECURE)).is_true()


# The deck's Map of the whole lab network from the jack (network_map_checks.gd: readable, no cable
# crossing, nothing off the tree): three subnet boxes left to right (Office, Security, Servers) in
# their data's colours with their names and ranges, RTR-01 and RTR-02 between them with both
# addresses. Fitted in the deck's 1152 x 648 Map panel at about 0.51.
func test_the_deck_map_shows_three_subnet_boxes_with_the_routers_between() -> void:
	assert_array(Router.of(_node("Devices/BayA/Rtr01")).addresses()).is_equal(["10.0.10.1", "10.0.20.254"])
	assert_array(Router.of(_node("Devices/BayB/Rtr02")).addresses()).is_equal(["10.0.20.1", "10.0.30.1"])
	var rows := MapChecks.rows_from(_node("Devices/Jack"))
	var result := MapChecks.check(self, rows, MapChecks.cables(rows))
	var layout := result["layout"] as NetworkLayout
	assert_int(result["crossings"]).is_equal(0)
	assert_int(result["extra"]).is_equal(0)
	var zoom: float = result["zoom"]
	assert_float(zoom).override_failure_message("fitted zoom %.2f" % zoom).is_greater(0.45)
	var boxes: Dictionary = result["boxes"]
	assert_array(boxes.keys()).contains_exactly([&"office", &"security", &"servers"])
	var titles := {
		&"office": "OFFICE 10.0.10.0/24", &"security": "SECURITY 10.0.20.0/24", &"servers": "SERVERS 10.0.30.0/24"
	}
	var colours: Array[Color] = []
	for id: StringName in titles:
		assert_str(boxes[id]["title"]).is_equal(titles[id])
		colours.append(boxes[id]["color"])
	# Office blue, Security orange, Servers purple: distinct hues.
	assert_float(colours[0].h).is_between(0.55, 0.7)
	assert_float(colours[1].h).is_between(0.0, 0.1)
	assert_float(colours[2].h).is_between(0.72, 0.85)
	var office: Rect2 = boxes[&"office"]["rect"]
	var security: Rect2 = boxes[&"security"]["rect"]
	var servers: Rect2 = boxes[&"servers"]["rect"]
	var by_name := {}
	for i in rows.size():
		by_name[rows[i].name] = i
	var rtr01 := layout.rects[by_name["RTR-01"]]
	var rtr02 := layout.rects[by_name["RTR-02"]]
	assert_bool(office.end.x < rtr01.position.x and rtr01.end.x < security.position.x).is_true()
	assert_bool(security.end.x < rtr02.position.x and rtr02.end.x < servers.position.x).is_true()
	assert_str(rows[by_name["RTR-01"]].address).is_equal("10.0.10.1 · 10.0.20.254")
	assert_str(rows[by_name["RTR-01"]].role).is_equal("router")


func test_every_clue_is_fair() -> void:
	var note := _node("Items/StickyNote").get_node("Readable") as Readable
	assert_str(note.codes[&"network_lab_office_pc1"]).is_equal("achen:otter61")
	assert_str(_password("Devices/OfficePc1")).is_equal("otter61")
	# PC 1's mail: an implicit clue naming PC 2's user and the rule; the photo gives the name and year.
	var mail := Computer.of(_node("Devices/OfficePc1")).data.mail[0]
	assert_bool(mail.implicit_clue).is_true()
	assert_bool(mail.codes.is_empty()).is_true()
	for words: String in ["jnovak", "cat's name", "year we moved in", "lower case"]:
		assert_str(mail.text).contains(words)
	var photo := (_node("Items/Photo").get_node("Readable") as Readable).text
	assert_str(photo).contains("Mishka").contains("2029").contains("new flat")
	assert_str(_password("Devices/OfficePc2")).is_equal("mishka" + "2029")
	# PC 2's mail teaches the console's login; the console's file RTR-02's.
	var pc2_mail := Computer.of(_node("Devices/OfficePc2")).data.mail[0]
	assert_str(pc2_mail.codes[&"network_lab_console"]).is_equal("ops:" + _password("Devices/Console"))
	var rtr02_file := Computer.of(_node("Devices/Console")).data.files[0]
	assert_str(rtr02_file.codes[&"network_lab_rtr02"]).is_equal("admin:" + _password("Devices/BayB/Rtr02"))
	assert_str(String(DeviceAccounts.of(_node("Devices/BayB/Rtr02")).credentials_id)).is_equal("network_lab_rtr02")
	# RTR-01 and the file server are cracked: their passwords are written nowhere.
	var texts: Array[String] = []
	for node in _room.find_children("*", "Readable", true, false):
		texts.append((node as Readable).text + str((node as Readable).codes))
	for node in _room.find_children("*", "Computer", true, false):
		var data := (node as Computer).data
		for document in data.mail + data.files:
			texts.append(document.text + str(document.codes))
	for path: String in ["Devices/BayA/Rtr01", "Devices/BayB/FileServer"]:
		for text in texts:
			assert_str(text).override_failure_message(path + "'s password is written").not_contains(_password(path))


func test_the_deck_waits_on_the_entrance_table_clear_of_the_doorway() -> void:
	var deck := _node("Items/Deck")
	assert_str(String(ItemPickup.of(deck).item.id)).is_equal("deck")
	var table := _node("Furniture/DeckTable")
	assert_float(deck.position.y).is_equal_approx(1.02, 0.01)
	assert_float(absf(deck.position.x - table.position.x)).is_less(0.8)
	assert_float(absf(deck.position.z - (table.position.z + 0.35))).is_less(0.35)
	# The table's near end is more than 0.75 m from the doorway's jamb (x 1), surface to surface.
	assert_float(table.position.x - 0.8 - 1.0).is_greater(0.75)
	# Within pick-up reach (2 m) from a stand spot in front of it, at eye height.
	var eye := Vector3(2.6, 1.65, -5.6)
	assert_float(eye.distance_to(deck.position)).is_less(2.0)


func _opening(room: Room, node_name: StringName) -> RoomOpening:
	for opening in room.openings:
		if opening.node_name == node_name:
			return opening
	return null


func _password(path: String) -> String:
	return DeviceAccounts.of(_node(path)).accounts[0].password
