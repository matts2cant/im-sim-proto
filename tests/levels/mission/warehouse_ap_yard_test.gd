extends GdUnitTestSuite
## Warehouse wireless (M12b, design/levels/mission-warehouse.md "Wireless and intrusion (M12b)",
## ADR 0117): the access point AP-YARD, on a bracket over the north parapet above the dock (between
## the roller doors), cabled to the yard's switch on the Security subnet. The yard camera and both
## roof lasers link to it by radio (27 m range); breaking or unpowering it takes only them offline.
## Two cracking spots outside the Security area, measured from the eye (1.65 m over the feet) to
## the access point: on the roof north of the dock skylights, about 6.4 m (Untrained, 8 m), and in
## the yard in the gap between the truck's trailer and the hall wall, about 10.5 m (Trained, 12 m);
## both in sight, dark, and quiet (a crouch-walk there reaches no guard). A deck joined over AP-YARD
## is on the Security subnet: it reaches the cameras, the lasers and both alarm controllers without
## passing RTR-01 (the office stays hidden); the Sentry tracer on RTR-01 still watches the subnet.
## The level is loaded once (design/tech/testing.md "Writing fast tests").

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const MapChecks := preload("res://tests/ui/deck/network_map_checks.gd")
const NOISE: MovementNoiseConfig = preload("res://actors/player/player_movement_noise.tres")
const SECURITY := "Population/Security/"
const AP := "Devices/ApYard"
const RADIO: Array[String] = ["Devices/CameraYard", "Devices/LaserRoofWest", "Devices/LaserRoofEast"]
## Cabled security devices in the same parts of the compound (the yard's and the roof's switches).
const CABLED: Array[String] = [
	"Devices/CameraGate", "Devices/CameraRoof", "Devices/AlarmControllerYard", "Doors/FrontGate/Hardware/Controller"
]
## The cracking spots (feet). Roof: 4.2 m south of the north parapet's inner face, west of the dock
## skylights. Gap: between the trailer's north end (z -12.5) and the hall wall (z -10.5).
const ROOF_SPOT := Vector3(0, 9.5, -4.2)
const GAP_SPOT := Vector3(4, 0, -11.6)
const EYE := Vector3(0, 1.65, 0)
const DARK := 0.1
const UNTRAINED := 0
const TRAINED := 1

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
	StimulusSystem.clear()


func _entity(path: String) -> Node3D:
	return _level.get_node(SECURITY + path) as Node3D


func _device(path: String) -> Device:
	return Device.of(_entity(path))


func _tracer() -> Tracer:
	return _entity("Network/OfficeBay/Rtr01").get_node("Tracer") as Tracer


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_ap_yard_links_the_yard_camera_and_roof_lasers_by_radio() -> void:
	var ap := _device(AP)
	var radio := AccessPoint.of(_entity(AP))
	assert_object(radio).is_not_null()
	assert_str(String(DeviceNetwork.subnet_of(ap))).is_equal("security")
	assert_str(NetworkSource.display_name(ap)).is_equal("AP-YARD")
	assert_int(radio.key_strength).is_equal(DeviceAccount.Strength.WEAK)
	assert_str(String(Powered.of(_entity(AP)).circuit)).is_equal("warehouse_yard")
	# Cabled to the yard's switch, which no longer cables the yard camera; the roof's switch feeds only
	# the roof camera now.
	var yard_links := _linked(_device("Network/OfficeBay/YardSwitch"))
	assert_array(yard_links).contains([AP])
	assert_array(yard_links).not_contains(["Devices/CameraYard"])
	assert_array(_linked(_device("Network/OfficeBay/RoofSwitch"))).contains_exactly(["Devices/CameraRoof"])
	for path: String in RADIO:
		var device := _device(path)
		assert_object(device.wireless_link()).override_failure_message(path).is_same(ap)
		assert_array(device.links).override_failure_message(path).is_empty()
		# Within range with at least 2 m to spare (centre to centre).
		var distance := _entity(path).global_position.distance_to(_entity(AP).global_position)
		assert_float(distance).override_failure_message("%s %.2f m" % [path, distance]).is_less(
			radio.wireless_range - 2.0
		)
		assert_bool(Tracer.watching(device).has(_tracer())).override_failure_message(path).is_true()
	# Its bracket (a mesh: KitGeometry's CSG check does not see it) reaches from the box down into the
	# hall wall (outer face z -10.5) and below the parapet's top (10.5), with no face on the wall's.
	var bracket := _entity(AP).get_node("Bracket") as MeshInstance3D
	var box := bracket.global_transform * bracket.get_aabb()
	var ap_bottom := _entity(AP).global_position.y - 0.025
	assert_float(box.end.y).is_equal_approx(ap_bottom, 0.002)
	assert_float(box.position.y).is_less(10.5)
	assert_float(box.position.z).is_less(-10.5 - 0.02)
	assert_float(box.end.z).is_greater(-10.5 + 0.005)


