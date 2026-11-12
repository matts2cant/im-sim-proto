extends GdUnitTestSuite
## Integration (M12c, ADR 0115): mail needs a route to its server, on minimal entities built in code
## (network_fixtures): any entity with a MailServer is an in-house server, any edge router with an
## InternetLink stands for the internet. Plan (metres from ORIGIN):
##
##   Pc (0,0) ── Switch (2,0) ── Rtr (4,0) ── ServerSwitch (6,0) ── Mail (8,0)   in-house MAIL-01
##   WebPc (0,2) ─┘   └── Edge (2,3): InternetLink serving mail.example.net
##
## Pc fetches from MAIL-01, WebPc from mail.example.net. Both hold two mails for everyone.

const Net := preload("res://tests/objects/network/network_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const ORIGIN := Vector3(300, 0, -340)
const OFF_SITE := "mail.example.net"

var _root: Node3D
var _n: Dictionary[String, Node3D] = {}
var _reader: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_n.clear()
	_n["Pc"] = Net.body_device(_root, "Pc", ORIGIN)
	_n["WebPc"] = Net.body_device(_root, "WebPc", ORIGIN + Vector3(0, 0, 2))
	_n["Switch"] = Net.instance(_root, Net.SWITCH, "Switch", ORIGIN + Vector3(2, 0, 0), &"office", "10.0.10.2")
	_n["Rtr"] = Net.instance(_root, Net.ROUTER, "Rtr", ORIGIN + Vector3(4, 0, 0), &"office", "10.0.10.1")
	_n["ServerSwitch"] = Net.instance(
		_root, Net.SWITCH, "ServerSwitch", ORIGIN + Vector3(6, 0, 0), &"servers", "10.0.30.2"
	)
	_n["Mail"] = Net.body_device(_root, "Mail", ORIGIN + Vector3(8, 0, 0), [], true)
	_n["Edge"] = Net.instance(_root, Net.ROUTER, "Edge", ORIGIN + Vector3(2, 0, 3), &"office", "10.0.10.254")
	var server := MailServer.new()
	server.name = "MailServer"
	server.host = "MAIL-01"
	_n["Mail"].add_child(server)
	var internet := InternetLink.new()
	internet.name = "InternetLink"
	internet.hosts = PackedStringArray([OFF_SITE])
	_n["Edge"].add_child(internet)
	for pair: Array in [["Pc", "Switch"], ["WebPc", "Switch"], ["Switch", "Rtr"], ["Rtr", "ServerSwitch"]]:
		Net.link(_n[pair[0]], _n[pair[1]])
	Net.link(_n["ServerSwitch"], _n["Mail"])
	Net.link(_n["Switch"], _n["Edge"])
	var names := {"Rtr": "RTR-01", "Edge": "EDGE-RTR", "Switch": "SW-OFFICE", "ServerSwitch": "SW-SERVERS"}
	for key: String in names:
		_n[key].set_meta(&"display_name", names[key])
	_computer("Pc", "MAIL-01")
	_computer("WebPc", OFF_SITE)
	var user_root := Node3D.new()
	var reader_log := PersonalLog.new()
	reader_log.name = "PersonalLog"
	user_root.add_child(reader_log)
	_reader = Fixtures.compose(user_root, _root, "Reader", ORIGIN + Vector3(0, 0, -2), [])
	await _frames(2)


func after_test() -> void:
	StimulusSystem.clear()


func _computer(key: String, host: String) -> void:
	var computer := Net.add_computer(_n[key])
	computer.mail_server = host
	computer.data = ComputerData.new()
	for i in 2:
		var mail := ComputerDocument.new()
		mail.id = StringName("test.mail.%s.%d" % [key, i])
		mail.title = "Mail %d" % i
		mail.text = "Body %d" % i
		computer.data.mail.append(mail)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Waits physics frames until `condition` holds (at most 2 s of 144 Hz frames).
func _until(condition: Callable) -> void:
	for i in 288:
		if condition.call():
			return
		await get_tree().physics_frame


func _titles(key: String) -> Array[String]:
	var titles: Array[String] = []
	for item in Computer.of(_n[key]).documents(Computer.MAIL, "anyone", _reader):
		titles.append(item.title)
	return titles


func _power(key: String, on: bool) -> void:
	Powered.of(_n[key]).on = on


func test_an_in_house_server_reached_shows_every_mail() -> void:
	var route := Computer.of(_n["Pc"]).mail_route()
	assert_bool(route.reached).is_true()
	assert_str(route.reason()).is_empty()
	assert_array(_titles("Pc")).contains_exactly(["Mail 0", "Mail 1"])


func test_a_cut_route_keeps_only_read_mail_and_names_the_down_router_then_comes_back() -> void:
	var computer := Computer.of(_n["Pc"])
	computer.read(computer.data.mail[0], _reader, "Mail")
	_power("Rtr", false)
	var route := computer.mail_route()
	assert_bool(route.reached).is_false()
	assert_str(route.reason()).is_equal("Can't reach MAIL-01: no route (RTR-01 is down)")
	assert_array(_titles("Pc")).contains_exactly(["Mail 0"])
	# The server itself down names the server; a firewall-free cut with nothing down says "no route".
	_power("Rtr", true)
	_power("Mail", false)
	assert_str(computer.mail_route().reason()).is_equal("Can't reach MAIL-01: no route (Mail is down)")
	_power("Mail", true)
	assert_bool(computer.mail_route().reached).is_true()
	assert_array(_titles("Pc")).contains_exactly(["Mail 0", "Mail 1"])


func test_an_off_site_server_is_reached_through_the_edge_routers_internet_link() -> void:
	var computer := Computer.of(_n["WebPc"])
	assert_bool(computer.mail_route().reached).is_true()
	assert_array(_titles("WebPc")).contains_exactly(["Mail 0", "Mail 1"])
	# The in-house router does not matter to it; the edge router does.
	_power("Rtr", false)
	assert_bool(computer.mail_route().reached).is_true()
	_power("Edge", false)
	assert_str(computer.mail_route().reason()).is_equal("Can't reach mail.example.net: no route (EDGE-RTR is down)")
	assert_array(_titles("WebPc")).is_empty()
	_power("Edge", true)
	assert_bool(computer.mail_route().reached).is_true()


func test_an_unknown_host_has_no_route_and_no_server_means_local_mail() -> void:
	var computer := Computer.of(_n["Pc"])
	computer.mail_server = "nowhere.example"
	assert_str(computer.mail_route().reason()).is_equal("Can't reach nowhere.example: no route")
	computer.mail_server = ""
	assert_bool(computer.mail_route().reached).is_true()
	_power("Rtr", false)
	assert_array(_titles("Pc")).contains_exactly(["Mail 0", "Mail 1"])


func test_a_remote_desktops_mail_follows_the_remote_computers_route() -> void:
	var screen := ComputerScreen.new()
	screen.name = "ComputerScreen"
	_reader.add_child(screen)
	var computer := Computer.of(_n["Pc"])
	computer.open_desktop(_reader, "anyone", true)
	assert_bool(screen.desktop_shown()).is_true()
	screen.show_app(ComputerScreen.App.MAIL)
	assert_bool(screen.mail_app.status_label.visible).is_false()
	assert_array(screen.mail_app.titles()).contains_exactly(["Mail 0", "Mail 1"])
	# Showing Mail read the first mail; cut the route and the screen refills on its next refresh.
	_power("Rtr", false)
	await _until(func() -> bool: return screen.mail_app.status_label.visible)
	assert_bool(screen.mail_app.status_label.visible).is_true()
	assert_str(screen.mail_app.status_label.text).is_equal("Can't reach MAIL-01: no route (RTR-01 is down)")
	assert_array(screen.mail_app.titles()).contains_exactly(["Mail 0"])
	_power("Rtr", true)
	await _until(func() -> bool: return not screen.mail_app.status_label.visible)
	assert_bool(screen.mail_app.status_label.visible).is_false()
	assert_array(screen.mail_app.titles()).contains_exactly(["Mail 0", "Mail 1"])
	screen.close()
