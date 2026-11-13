extends GdUnitTestSuite
## Integration (M12b, ADR 0115, 0117): wireless links in the reach graph. The lab network
## (network_fixtures.gd) with the access point AP-YARD on the security switch, its wireless camera
## and laser and a cabled camera beside it (add_wireless()). A wireless device reaches and is reached
## through its access point and is on its subnet; breaking or unpowering the access point takes its
## wireless devices offline (to the deck and to other devices) while the cabled device beside it
## stays online; network gear never links wirelessly; out of the access point's range there is no
## link. The same holds for an access point built from components (a minimal entity).

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const ORIGIN := Vector3(-340, 0, -420)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	Net.add_wireless(_n, _root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))
	# The deck's user hacked RTR-01: its traffic reaches the security subnet.
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")


func after_test() -> void:
	StimulusSystem.clear()


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


# The deck on the office jack.
func _deck() -> NetworkSource:
	return NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)


func _reaches(entity_name: String) -> bool:
	return _deck().reaches(get_tree(), _dev(entity_name))


func test_a_wireless_device_links_through_its_access_point_on_its_subnet() -> void:
	assert_object(_dev("CamYard").wireless_link()).is_same(_dev("ApYard"))
	assert_object(_dev("LaserRoof").wireless_link()).is_same(_dev("ApYard"))
	assert_str(String(DeviceNetwork.subnet_of(_dev("ApYard")))).is_equal("security")
	assert_str(String(DeviceNetwork.subnet_of(_dev("CamYard")))).is_equal("security")
	assert_array(DeviceNetwork.wireless_devices(_dev("ApYard"))).contains_exactly_in_any_order(
		[_dev("CamYard"), _dev("LaserRoof")]
	)
	# Reach both ways: the deck (through the hacked router) and a device on the cabled side.
	assert_bool(_reaches("CamYard")).is_true()
	assert_bool(_dev("CamYard").reaches(_n["Alarm"])).is_true()
	assert_bool(_dev("Console").reaches(_n["LaserRoof"])).is_true()
	# A wireless link is not a cable: not autonomous, so no maintenance port.
	assert_bool(DeviceNetwork.cabled(_dev("CamYard")).is_empty()).is_true()
	assert_int(DeviceNetwork.port_kind(_dev("CamYard"))).is_equal(NetworkSource.Kind.NONE)
	# Incidents go out over the radio link too.
	assert_int(_dev("CamYard").report_incident(_n["CamYard"].global_position)).is_equal(1)


func test_breaking_the_access_point_takes_its_wireless_devices_offline() -> void:
	Breakable.of(_n["ApYard"]).take_damage(&"damage.ballistic", 100.0)
	assert_bool(_dev("ApYard").is_up()).is_false()
	for entity_name: String in ["CamYard", "LaserRoof"]:
		assert_bool(_reaches(entity_name)).override_failure_message(entity_name).is_false()
		assert_bool(_dev(entity_name).reaches(_n["Alarm"])).override_failure_message(entity_name).is_false()
	# As for a cut cable: still up themselves, offline on a screen (DeviceStatus words).
	assert_bool(_dev("CamYard").is_up()).is_true()
	assert_array(Array(DeviceStatus.of(_n["CamYard"], _reaches("CamYard")))).is_equal(["offline"])
	# The cabled camera beside it stays online.
	assert_bool(_reaches("CamDock")).is_true()
	assert_bool(_dev("CamDock").reaches(_n["Alarm"])).is_true()
	# Seen from the deck, the dead access point is there and its wireless devices behind it.
	var connected := _deck().connected(get_tree())
	assert_bool(connected.has(_dev("ApYard"))).is_true()


func test_unpowering_the_access_point_takes_its_wireless_devices_offline() -> void:
	Powered.of(_n["ApYard"]).on = false
	assert_bool(_reaches("CamYard")).is_false()
	assert_bool(_reaches("LaserRoof")).is_false()
	assert_bool(_reaches("CamDock")).is_true()
	Powered.of(_n["ApYard"]).on = true
	assert_bool(_reaches("CamYard")).is_true()