func test_both_cracking_spots_are_in_range_in_sight_dark_and_quiet() -> void:
	var ap := _device(AP)
	# The roof: in the Untrained range.
	var user := Net.user(_level, ROOF_SPOT + EYE, UNTRAINED)
	var wireless := WirelessTool.of(user)
	assert_float(wireless.distance_to(ap)).is_between(6.0, 7.0)
	assert_bool(wireless.in_range(ap)).is_true()
	assert_bool(wireless.has_sight(ap)).is_true()
	# The gap behind the truck: out of the Untrained range, in the Trained one.
	user.global_position = GAP_SPOT + EYE
	assert_float(wireless.distance_to(ap)).is_between(10.0, 11.0)
	assert_bool(wireless.in_range(ap)).is_false()
	Net.set_tier(user, TRAINED)
	assert_bool(wireless.in_range(ap)).is_true()
	assert_bool(wireless.has_sight(ap)).is_true()
	user.free()
	for spot: Vector3 in [ROOF_SPOT, GAP_SPOT]:
		# The feet stand on a floor there.
		var hit := _ray(spot + Vector3.UP * 0.5, spot + Vector3.DOWN * 0.5)
		assert_bool(hit.is_empty()).override_failure_message("no floor at %s" % spot).is_false()
		assert_float(absf((hit["position"] as Vector3).y - spot.y)).is_less(0.05)
		# Dark, standing and crouched.
		for crouched: bool in [false, true]:
			var level := _measure(spot, crouched)
			assert_float(level).override_failure_message("%s crouched %s: %.2f" % [spot, crouched, level]).is_less(DARK)
		# A crouch-walk there (its floor's surface) reaches no guard post or patrol point: the noise
		# carries `loudness` m of path, and a path is at least the straight line.
		var surface := NOISE.surfaces.surface_of(hit["collider"])
		var loudness := MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.CROUCH, surface, NOISE)
		for post: Vector3 in _guard_spots():
			(
				assert_float(post.distance_to(spot))
				. override_failure_message("%s: guard spot %s within %.1f m" % [spot, post, loudness])
				. is_greater(loudness + 2.0)
			)


func test_breaking_or_unpowering_ap_yard_cuts_only_its_radio_devices() -> void:
	var console := _device("Devices/SecurityConsole")
	_assert_reached(console, RADIO + CABLED, true)
	var ap := _device(AP)
	ap.load_state({"broken": true})
	await _frames(2)
	_assert_reached(console, RADIO, false)
	_assert_reached(console, CABLED, true)
	ap.load_state({"broken": false})
	await _frames(2)
	_assert_reached(console, RADIO, true)
	var powered := Powered.of(_entity(AP))
	powered.on = false
	await _frames(2)
	_assert_reached(console, RADIO, false)
	_assert_reached(console, CABLED, true)
	powered.on = true
	await _frames(2)
	_assert_reached(console, RADIO + CABLED, true)


