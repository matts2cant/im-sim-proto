extends GdUnitTestSuite
## Integration (ADR 0113): reach on the lab network (network_fixtures.gd) built from components.
## A deck's traffic (NetworkSource) reaches its own subnet and the router in front of it; a router
## lets a user's traffic through only once the user has an account on it (hidden, then revealed,
## then chained); devices' own traffic passes routers by default; a router's rules come first; a
## maintenance port reaches its device only; power cuts and breaking cut reach as before; a trust
## list limits who may command a device.

const Wait := preload("res://tests/helpers/wait.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Devices := preload("res://tests/objects/devices/device_fixtures.gd")
const ORIGIN := Vector3(300, 0, -300)

var _root: Node3D
var _n: Dictionary[String, Node3D]
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n = Net.lab(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + Vector3(0, 0, 1))


func after_test() -> void:
	StimulusSystem.clear()


func _jack() -> NetworkSource:
	return NetworkSource.for_user(_user, _dev("Jack"), NetworkSource.Kind.JACK)


func _dev(entity_name: String) -> Device:
	return Device.of(_n[entity_name])


func _names(devices: Array[Device]) -> Array[String]:
	var found: Array[String] = []
	for each in devices:
		found.append(String(each.entity.name))
	return found


func test_subnets_come_from_the_switch_a_device_hangs_on() -> void:
	assert_str(String(DeviceNetwork.subnet_of(_dev("OfficePc")))).is_equal("office")
	assert_str(String(DeviceNetwork.subnet_of(_dev("Console")))).is_equal("security")
	assert_str(String(DeviceNetwork.subnet_of(_dev("FileServer")))).is_equal("servers")
	# A router names its own side.
	assert_str(String(DeviceNetwork.subnet_of(_dev("Rtr01")))).is_equal("office")
	assert_array(Array(Router.of(_n["Rtr01"]).subnets())).contains_exactly_in_any_order([&"office", &"security"])


func test_a_jack_reaches_its_subnet_and_its_router_only() -> void:
	var source := _jack()
	assert_str(source.address).is_equal("10.0.10.40")
	assert_str(String(source.subnet)).is_equal("office")
	var reached := _names(source.reached(get_tree()))
	assert_array(reached).contains_exactly_in_any_order(["Jack", "OfficeSwitch", "OfficePc", "Rtr01"])
	assert_bool(source.reaches(get_tree(), _dev("Console"))).is_false()


func test_hacking_a_router_reveals_what_is_behind_it_and_chains() -> void:
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	var reached := _names(_jack().reached(get_tree()))
	assert_array(reached).contains(["SecuritySwitch", "Console", "Camera", "Alarm", "Rtr02"])
	assert_bool(reached.has("FileServer")).is_false()
	# The second router, inside the revealed subnet, hides the servers until it is hacked too.
	DeviceAccounts.of(_n["Rtr02"]).grant(_user, "admin")
	assert_bool(_jack().reaches(get_tree(), _dev("FileServer"))).is_true()
	# Another user has hacked nothing.
	var other := Net.user(_root, ORIGIN + Vector3(0, 0, 2))
	(
		assert_bool(
			NetworkSource.for_user(other, _dev("Jack"), NetworkSource.Kind.JACK).reaches(get_tree(), _dev("Console"))
		)
		. is_false()
	)


func test_devices_traffic_crosses_routers_by_default() -> void:
	# The router's tracer reports to the alarm controller behind it; the console reaches the camera.
	assert_bool(_dev("Rtr01").reaches(_dev("Alarm"))).is_true()
	assert_bool(_dev("OfficePc").reaches(_dev("FileServer"))).is_true()
	Router.of(_n["Rtr02"]).default_allow = false
	assert_bool(_dev("OfficePc").reaches(_dev("FileServer"))).is_false()
	assert_bool(_dev("Rtr02").reaches(_dev("FileServer"))).is_true()


func test_rules_come_first_and_the_first_match_wins() -> void:
	var router := Router.of(_n["Rtr01"])
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	router.rules = [
		RouterRule.make(RouterRule.Match.YOU, "", RouterRule.Match.DEVICE, "Console", false),
		RouterRule.make(RouterRule.Match.ANY, "", RouterRule.Match.SUBNET, "security", true),
	]
	# Hacked, but a rule denies "you" the console; the rest of the subnet is allowed.
	assert_bool(_jack().reaches(get_tree(), _dev("Console"))).is_false()
	assert_bool(_jack().reaches(get_tree(), _dev("Camera"))).is_true()
	# A device rule matches by name or address.
	router.rules = [RouterRule.make(RouterRule.Match.DEVICE, "10.0.10.12", RouterRule.Match.ANY, "", false)]
	assert_bool(_dev("OfficePc").reaches(_dev("Console"))).is_false()
	assert_bool(_dev("OfficeSwitch").reaches(_dev("Console"))).is_true()
	# Saved and loaded with the router.
	var saved := router.save_state()
	router.rules = []
	router.load_state(saved)
	assert_int(router.rules.size()).is_equal(1)
	assert_str(router.rules[0].from).is_equal("10.0.10.12")
	assert_bool(router.rules[0].allow).is_false()


func test_a_maintenance_port_reaches_its_device_only() -> void:
	assert_int(DeviceNetwork.port_kind(_dev("Kiosk"))).is_equal(Device.DeckPort.MAINTENANCE)
	assert_int(DeviceNetwork.port_kind(_dev("OfficePc"))).is_equal(Device.DeckPort.HOST)
	assert_int(DeviceNetwork.port_kind(_dev("Jack"))).is_equal(Device.DeckPort.JACK)
	assert_int(DeviceNetwork.port_kind(_dev("Camera"))).is_equal(Device.DeckPort.NONE)
	var port := NetworkSource.for_user(_user, _dev("Kiosk"), NetworkSource.Kind.PORT)
	assert_array(_names(port.reached(get_tree()))).is_equal(["Kiosk"])
	assert_str(port.address).is_equal("port:10.0.40.9")


func test_a_computer_lends_its_address_and_its_reach() -> void:
	var host := NetworkSource.for_user(_user, _dev("OfficePc"), NetworkSource.Kind.HOST)
	assert_str(host.address).is_equal("10.0.10.12")
	var reached := _names(host.reached(get_tree()))
	assert_array(reached).contains(["OfficePc", "OfficeSwitch", "Jack", "Rtr01"])
	# Its own traffic crosses the router, the user's does not.
	assert_bool(_dev("OfficePc").reaches(_dev("Console"))).is_true()
	assert_bool(host.reaches(get_tree(), _dev("Console"))).is_false()


func test_power_cuts_and_breaking_cut_reach_behind_them() -> void:
	DeviceAccounts.of(_n["Rtr01"]).grant(_user, "admin")
	Powered.of(_n["SecuritySwitch"]).on = false
	var source := _jack()
	assert_bool(source.reaches(get_tree(), _dev("Console"))).is_false()
	# Dead devices right behind a reached one still show (greyed on a map).
	assert_bool(_names(source.connected(get_tree())).has("SecuritySwitch")).is_true()
	assert_bool(_names(source.connected(get_tree())).has("Console")).is_false()
	Powered.of(_n["SecuritySwitch"]).on = true
	Breakable.of(_n["Rtr01"]).take_damage(&"damage.ballistic", 100.0)
	assert_bool(source.reaches(get_tree(), _dev("Console"))).is_false()
	assert_bool(source.reaches(get_tree(), _dev("OfficePc"))).is_true()


func test_a_trust_list_limits_who_commands_a_device() -> void:
	assert_bool(DeviceNetwork.trusts(_dev("Camera"), _dev("Console"))).is_true()
	assert_bool(DeviceNetwork.trusts(_dev("Camera"), _dev("OfficePc"))).is_false()
	# No list: anyone that reaches it (M8's behaviour).
	assert_bool(DeviceNetwork.trusts(_dev("Alarm"), _dev("OfficePc"))).is_true()
	assert_bool(_dev("OfficePc").send_command(Device.DISABLE, _n["Camera"])).is_false()
	assert_bool(_dev("Console").send_command(Device.DISABLE, _n["Camera"])).is_true()
	await Wait.frames(get_tree(), 3)
	assert_bool(DeviceSwitch.of(_n["Camera"]).disabled).is_true()
	assert_str(" ".join(DeviceStatus.of(_n["Camera"], true))).is_equal("online disabled")
	# Incidents are reports, not commands: a trust list does not stop them.
	Device.of(_n["Alarm"]).trusted.append(Device.of(_n["Alarm"]).get_path_to(_n["Console"]))
	assert_int(_dev("Rtr01").report_incident(ORIGIN)).is_equal(1)


func test_a_level_without_network_data_keeps_one_open_network() -> void:
	var plain := auto_free(Node3D.new()) as Node3D
	add_child(plain)
	var a := Devices.device(plain, "A", Vector3(300, 0, -320))
	var hub := Devices.device(plain, "Hub", Vector3(302, 0, -320))
	var b := Devices.device(plain, "B", Vector3(304, 0, -320), [Devices.action_receptron(Device.RING)])
	Devices.link(a, hub)
	Devices.link(hub, b)
	assert_str(String(DeviceNetwork.subnet_of(Device.of(b)))).is_empty()
	assert_bool(Device.of(a).reaches(b)).is_true()
	assert_bool(Device.of(a).send_command(Device.RING, b)).is_true()
	# A deck on such a network's cabled device: no port (only jacks, computers and autonomous
	# devices take one).
	assert_int(DeviceNetwork.port_kind(Device.of(hub))).is_equal(Device.DeckPort.NONE)
