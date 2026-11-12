extends GdUnitTestSuite
## The network lab's mail route station (M12c, ADR 0115; design/levels/hub-and-gallery.md "8 Network
## lab"): on the hall's east wall, MAIL-PC (unlocked as `guest`) fetches its mail from
## mail.halcyon.net on the internet through EDGE-RTR, whose InternetLink stands for the internet;
## the breaker beside them ("edge router") cuts the router: unread mail goes out of reach with a
## line naming EDGE-RTR, read mail stays. A network of its own (not cabled to the M12a chain). The
## room alone is loaded once.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/network_lab/network_lab.tscn")
const ORIGIN := Vector3(-300, 0, -900)
const CIRCUIT: StringName = &"network_lab_edge"
const HOST := "mail.halcyon.net"

var _room: Node3D
var _reader: Node3D


func before() -> void:
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)
	_reader = auto_free(Node3D.new())
	_reader.name = "MailReader"
	var reader_log := PersonalLog.new()
	reader_log.name = "PersonalLog"
	_reader.add_child(reader_log)
	add_child(_reader)
	await KitGeometry.settle(get_tree(), 5)


func before_test() -> void:
	EventLog.clear()


func after_test() -> void:
	Powered.set_circuit(get_tree(), CIRCUIT, true)


func _node(path: String) -> Node3D:
	return _room.get_node(path) as Node3D


func _computer() -> Computer:
	return Computer.of(_node("Devices/MailPc"))


func _titles() -> Array[String]:
	var titles: Array[String] = []
	for item in _computer().documents(Computer.MAIL, _computer().session_user, _reader):
		titles.append(item.title)
	return titles


func test_the_station_is_a_network_of_its_own_on_the_east_wall() -> void:
	var pc := Device.of(_node("Devices/MailPc"))
	var edge := Device.of(_node("Devices/EdgeRouter"))
	assert_array(DeviceNetwork.physical_network(pc)).contains_exactly_in_any_order([pc, edge])
	var link := _node("Devices/EdgeRouter").get_node("InternetLink") as InternetLink
	assert_bool(link.serves(HOST)).is_true()
	assert_str(_computer().mail_server).is_equal(HOST)
	assert_str(_computer().session_user).is_equal("guest")
	assert_str(String(Powered.of(_node("Devices/EdgeRouter")).circuit)).is_equal(String(CIRCUIT))
	var breaker := _node("Devices/EdgeBreaker").get_node("CircuitBreaker")
	assert_str(String(breaker.get(&"circuit"))).is_equal(String(CIRCUIT))
	for path: String in ["Devices/MailPc", "Devices/EdgeRouter", "Devices/EdgeBreaker"]:
		var local := _node(path).position
		assert_float(local.x).override_failure_message(path).is_equal_approx(11.99, 0.001)
		assert_float(local.z).override_failure_message(path).is_between(-11.0, -5.0)
	assert_str((_node("Labels/MailRoute") as Label3D).text).contains("EDGE-RTR")


func test_the_breaker_cuts_unread_mail_and_restoring_it_brings_it_back() -> void:
	assert_bool(_computer().mail_route().reached).is_true()
	assert_array(_titles()).has_size(2)
	var first := _computer().data.mail[0]
	_computer().read(first, _reader, "Mail")
	Powered.set_circuit(get_tree(), CIRCUIT, false)
	var route := _computer().mail_route()
	assert_bool(route.reached).is_false()
	assert_str(route.reason()).is_equal("Can't reach mail.halcyon.net: no route (EDGE-RTR is down)")
	assert_array(_titles()).contains_exactly([first.title])
	Powered.set_circuit(get_tree(), CIRCUIT, true)
	assert_bool(_computer().mail_route().reached).is_true()
	assert_array(_titles()).has_size(2)
