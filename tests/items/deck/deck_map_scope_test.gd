extends GdUnitTestSuite
## Integration (M12b map fix, ADR 0113 amendment): the deck's Map draws only the seen devices on the
## physical network of its entry point (DeviceNetwork.physical_network()), while the deck remembers
## everything it has seen. A minimal user entity (network_fixtures.gd user(): its origin is its eye)
## and two networks with no link between them: the lab (A, with AP-YARD and its wireless devices)
## and the annex (B, network_fixtures.gd annex(), with AP-ANNEX and CAM-ANNEX). The user's report:
## plugged into A, then into B, the Map still drew A.

const Wait := preload("res://tests/helpers/wait.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const ORIGIN := Vector3(460, 0, -300)
## The user's eye 1 m in front of the lab's jack (0, 0.5, 0) and of the annex's (-4, 0.5, 0).
const AT_A := Vector3(0, 1.6, 1)
const AT_B := Vector3(-4, 1.6, 1)
## 4.1 m from AP-ANNEX (-6, 2.6, 6), 18.2 m from AP-YARD (12, 2.6, 3): inside the Untrained 8 m only
## for the annex.
const NEAR_AP_ANNEX := Vector3(-6, 1.6, 2)
const LAB: Array[String] = ["Jack", "OfficeSwitch", "OfficePc", "Rtr01"]
const ANNEX: Array[String] = ["JackB", "SwitchB", "PcB", "PrinterB", "TerminalB", "ApAnnex", "CamAnnex"]

var _root: Node3D
var _a: Dictionary[String, Node3D]
var _b: Dictionary[String, Node3D]
var _user: Node3D
var _session: DeckSession
var _stack: ItemStack


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_a = Net.lab(_root, ORIGIN)
	Net.add_wireless(_a, _root, ORIGIN)
	_b = Net.annex(_root, ORIGIN)
	_user = Net.user(_root, ORIGIN + AT_A)
	_session = DeckSession.of(_user)
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_stack = Net.deck_stack()
	await Wait.frames(get_tree(), 2)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	StimulusSystem.clear()


func _map() -> Array[String]:
	var found: Array[String] = []
	for each in _session.map_devices():
		found.append(String(each.entity.name))
	return found


# Moves the user to `eye` and plugs into `entity` (a jack), then waits out the 0.1 s scan.
func _plug(entity: Node3D, eye: Vector3) -> void:
	_user.global_position = ORIGIN + eye
	assert_bool(_session.plug(Device.of(entity), _stack)).is_true()
	await Wait.frames(get_tree(), 15)


func test_after_network_a_the_map_on_network_b_draws_only_b_and_a_again_without_a_scan() -> void:
	await _plug(_a["Jack"], AT_A)
	assert_array(_map()).contains_exactly_in_any_order(LAB)
	_session.unplug()
	# The user's report: plugged into B, the Map still drew A.
	await _plug(_b["JackB"], AT_B)
	assert_array(_map()).contains_exactly_in_any_order(ANNEX)
	# The deck remembers A: back on A's jack its map shows at once, no new scan.
	_session.unplug()
	var scans := EventLog.find(&"deck.scan").size()
	_user.global_position = ORIGIN + AT_A
	assert_bool(_session.plug(Device.of(_a["Jack"]), _stack)).is_true()
	assert_array(_map()).contains_exactly_in_any_order(LAB)
	await Wait.frames(get_tree(), 15)
	assert_int(EventLog.find(&"deck.scan").size()).is_equal(scans)
	assert_array(_map()).contains_exactly_in_any_order(LAB)
	# Everything seen stays on the deck.
	var seen := _stack.state[DeckSession.SEEN] as Array
	assert_bool(seen.has(DeckSession.key_of(Device.of(_b["PcB"])))).is_true()


func test_broken_and_unpowered_devices_on_the_plugged_network_are_drawn_down() -> void:
	Breakable.of(_b["PrinterB"]).take_damage(&"damage.ballistic", 100.0)
	await _plug(_b["JackB"], AT_B)
	Powered.of(_b["TerminalB"]).on = false
	_session.refresh()
	assert_bool(Device.of(_b["PrinterB"]).is_up()).is_false()
	assert_array(_map()).contains(["PrinterB", "TerminalB"])
	assert_bool(_session.reached_devices().has(Device.of(_b["PrinterB"]))).is_false()
	assert_bool(_session.reached_devices().has(Device.of(_b["TerminalB"]))).is_false()
	# The switch going down cuts the reach, not the map.
	Powered.of(_b["SwitchB"]).on = false
	_session.refresh()
	assert_array(_map()).contains_exactly_in_any_order(ANNEX)
	assert_bool(_session.reached_devices().has(Device.of(_b["PcB"]))).is_false()


func test_wireless_devices_are_drawn_only_on_their_own_access_points_network() -> void:
	# A's security subnet seen first (Rtr01 hacked): CAM-YARD is remembered.
	DeviceAccounts.of(_a["Rtr01"]).grant(_user, "admin")
	await _plug(_a["Jack"], AT_A)
	_session.refresh()
	await Wait.frames(get_tree(), 15)
	assert_array(_map()).contains(["ApYard", "CamYard", "LaserRoof"])
	assert_bool(_map().has("CamAnnex")).is_false()
	# On B's jack: CAM-ANNEX on B's access point is drawn, CAM-YARD is not.
	await _plug(_b["JackB"], AT_B)
	assert_array(_map()).contains(["ApAnnex", "CamAnnex"])
	assert_bool(_map().has("CamYard")).is_false()
	assert_bool(_map().has("ApYard")).is_false()
	# Joined to AP-ANNEX over Wi-Fi: the same annex map.
	_session.unplug()
	AccessPoint.of(_b["ApAnnex"]).grant_key(_user)
	_user.global_position = ORIGIN + NEAR_AP_ANNEX
	assert_bool(_session.plug(Device.of(_b["ApAnnex"]), _stack)).is_true()
	assert_bool(_session.is_wireless()).is_true()
	assert_array(_map()).contains_exactly_in_any_order(ANNEX)


func test_a_subnet_behind_an_unhacked_router_stays_hidden_until_hacked() -> void:
	await _plug(_b["JackB"], AT_B)
	_session.unplug()
	await _plug(_a["Jack"], AT_A)
	assert_array(_map()).contains_exactly_in_any_order(LAB)
	assert_bool(_map().has("Console")).is_false()
	DeviceAccounts.of(_a["Rtr01"]).grant(_user, "admin")
	_session.refresh()
	await Wait.frames(get_tree(), 15)
	assert_array(_map()).contains(["SecuritySwitch", "Console", "Camera", "Alarm", "Rtr02", "ApYard"])
	assert_bool(_map().has("FileServer")).is_false()
	assert_bool(_map().has("PcB")).is_false()


func test_unplugged_the_map_is_empty() -> void:
	await _plug(_b["JackB"], AT_B)
	assert_array(_map()).is_not_empty()
	_session.unplug()
	assert_array(_map()).is_empty()
	# Remembered on the deck, drawn again once plugged in.
	assert_array(_stack.state[DeckSession.SEEN] as Array).is_not_empty()
