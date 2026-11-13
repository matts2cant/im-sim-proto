extends GdUnitTestSuite
## Warehouse intrusion data (M12b, design/levels/mission-warehouse.md "Wireless and intrusion
## (M12b)", ADR 0121): every networked device is of a kind the deck's Map draws an icon for; two
## exploit items lie in the level: a camera exploit on office desk 1 (where office PC 1's mail used
## to teach it) and an alarm exploit beside the field service datapad on the water tower deck. The
## alarm item, used over AP-YARD, gives admin on the yard's alarm controller at once, without trace.
## No document teaches an exploit any more. RTR-01's rules: Security -> Office allow, Office ->
## SEC-CONSOLE allow, Office -> MAIL-01 allow (M12c), Office -> Security deny; a deck with access to
## RTR-01 still passes (only rules from "you" judge it). The sirens and both alarm controllers are
## on the Security subnet, so no RTR-01 rule silences them. The level is loaded once.

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const SECURITY := "Population/Security/"
## Every camera (a camera exploit opens each).
const CAMERAS: Array[String] = [
	"Devices/CameraGate", "Devices/CameraYard", "Devices/CameraHall", "Devices/CameraOffice", "Devices/CameraRoof"
]
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
		device.intrusion.from_dict({"log": [], "exploit_admins": []})
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


func test_every_networked_device_is_of_a_kind_with_an_icon() -> void:
	var kinds := DeviceKinds.shipped()
	var missing: PackedStringArray = []
	for device in _security_devices():
		# MAIL-01 is a rack server since ADR 0130 step 3: a computer, of the computer kind.
		var kind := kinds.kind_for(device.entity)
		if kind == null or kind.icon.is_empty():
			missing.append(_path(device))
	assert_array(Array(missing)).is_empty()
	for path: String in CAMERAS:
		assert_str(String(ExploitItems.kind_of(_device(path)))).override_failure_message(path).is_equal("camera")
	for path: String in ["Devices/AlarmController", "Devices/AlarmControllerYard"]:
		assert_str(String(ExploitItems.kind_of(_device(path)))).override_failure_message(path).is_equal("alarm")
	assert_str(String(ExploitItems.kind_of(_device("Network/OfficeBay/Rtr01")))).is_equal("router")


func test_the_exploit_items_lie_at_their_places() -> void:
	# The camera exploit on office desk 1 (top 0.75 m above its floor at 4.5), the alarm one on the
	# water tower deck (20 m, x 42..50, z -20..-12) beside the field service datapad.
	var desk := _entity("Furniture/OfficeDesk1")
	var camera_item := _entity("Items/CameraExploit")
	assert_str(String(ItemPickup.of(camera_item).item.exploit_kind)).is_equal("camera")
	# A ledge's origin is its lip; its top extends `depth` (0.8 m) along its local -z.
	var on_desk := desk.to_local(camera_item.global_position)
	assert_float(on_desk.y).is_between(0.74, 0.85)
	assert_float(absf(on_desk.x)).is_less(0.6)
	assert_float(on_desk.z).is_between(-0.7, -0.1)
	var alarm_item := _entity("Items/AlarmExploit")
	assert_str(String(ItemPickup.of(alarm_item).item.exploit_kind)).is_equal("alarm")
	var at := alarm_item.global_position
	assert_float(at.y).is_between(20.0, 20.1)
	assert_bool(Rect2(42.3, -19.7, 7.4, 7.4).has_point(Vector2(at.x, at.z))).is_true()
	assert_float(at.distance_to(_entity("Items/TowerNotes").global_position)).is_less(1.0)
	# Something solid right under each (a ray down from 5 cm above).
	var space := _level.get_world_3d().direct_space_state
	for item: Node3D in [camera_item, alarm_item]:
		var query := PhysicsRayQueryParameters3D.create(
			item.global_position + Vector3.UP * 0.05, item.global_position + Vector3.DOWN * 0.1, PhysicsLayers.WORLD
		)
		assert_bool(space.intersect_ray(query).is_empty()).override_failure_message(item.name).is_false()
	# The camera mail is gone, and the datapad no longer talks about firmware.
	for document in Computer.of(_entity("Network/OfficePc1")).data.mail:
		assert_str(document.title).is_not_equal("Camera firmware")
	var notes := (_entity("Items/TowerNotes").get_node("Readable") as Readable).text
	assert_bool(notes.contains("firmware")).is_false()


