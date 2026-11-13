extends GdUnitTestSuite
## Integration across M12b's intrusion (ADR 0121) and wireless (ADR 0117), on the lab network with
## the access point AP-YARD and its wireless devices (network_fixtures.gd add_wireless()): CAM-YARD
## (wireless) and CAM-DOCK (cabled) tagged as cameras here. A camera exploit item opens the wireless
## camera from a deck on the office jack (through the hacked router) and from a deck joined over
## Wi-Fi, and only that camera; a firewall rule stops a wireless camera's incident reaching an alarm
## controller across the router; a rule from "you" judges a Wi-Fi deck as it judges a deck on a jack.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const ORIGIN := Vector3(620, 0, -300)
## Beside AP-YARD (12, 2.6, 3): about 3 m, in the Untrained Wi-Fi range (8 m).
const NEAR_AP := Vector3(12, 0, 6)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession
var _deck: ItemStack


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	Net.add_wireless(_n, _root, ORIGIN)
	for entity_name: String in ["CamYard", "CamDock"]:
		ActorState.set_tag(_n[entity_name], &"object.camera", true)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))
	_session = DeckSession.of(_user)
	_deck = Net.carry(_user, {&"camera": 1})


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _seconds(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await get_tree().physics_frame


func _fast() -> void:
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1


# Uses the camera item on CAM-YARD: admin there, the item gone, CAM-DOCK still closed.
func _use_on_cam_yard(address: String) -> void:
	var cam := _dev("CamYard")
	assert_bool(_session.is_online(cam)).is_true()
	assert_bool(ExploitItems.use_from_deck(_session, cam)).is_true()
	assert_bool(cam.is_admin(_user)).is_true()
	assert_bool(_dev("CamDock").has_access(_user)).is_false()
	assert_int(ExploitItems.count(_user, &"camera")).is_equal(0)
	assert_bool(ExploitItems.use_from_deck(_session, _dev("CamDock"))).is_false()
	var used := cam.intrusion.device_log.of_kind(DeviceLog.EXPLOIT)
	assert_str(str(used[0]["address"])).is_equal(address)


func test_a_camera_item_opens_a_wireless_camera_from_a_jack_through_the_router() -> void:
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	_fast()
	assert_bool(_session.plug(_dev("Jack"), _deck)).is_true()
	_use_on_cam_yard("10.0.10.40")


func test_a_camera_item_opens_a_wireless_camera_over_wifi() -> void:
	_user.global_position = ORIGIN + NEAR_AP
	AccessPoint.of(_n["ApYard"]).grant_key(_user)
	_fast()
	assert_bool(_session.plug(_dev("ApYard"), _deck)).is_true()
	assert_bool(_session.is_wireless()).is_true()
	await _seconds(0.1)
	_use_on_cam_yard("10.0.20.90")


func test_a_firewall_rule_stops_a_wireless_cameras_incident_across_the_router() -> void:
	# An alarm controller stand-in on the office side: incidents from the security subnet cross RTR-01.
	var receptrons: Array[Receptron] = [Devices.command_receptron(Device.INCIDENT, [Fixtures.add_tag(Net.ALARMED)])]
	var office_alarm := Net.body_device(_root, "OfficeAlarm", ORIGIN + Vector3(3, 1.5, 2), receptrons)
	Device.of(office_alarm).address = "10.0.10.41"
	Net.link(_n["OfficeSwitch"], office_alarm)
	var router := Router.of(_n["Rtr01"])
	var camera := _dev("CamYard")
	router.add_rule(
		RouterRule.make(RouterRule.Match.DEVICE, "10.0.20.22", RouterRule.Match.DEVICE, "10.0.10.41", false)
	)
	assert_bool(camera.reached(Device.INCIDENT).has(Device.of(office_alarm))).is_false()
	camera.report_incident(camera.entity.global_position)
	await _seconds(0.05)
	assert_bool(ActorState.has(office_alarm, Net.ALARMED)).is_false()
	router.remove_rule(0)
	camera.report_incident(camera.entity.global_position)
	await _seconds(0.05)
	assert_bool(ActorState.has(office_alarm, Net.ALARMED)).is_true()


func test_a_rule_from_you_judges_a_wifi_deck_like_a_deck_on_a_jack() -> void:
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	var wifi := NetworkSource.wireless(_user, _dev("ApYard"))
	var jack := NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)
	assert_bool(wifi.reaches(get_tree(), _dev("OfficePc"))).is_true()
	assert_bool(jack.reaches(get_tree(), _dev("CamYard"))).is_true()
	var router := Router.of(_n["Rtr01"])
	router.add_rule(RouterRule.make(RouterRule.Match.YOU, "", RouterRule.Match.SUBNET, "office", false))
	router.add_rule(RouterRule.make(RouterRule.Match.YOU, "", RouterRule.Match.DEVICE, "10.0.20.22", false))
	assert_bool(wifi.reaches(get_tree(), _dev("OfficePc"))).is_false()
	assert_bool(jack.reaches(get_tree(), _dev("CamYard"))).is_false()
	# Only the named targets: the rest stays in reach with the account.
	assert_bool(jack.reaches(get_tree(), _dev("CamDock"))).is_true()
	# The Wi-Fi deck's own subnet does not cross the router at all.
	assert_bool(wifi.reaches(get_tree(), _dev("CamYard"))).is_true()
