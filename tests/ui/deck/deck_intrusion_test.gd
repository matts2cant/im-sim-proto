extends GdUnitTestSuite
## Integration (ADR 0115, 0121): exploit items and the Firewall tool on the real Player in the lab
## fixture (fixtures/deck_lab.tscn), plugged into the wall jack. A device's menu offers "Use <kind>
## exploit (N left)" while the player carries an item of its kind and has no access: using it is
## instant, adds no trace, consumes one and gives admin (a router's subnets then scanned, the scan
## shown on the Map); another kind offers nothing; used up, the button is gone.
## A router the player is admin of offers "Firewall rules": the Firewall tool adds, edits, toggles,
## moves and deletes its rules, and a rule from "you" cuts the deck off a device behind it.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"

var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _session: DeckSession
var _screen: DeckScreen


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(LAB))
	_lab = _driver.runner.scene() as Lab
	_player = _driver.player
	_player.reload_on_reset = false
	_session = DeckSession.of(_player)
	_screen = DeckScreen.of(_player)
	await _driver.settle()
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	_player.load_state(PlayerDriver.state(Lab.ORIGIN + Lab.AT_JACK, 0.0))
	await _driver.frames(2)
	_session.plug_and_raise(_lab.device("Jack"))
	await _driver.frames(15)
	_screen.refresh()


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _press(text: String) -> void:
	var button := _screen.menu_button(text)
	if button == null:
		button = _screen.find_button(text)
	assert_object(button).override_failure_message("no button '%s' in %s" % [text, _screen.menu_texts()]).is_not_null()
	if button != null:
		button.pressed.emit()


func test_a_router_exploit_from_the_menu_gives_admin_and_scans_behind_it() -> void:
	_player.inventory.give(Net.exploit_item(&"router"), 1)
	_player.inventory.give(Net.exploit_item(&"camera"), 2)
	_screen.refresh()
	var sentry := _lab.node("Rtr01").get_node("Tracer") as Tracer
	var before := sentry.trace_of(_player)
	# A wrong kind offers nothing: the office PC has no camera or router kind.
	assert_bool(_screen.graph.select("OFFICE-PC")).is_true()
	for text in _screen.menu_texts():
		assert_bool(text.begins_with("Use ")).override_failure_message(text).is_false()
	assert_bool(_screen.graph.select("RTR-01")).is_true()
	assert_array(_screen.menu_texts()).contains(["Use router exploit (1 left)", IntrusionMenu.EXPLOIT_NOTE])
	_press("Use router exploit (1 left)")
	var router := _lab.device("Rtr01")
	assert_bool(router.is_admin(_player)).is_true()
	assert_int(ExploitItems.count(_player, &"router")).is_equal(0)
	# Instant, no trace of its own (only the scan of the watched Security subnet behind it adds),
	# logged on the router with the deck's address.
	var scan := sentry.config.scan * Icebreaker.trace_mult(_player)
	assert_float(sentry.trace_of(_player) - before).is_equal_approx(scan, 0.01)
	var used := router.intrusion.device_log.of_kind(DeviceLog.EXPLOIT)
	assert_int(used.size()).is_equal(1)
	var line := "exploit 10.0.10.40 %s Router exploit" % NetworkSource.user_key(_player)
	assert_str(DeviceLog.line(used[0])).is_equal(line)
	# The subnet behind it is scanned, shown as the scan, then on the map.
	assert_bool(_session.scans.has(&"security")).is_true()
	_screen.refresh()
	assert_array(NetworkGraph.scanning_subnets(_screen.graph)).contains([&"security"])
	assert_bool(_screen.graph.node_names().has("CAM-GATE")).is_false()
	await _driver.frames(15)
	_screen.refresh()
	assert_array(_screen.graph.node_names()).contains(["CAM-GATE", "SEC-CONSOLE"])
	assert_array(NetworkGraph.scanning_subnets(_screen.graph)).is_empty()
	# Used up: the router offers no exploit any more, the Firewall instead; the camera offers its own.
	assert_bool(_screen.graph.select("RTR-01")).is_true()
	assert_array(_screen.menu_texts()).contains(["Firewall rules", "access: admin (exploit)"])
	assert_bool(_screen.menu_texts().has("Use router exploit (0 left)")).is_false()
	assert_bool(_screen.graph.select("CAM-GATE")).is_true()
	assert_array(_screen.menu_texts()).contains(["Use camera exploit (2 left)"])


func test_the_firewall_tool_edits_a_routers_rules() -> void:
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_session.refresh()
	await _driver.frames(15)
	_screen.refresh()
	assert_bool(_screen.graph.select("RTR-01")).is_true()
	_press("Firewall rules")
	assert_int(_screen.tool).is_equal(DeckScreen.Tool.FIREWALL)
	var view := _screen.firewall_view
	assert_array(view.texts()).contains(["Firewall · RTR-01", "Add a rule", "Move up", "Move down", "Delete"])
	view.add_rule()
	view.add_rule()
	assert_array(view.rule_lines()).is_equal(["1 any -> any ALLOW", "2 any -> any ALLOW"])
	var console := _lab.device("Console")
	assert_bool(_session.is_online(console)).is_true()
	assert_bool(view.choose(1, true, "you")).is_true()
	assert_bool(view.choose(1, false, "SEC-CONSOLE")).is_true()
	view.toggle(1)
	view.move_selected(-1)
	assert_array(view.rule_lines()).is_equal(["1 you -> SEC-CONSOLE DENY", "2 any -> any ALLOW"])
	assert_bool(_session.is_online(console)).is_false()
	assert_bool(_session.is_online(_lab.device("Camera"))).is_true()
	# Choices: subnets and devices on the map; "you" only as From.
	var to_labels: Array = view.endpoints(false).map(func(choice: Dictionary) -> String: return choice["label"])
	assert_array(to_labels).contains(["any", "OFFICE subnet", "SECURITY subnet", "SEC-CONSOLE"])
	assert_bool(to_labels.has("you")).is_false()
	view.select_rule(0)
	view.delete_selected()
	assert_array(view.rule_lines()).is_equal(["1 any -> any ALLOW"])
	assert_bool(_session.is_online(console)).is_true()
	assert_int(Router.of(_lab.node("Rtr01")).rules.size()).is_equal(1)