func test_the_alarm_item_over_ap_yard_opens_the_yard_controller_without_trace() -> void:
	var user := Net.user(_level, ROOF_EYE)
	var deck := Net.carry(user, {&"alarm": 1})
	var session := DeckSession.of(user)
	session.config = session.config.duplicate() as DeckConfig
	session.config.scan_time = 0.1
	AccessPoint.of(_entity("Devices/ApYard")).grant_key(user)
	assert_bool(session.plug(_device("Devices/ApYard"), deck)).is_true()
	await _frames(10)
	var controller := _device("Devices/AlarmControllerYard")
	assert_bool(session.is_online(controller)).is_true()
	var before := _tracer().trace_of(user)
	assert_bool(ExploitItems.can_use(user, controller)).is_true()
	assert_bool(ExploitItems.can_use(user, _device("Devices/CameraYard"))).is_false()
	assert_bool(ExploitItems.use_from_deck(session, controller)).is_true()
	assert_bool(controller.is_admin(user)).is_true()
	assert_float(_tracer().trace_of(user)).is_equal_approx(before, 0.001)
	assert_int(ExploitItems.count(user, &"alarm")).is_equal(0)
	assert_bool(ExploitItems.can_use(user, _device("Devices/AlarmController"))).is_false()
	session.unplug()
	user.free()


func test_rtr01_keeps_the_office_off_security_except_the_console() -> void:
	var router := Router.of(_entity("Network/OfficeBay/Rtr01"))
	assert_int(router.rules.size()).is_equal(4)
	assert_bool(router.default_allow).is_true()
	var pc := _device("Network/OfficePc1")
	# Office devices reach the console and MAIL-01 (M12c) only; the security devices reach the office.
	assert_bool(pc.reaches(_entity("Devices/SecurityConsole"))).is_true()
	assert_bool(pc.reaches(_entity("Network/OfficeBay/MailServer"))).is_true()
	for path: String in ["Doors/VaultDoor/Hardware/Controller", "Devices/CameraHall", "Devices/AlarmController"]:
		assert_bool(pc.reaches(_entity(path))).override_failure_message(path).is_false()
	assert_bool(_device("Devices/SecurityConsole").reaches(_entity("Network/OfficePc1"))).is_true()
	# RTR-01 itself sends freely: its tracer's incidents reach the alarm controllers.
	for path: String in ["Devices/AlarmController", "Devices/AlarmControllerYard"]:
		assert_bool(_device("Network/OfficeBay/Rtr01").reaches(_entity(path))).override_failure_message(path).is_true()
	# A deck on the office jack with access to RTR-01 passes (no rule names "you").
	var user := Net.user(_level, AT_JACK)
	var jack := NetworkSource.for_user(user, _device("Network/OfficeWallJack"), NetworkSource.Kind.JACK)
	assert_bool(jack.reaches(get_tree(), _device("Devices/CameraHall"))).is_false()
	DeviceAccounts.of(_entity("Network/OfficeBay/Rtr01")).grant(user, "admin")
	assert_bool(jack.reaches(get_tree(), _device("Devices/CameraHall"))).is_true()
	DeviceAccounts.of(_entity("Network/OfficeBay/Rtr01")).set_password(
		"admin", DeviceAccounts.of(_entity("Network/OfficeBay/Rtr01")).account("admin").password
	)
	# Every siren and both alarm controllers are on Security: no rule at RTR-01 stands between them.
	for node in _level.find_children("Siren*", "", true, false):
		var siren := Device.of(node)
		if siren != null:
			assert_str(String(DeviceNetwork.subnet_of(siren))).override_failure_message(node.name).is_equal("security")
	user.free()


func _path(device: Device) -> String:
	return String(_level.get_node(SECURITY).get_path_to(device.entity))


# Every device with an address under Population/Security.
func _security_devices() -> Array[Device]:
	var found: Array[Device] = []
	for node in _level.get_node(SECURITY).find_children("*", "Device", true, false):
		if not (node as Device).address.is_empty():
			found.append(node as Device)
	return found