func test_a_deck_joined_over_ap_yard_reaches_security_without_passing_rtr01() -> void:
	var user := Net.user(_level, ROOF_SPOT + EYE, UNTRAINED)
	var session := DeckSession.of(user)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	var ap := _device(AP)
	AccessPoint.of(_entity(AP)).grant_key(user)
	assert_bool(session.plug(ap, Net.deck_stack())).is_true()
	assert_bool(session.is_wireless()).is_true()
	assert_str(session.source.address).is_equal("10.0.20.90")
	await _frames(15)
	var seen := _map(session)
	for path: String in [
		"Devices/AlarmController",
		"Devices/AlarmControllerYard",
		"Devices/CameraHall",
		"Devices/CameraYard",
		"Devices/LaserRoofWest",
		"Devices/SecurityConsole",
		"Network/OfficeBay/Rtr01",
	]:
		assert_array(seen).override_failure_message(path + " not on the map").contains([path])
		if path != "Network/OfficeBay/Rtr01":
			assert_bool(session.source.reaches(get_tree(), _device(path))).override_failure_message(path).is_true()
	# RTR-01 is not passed: the office stays hidden and out of reach.
	for path: String in ["Network/OfficeSwitch", "Network/OfficePc1", "Network/OfficePc2", "Network/OfficeWallJack"]:
		assert_array(seen).override_failure_message(path + " on the map").not_contains([path])
		assert_bool(session.source.reaches(get_tree(), _device(path))).override_failure_message(path).is_false()
	# The Security subnet is the one joined: shown at once without a scan, so no trace (ADR 0121).
	assert_bool(session.scans.is_empty()).is_true()
	assert_float(_tracer().trace_of(user)).is_equal(0.0)
	session.unplug()
	user.free()


func test_the_map_from_the_office_jack_and_from_ap_yard_is_readable() -> void:
	for path: String in ["Network/OfficeWallJack", AP]:
		var rows := MapChecks.rows_from(_entity(path))
		var result := MapChecks.check(self, rows, MapChecks.cables(rows))
		assert_int(result["crossings"]).override_failure_message(path).is_equal(0)
		assert_int(result["extra"]).override_failure_message(path).is_equal(0)
		var names: Array[String] = []
		for row in rows:
			names.append(row.name)
		assert_array(names).contains(["AP-YARD", "CAM-YARD", "LASER-ROOF-W", "LASER-ROOF-E"])


# Entity paths (under Population/Security) of the devices cabled to `device`.
func _linked(device: Device) -> Array[String]:
	var found: Array[String] = []
	var root := _level.get_node(SECURITY)
	for link: NodePath in device.links:
		found.append(String(root.get_path_to(device.get_node(link))))
	return found


func _assert_reached(from: Device, paths: Array[String], expected: bool) -> void:
	for path: String in paths:
		(
			assert_bool(from.reaches(_entity(path)))
			. override_failure_message("reaches %s: %s" % [path, not expected])
			. is_equal(expected)
		)


# Entity paths (under Population/Security) of the devices on the deck's map.
func _map(session: DeckSession) -> Array[String]:
	var found: Array[String] = []
	var root := _level.get_node(SECURITY)
	for each in session.map_devices():
		found.append(String(root.get_path_to(each.entity)))
	return found


# Every guard (as placed) and every patrol point.
func _guard_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for guard: Node3D in _level.get_node("Population/People/Guards").get_children():
		spots.append(guard.global_position)
	for route: Node in _level.get_node("Population/People/Routes").get_children():
		for point: Node3D in route.get_children():
			spots.append(point.global_position)
	return spots


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return _level.get_world_3d().direct_space_state.intersect_ray(query)


# Light level of a player-sized body standing (or crouched) at `feet` (warehouse_light_test.gd).
func _measure(feet: Vector3, crouched: bool) -> float:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 0.95 if crouched else 1.8
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	body.add_child(shape)
	var tags := Tags.new()
	if crouched:
		tags.initial_tags = [&"stance.crouch"]
	body.add_child(tags)
	var exposure := LightExposure.new()
	body.add_child(exposure)
	_level.add_child(body)
	body.global_position = feet
	var level := exposure.update_now()
	body.free()
	return level