func test_network_gear_never_links_wirelessly() -> void:
	# A switch, a router and another access point naming AP-YARD: no link, and still on their cables.
	var other_ap := Net.instance(_root, Net.ACCESS_POINT, "ApOther", ORIGIN + Vector3(13, 2.6, 4), &"", "10.0.20.62")
	var gear: Array[Node3D] = [_n["ServerSwitch"], _n["Rtr02"], other_ap]
	for entity: Node3D in gear:
		Net.link_wireless(entity, _n["ApYard"])
		assert_object(Device.of(entity).wireless_link()).override_failure_message(entity.name).is_null()
		assert_bool(DeviceNetwork.is_network_gear(Device.of(entity))).is_true()
	# They keep their own subnets and are not AP-YARD's wireless devices.
	assert_str(String(DeviceNetwork.subnet_of(_dev("ServerSwitch")))).is_equal("servers")
	assert_array(DeviceNetwork.wireless_devices(_dev("ApYard"))).has_size(2)
	assert_bool(DeviceNetwork.is_network_gear(_dev("CamYard"))).is_false()


func test_out_of_the_access_points_range_there_is_no_link() -> void:
	var radio := AccessPoint.of(_n["ApYard"])
	# CAM-YARD stands 4.5 m from AP-YARD (centre to centre); a 3 m range leaves it out.
	var gap := _n["CamYard"].global_position.distance_to(_n["ApYard"].global_position)
	assert_float(gap).is_between(4.0, 5.0)
	radio.wireless_range = 3.0
	assert_object(_dev("CamYard").wireless_link()).is_null()
	assert_bool(_reaches("CamYard")).is_false()
	# LASER-ROOF (3.9 m) also drops at 3 m; back to 6 m both link again.
	assert_bool(_reaches("LaserRoof")).is_false()
	radio.wireless_range = 6.0
	assert_bool(_reaches("CamYard")).is_true()
	assert_bool(_reaches("LaserRoof")).is_true()


func test_an_access_point_from_components_behaves_the_same() -> void:
	# A minimal entity: a box with a Device, Powered, Breakable and an AccessPoint (no scene), cabled
	# to the security switch; a minimal sensor links to it by radio.
	var ap := Net.body_device(_root, "Ap2", ORIGIN + Vector3(6, 2, 6), [], true, 20.0)
	var radio := AccessPoint.new()
	radio.name = "AccessPoint"
	radio.wireless_range = 5.0
	ap.add_child(radio)
	Net.link(_n["SecuritySwitch"], ap)
	var sensor := Net.body_device(_root, "Sensor", ORIGIN + Vector3(7, 1, 8))
	Net.link_wireless(sensor, ap)
	assert_bool(DeviceNetwork.is_network_gear(Device.of(ap))).is_true()
	assert_str(String(DeviceNetwork.subnet_of(Device.of(sensor)))).is_equal("security")
	assert_bool(_deck().reaches(get_tree(), Device.of(sensor))).is_true()
	Powered.of(ap).on = false
	assert_bool(_deck().reaches(get_tree(), Device.of(sensor))).is_false()


func test_saving_keeps_who_knows_the_key() -> void:
	var radio := AccessPoint.of(_n["ApYard"])
	assert_bool(radio.knows_key(_user)).is_false()
	radio.grant_key(_user)
	assert_bool(radio.knows_key(_user)).is_true()
	assert_int(EventLog.find(&"network.wifi_key").size()).is_equal(1)
	var data: Variant = JSON.from_native(radio.save_state())
	radio.load_state({"known": []})
	assert_bool(radio.knows_key(_user)).is_false()
	radio.load_state(JSON.to_native(data) as Dictionary)
	assert_bool(radio.knows_key(_user)).is_true()
	# The deck joining over Wi-Fi gets the access point's client address on its subnet.
	var source := NetworkSource.wireless(_user, _dev("ApYard"))
	assert_str(source.address).is_equal("10.0.20.90")
	assert_str(String(source.subnet)).is_equal("security")
	assert_bool(source.reaches(get_tree(), _dev("CamYard"))).is_true()
	assert_bool(source.reaches(get_tree(), _dev("Rtr01"))).is_true()
