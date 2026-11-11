extends GdUnitTestSuite
## Network lab (gallery room 8) alone: the M12b annex (design/levels/hub-and-gallery.md "8 Network
## lab", "M12b annex"), a 14 x 14 m room behind the hall's far wall through a 2 x 2.6 m doorway, with
## three stations on two networks of their own:
## - Wi-Fi: AP-LAB on the east wall (Wi-Fi subnet, cabled to SW-WIFI, on its own breaker) with a
##   wireless camera and laser; floor marks 6 m (Untrained: in range) and 10 m (Trained only) from
##   it with a clear line of sight, and a pillar that hides it from a spot behind it within the
##   Untrained range;
## - exploits: the CCTV subnet (a jack, three Helix CAM-3 cameras 2.1, 2.0 and 2.4) behind RTR-03
##   (Norsk EdgeGuard 1.8, the Watchdog tracer watching CCTV only), which joins it to the Wi-Fi
##   subnet; a datapad teaches the Helix and EdgeGuard exploits;
## - firewall: RTR-04 between the Alarm subnet (a jack, the alarm controller, a panic button) and
##   the Sirens subnet (two sirens); its Weak admin login on a note at the station; denying the
##   controller to the Sirens subnet silences them.
## Lab-local coordinates; distances to the access point are straight lines from the eye (feet +
## 1.65 m) to its origin (DeckSession.distance()). The room is loaded once; tests that change state
## restore it.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/network_lab/network_lab.tscn")
const ORIGIN := Vector3(-300, 0, -700)
## Annex interior (lab-local): x 7.75..21.75, z -32.5..-18.5, 3.5 m high.
const ANNEX := Rect2(7.75, -32.5, 14, 14)
const ANNEX_HEIGHT := 3.5
const EYE := 1.65
## Floor spots (lab-local feet): the two marks and behind the pillar.
const SPOT_6 := Vector3(15.6, 0, -25.5)
const SPOT_10 := Vector3(11.6, 0, -25.5)
const BEHIND_PILLAR := Vector3(16.0, 0, -27.9)
## The deck's Wi-Fi range, Untrained and Trained (m).
const UNTRAINED := 8.0
const TRAINED := 12.0
## Entity path -> [subnet, address, display name].
const NETWORK: Dictionary[String, Array] = {
	"Devices/WifiSwitch": [&"lab_wifi", "10.0.40.2", "SW-WIFI"],
	"Devices/ApLab": [&"lab_wifi", "10.0.40.5", "AP-LAB"],
	"Devices/WifiCamera": [&"lab_wifi", "10.0.40.21", "CAM-WIFI"],
	"Devices/WifiLaser": [&"lab_wifi", "10.0.40.41", "LASER-WIFI"],
	"Devices/Rtr03": [&"lab_cctv", "10.0.50.1", "RTR-03"],
	"Devices/CctvSwitch": [&"lab_cctv", "10.0.50.2", "SW-CCTV"],
	"Devices/CctvJack": [&"lab_cctv", "10.0.50.40", "CCTV-JACK"],
	"Devices/CamEx1": [&"lab_cctv", "10.0.50.21", "CAM-EX1"],
	"Devices/CamEx2": [&"lab_cctv", "10.0.50.22", "CAM-EX2"],
	"Devices/CamEx3": [&"lab_cctv", "10.0.50.23", "CAM-EX3"],
	"Devices/AlarmJack": [&"lab_alarm", "10.0.60.40", "ALARM-JACK"],
	"Devices/AlarmSwitch": [&"lab_alarm", "10.0.60.2", "SW-ALARM"],
	"Devices/AlarmController": [&"lab_alarm", "10.0.60.10", "ALARM-LAB"],
	"Devices/PanicButton": [&"lab_alarm", "10.0.60.12", "PANIC-LAB"],
	"Devices/Rtr04": [&"lab_alarm", "10.0.60.1", "RTR-04"],
	"Devices/SirenSwitch": [&"lab_sirens", "10.0.70.2", "SW-SIRENS"],
	"Devices/SirenA": [&"lab_sirens", "10.0.70.31", "SIREN-A"],
	"Devices/SirenB": [&"lab_sirens", "10.0.70.32", "SIREN-B"],
}

var _room: Node3D
var _user: Node3D


func before() -> void:
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)
	_user = auto_free(Node3D.new())
	_user.name = "AnnexUser"
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


func _ap() -> Node3D:
	return _node("Devices/ApLab")


# Straight line from the eye at lab-local `feet` to the access point's origin.
func _eye_distance(feet: Vector3) -> float:
	return _room.to_global(feet + Vector3.UP * EYE).distance_to(_ap().global_position)


# What a ray from the eye at `feet` to the access point meets first on the world layer (the access
# point's own body excluded, as WirelessTool.has_sight() does); empty when nothing.
func _sight_ray(feet: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		_room.to_global(feet + Vector3.UP * EYE),
		_ap().global_position,
		PhysicsLayers.WORLD,
		[(_ap() as CollisionObject3D).get_rid()]
	)
	return _room.get_world_3d().direct_space_state.intersect_ray(query)


func _sirens() -> Array[Siren]:
	var found: Array[Siren] = []
	for path: String in ["Devices/SirenA", "Devices/SirenB"]:
		found.append(_node(path).find_children("*", "Siren", false, false)[0] as Siren)
	return found


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func test_the_annex_shares_the_hall_wall_and_its_doorway_is_clear() -> void:
	var annex := _node("Shell/Annex") as Room
	var hall := _node("Shell/Hall") as Room
	assert_float(annex.wall_thickness).is_equal(0.5)
	assert_vector(annex.position).is_equal(Vector3(ANNEX.get_center().x, 0, ANNEX.get_center().y))
	assert_vector(annex.size).is_equal(Vector3(ANNEX.size.x, ANNEX_HEIGHT, ANNEX.size.y))
	# Its near wall is the hall's far wall (z -18 to -18.5); its west wall the closet's east wall.
	assert_float(annex.position.z + annex.size.z * 0.5 + 0.5).is_equal_approx(-18.0, 0.001)
	assert_float(annex.position.x - annex.size.x * 0.5 - 0.5).is_equal_approx(7.25, 0.001)
	# The two openings line up at x 10, 2 x 2.6 m.
	for pair: Array in [[hall, &"ToAnnex"], [annex, &"FromHall"]]:
		var room := pair[0] as Room
		for opening in room.openings:
			if opening.node_name == pair[1]:
				assert_float(room.position.x + opening.offset).is_equal_approx(10.0, 0.001)
				assert_vector(Vector2(opening.width, opening.height)).is_equal(Vector2(2, 2.6))
	var world := _room.get_world_3d()
	# A standing capsule's width and height through the doorway; the wall beside it blocks.
	for x: float in [9.7, 10.0, 10.3]:
		for y: float in [0.3, 1.0, 1.85]:
			var hit := KitGeometry.ray(world, ORIGIN + Vector3(x, y, -16.5), ORIGIN + Vector3(x, y, -20.5))
			assert_dict(hit).override_failure_message("doorway blocked at x %.1f y %.1f" % [x, y]).is_empty()
	assert_dict(KitGeometry.ray(world, ORIGIN + Vector3(13, 1, -17), ORIGIN + Vector3(13, 1, -20))).is_not_empty()


func test_annex_devices_hang_flush_on_its_walls() -> void:
	assert_array(WallDeviceChecks.problems(_room)).is_empty()
	var paths: Array[String] = ["Devices/ApBreaker"]
	paths.append_array(NETWORK.keys())
	for path: String in paths:
		var box := _room.global_transform.affine_inverse() * WallDeviceChecks.visual_box(_node(path))
		var gaps: Array[float] = [
			box.position.x - ANNEX.position.x,
			ANNEX.end.x - box.end.x,
			box.position.z - ANNEX.position.y,
			ANNEX.end.y - box.end.z,
		]
		var nearest := gaps.min() as float
		assert_float(nearest).override_failure_message("%s: %.3f m off its wall" % [path, nearest]).is_between(
			-0.001, 0.02
		)
		assert_float(box.end.y).override_failure_message(path).is_less(ANNEX_HEIGHT - 0.3)


func test_two_networks_of_their_own_with_subnets_routers_tracer_and_logins() -> void:
	for path: String in NETWORK:
		var device := _device(path)
		assert_str(String(DeviceNetwork.subnet_of(device))).override_failure_message(path).is_equal(
			String(NETWORK[path][0])
		)
		assert_str(device.address).override_failure_message(path).is_equal(NETWORK[path][1])
		assert_str(NetworkSource.display_name(device)).override_failure_message(path).is_equal(NETWORK[path][2])
	assert_array(Router.of(_node("Devices/Rtr03")).addresses()).is_equal(["10.0.50.1", "10.0.40.1"])
	assert_array(Router.of(_node("Devices/Rtr04")).addresses()).is_equal(["10.0.60.1", "10.0.70.1"])
	# Not cabled to the M12a network nor to each other.
	var graph := Device.graph(get_tree())
	var wifi_side := graph.component(_device("Devices/CctvJack").get_instance_id())
	var alarm_side := graph.component(_device("Devices/AlarmJack").get_instance_id())
	for path: String in ["Devices/Rtr01", "Devices/Rtr02", "Devices/Jack"]:
		assert_bool(wifi_side.has(_device(path).get_instance_id())).override_failure_message(path).is_false()
		assert_bool(alarm_side.has(_device(path).get_instance_id())).override_failure_message(path).is_false()
	assert_bool(wifi_side.has(_device("Devices/Rtr04").get_instance_id())).is_false()
	assert_bool(wifi_side.has(_device("Devices/ApLab").get_instance_id())).is_true()
	# The Watchdog tracer on RTR-03 watches CCTV only (not the Wi-Fi side, not the firewall station).
	var tracer := _node("Devices/Rtr03").get_node("Tracer") as Tracer
	assert_array(tracer.watched).contains_exactly([&"lab_cctv"])
	for path: String in ["Devices/CamEx1", "Devices/CamEx2", "Devices/CamEx3"]:
		assert_bool(tracer.watches(_device(path))).override_failure_message(path).is_true()
	for path: String in ["Devices/WifiCamera", "Devices/ApLab", "Devices/SirenA"]:
		assert_bool(tracer.watches(_device(path))).override_failure_message(path).is_false()
	# RTR-04's Weak admin login on the note at the station; RTR-03's Medium one written nowhere.
	var rtr04 := DeviceAccounts.of(_node("Devices/Rtr04"))
	var note := _node("Items/Rtr04Note").get_node("Readable") as Readable
	var known := LoginCredentials.parse(note.codes[rtr04.code_id()])
	assert_str(known.password).is_equal(rtr04.accounts[0].password)
	assert_int(rtr04.accounts[0].strength).is_equal(DeviceAccount.Strength.WEAK)
	assert_bool(rtr04.accounts[0].admin).is_true()
	assert_float(_node("Items/Rtr04Note").position.distance_to(_node("Devices/Rtr04").position)).is_less(7.0)
	var rtr03 := DeviceAccounts.of(_node("Devices/Rtr03")).accounts[0]
	assert_int(rtr03.strength).is_equal(DeviceAccount.Strength.MEDIUM)
	for node in _room.find_children("*", "Readable", true, false):
		assert_str((node as Readable).text + str((node as Readable).codes)).not_contains(rtr03.password)


func test_the_access_point_covers_its_wireless_devices_and_its_breaker_cuts_them() -> void:
	var ap := _device("Devices/ApLab")
	var radio := AccessPoint.of(ap)
	assert_object(radio).is_not_null()
	assert_int(radio.key_strength).is_equal(DeviceAccount.Strength.WEAK)
	assert_array(DeviceNetwork.wireless_devices(ap)).contains_exactly_in_any_order(
		[_device("Devices/WifiCamera"), _device("Devices/WifiLaser")]
	)
	# Well inside its range (15 m), centre to centre.
	for path: String in ["Devices/WifiCamera", "Devices/WifiLaser"]:
		var distance := _node(path).global_position.distance_to(_ap().global_position)
		assert_float(distance).override_failure_message(path).is_less(radio.wireless_range - 5.0)
	var switch := _device("Devices/WifiSwitch")
	assert_bool(switch.reaches(_node("Devices/WifiCamera"))).is_true()
	assert_bool(switch.reaches(_node("Devices/WifiLaser"))).is_true()
	# Breakable like any prop, and on its own breaker: off, both wireless devices drop off.
	assert_object(_ap().get_node("Breakable")).is_not_null()
	var breaker := _node("Devices/ApBreaker").get_node("CircuitBreaker") as CircuitBreaker
	assert_str(String(Powered.of(_ap()).circuit)).is_equal(String(breaker.circuit))
	breaker.set_closed(false)
	assert_bool(ap.is_up()).is_false()
	assert_bool(switch.reaches(_node("Devices/WifiCamera"))).is_false()
	assert_bool(switch.reaches(_node("Devices/WifiLaser"))).is_false()
	breaker.set_closed(true)
	assert_bool(switch.reaches(_node("Devices/WifiCamera"))).is_true()


func test_the_floor_marks_sit_at_6_and_10_m_and_the_pillar_hides_the_access_point() -> void:
	# The marks: on the floor at the spots.
	for pair: Array in [["FloorMarks/Spot6", SPOT_6], ["FloorMarks/Spot10", SPOT_10]]:
		var mark := _node(String(pair[0]))
		var spot: Vector3 = pair[1]
		assert_float(Vector2(mark.position.x, mark.position.z).distance_to(Vector2(spot.x, spot.z))).is_less(0.05)
		assert_float(mark.position.y).is_less(0.05)
	# 6 m: inside the Untrained range with 1.5 m or more to spare, in sight.
	var six := _eye_distance(SPOT_6)
	assert_float(six).override_failure_message("6 m mark: %.2f" % six).is_between(5.5, UNTRAINED - 1.5)
	assert_dict(_sight_ray(SPOT_6)).is_empty()
	# 10 m: out of the Untrained range and inside the Trained one, 1.5 m or more from both, in sight.
	var ten := _eye_distance(SPOT_10)
	assert_float(ten).override_failure_message("10 m mark: %.2f" % ten).is_between(UNTRAINED + 1.5, TRAINED - 1.5)
	assert_dict(_sight_ray(SPOT_10)).is_empty()
	# Behind the pillar: within the Untrained range (so the pause is the sight, not the range), and
	# the pillar is what the ray meets.
	var behind := _eye_distance(BEHIND_PILLAR)
	assert_float(behind).override_failure_message("behind: %.2f" % behind).is_less(UNTRAINED - 1.0)
	var hit := _sight_ray(BEHIND_PILLAR)
	assert_object(hit.get("collider")).is_same(_node("Furniture/Pillar"))
	# The player fits there: 0.35 m capsule clear of the pillar's footprint (x 16.6..17.4, z -27.9..-27.1).
	var pillar := Rect2(16.6, -27.9, 0.8, 0.8)
	var nearest := Vector2(
		clampf(BEHIND_PILLAR.x, pillar.position.x, pillar.end.x),
		clampf(BEHIND_PILLAR.z, pillar.position.y, pillar.end.y)
	)
	assert_float(nearest.distance_to(Vector2(BEHIND_PILLAR.x, BEHIND_PILLAR.z))).is_greater(0.45)


func test_exploits_match_as_designed() -> void:
	var notes := _node("Items/ExploitNotes").get_node("Readable") as Readable
	assert_int(notes.exploits.size()).is_equal(2)
	var helix: Exploit = notes.exploits.filter(func(x: Exploit) -> bool: return x.product == "CAM-3")[0]
	var norsk: Exploit = notes.exploits.filter(func(x: Exploit) -> bool: return x.product == "EdgeGuard")[0]
	# Helix 2.0-2.1: CAM-EX1 (2.1) and CAM-EX2 (2.0, the same product on the watched subnet) and the
	# Wi-Fi camera (2.1, unwatched); CAM-EX3 (2.4) is out of range.
	for path: String in ["Devices/CamEx1", "Devices/CamEx2", "Devices/WifiCamera"]:
		assert_bool(helix.matches(_device(path).software)).override_failure_message(path).is_true()
	assert_bool(helix.matches(_device("Devices/CamEx3").software)).is_false()
	assert_bool(_device("Devices/CamEx3").software.same_product(_device("Devices/CamEx1").software)).is_true()
	# EdgeGuard 1.0-1.9: RTR-03 (1.8), not RTR-04 (2.2).
	assert_bool(norsk.matches(_device("Devices/Rtr03").software)).is_true()
	assert_bool(norsk.matches(_device("Devices/Rtr04").software)).is_false()
	assert_bool(helix.is_admin() and norsk.is_admin()).is_true()


func test_denying_the_controller_to_the_sirens_silences_them() -> void:
	var panic := _node("Devices/PanicButton").find_children("*", "PanicButton", false, false)[0] as PanicButton
	var controller := (
		_node("Devices/AlarmController").find_children("*", "AlarmController", false, false)[0] as AlarmController
	)
	var router := Router.of(_node("Devices/Rtr04"))
	# Without a rule the panic button rings both sirens through RTR-04.
	panic.use(_user)
	await _seconds(0.5)
	for siren in _sirens():
		assert_bool(siren.is_sounding()).override_failure_message(siren.get_parent().name).is_true()
	controller.stop("reset")
	await _seconds(0.5)
	for siren in _sirens():
		assert_bool(siren.is_sounding()).is_false()
	# ALARM-LAB -> the Sirens subnet: DENY. The alarm still rings, the sirens stay silent.
	router.add_rule(
		RouterRule.make(RouterRule.Match.DEVICE, "AlarmController", RouterRule.Match.SUBNET, "lab_sirens", false)
	)
	panic.use(_user)
	await _seconds(1.0)
	assert_bool(controller.is_ringing()).is_true()
	for siren in _sirens():
		assert_bool(siren.is_sounding()).override_failure_message(siren.get_parent().name).is_false()
	controller.stop("reset")
	router.remove_rule(0)


# The deck's Map of each annex network from its jack (network_map_checks.gd): two subnet boxes,
# their router between them, no crossing; the Wi-Fi devices hang on the access point.
func test_the_deck_maps_of_the_annex_networks_read_well() -> void:
	var expected: Dictionary[String, Array] = {
		"Devices/CctvJack": [&"lab_cctv", &"lab_wifi"], "Devices/AlarmJack": [&"lab_alarm", &"lab_sirens"]
	}
	for start: String in expected:
		var rows := MapChecks.rows_from(_node(start))
		var result := MapChecks.check(self, rows, MapChecks.cables(rows))
		assert_int(result["crossings"]).override_failure_message(start).is_equal(0)
		assert_int(result["extra"]).override_failure_message(start).is_equal(0)
		var zoom: float = result["zoom"]
		assert_float(zoom).override_failure_message("%s fitted zoom %.2f" % [start, zoom]).is_greater(0.6)
		var boxes: Dictionary = result["boxes"]
		assert_array(boxes.keys()).override_failure_message(start).contains_exactly_in_any_order(expected[start])
