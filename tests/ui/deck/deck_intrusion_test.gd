extends GdUnitTestSuite
## Integration (ADR 0115, 0116): the deck's Exploits and Firewall tools on the real Player in the lab
## fixture (fixtures/deck_lab.tscn), plugged into the wall jack. A scanned device's menu shows its
## software and "Exploits (n)" for the known exploits that match it, which opens the Exploits tool
## on it: Run on a match, "no match" otherwise, "patched on this subnet" once a seen run burned it.
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
var _x: Dictionary[String, Exploit]


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
	_x = Net.exploits()
	await _driver.settle()
	_session.config = _session.config.duplicate() as DeckConfig
	_session.config.scan_time = 0.1
	_session.config.exploit_time = 1.0
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


func test_the_menu_shows_software_and_opens_the_exploits_tool_on_a_match() -> void:
	Net.learn(_player, [_x["helix"], _x["halcyon"]])
	_screen.refresh()
	assert_bool(_screen.graph.select("OFFICE-PC")).is_true()
	assert_array(_screen.menu_texts()).contains(["Halcyon OS 4.2", "Exploits (1)"])
	_press("Exploits (1)")
	assert_int(_screen.tool).is_equal(DeckScreen.Tool.EXPLOITS)
	var view := _screen.exploits_view
	assert_object(ExploitTool.of(_player).target).is_same(_lab.device("OfficePc"))
	assert_array(view.texts()).contains(["Target: OFFICE-PC · Halcyon OS 4.2 · 10.0.10.12", "no match"])
	var run := view.run_button(&"halcyon_share_overflow")
	assert_object(run).is_not_null()
	assert_object(view.run_button(&"helix_default_login")).is_null()
	run.pressed.emit()
	assert_bool(ExploitTool.of(_player).is_running()).is_true()
	await _driver.frames(75)
	_screen.refresh()
	# Done: user access; the Sentry tracer watching the office saw it, so it is burned there.
	assert_bool(_lab.device("OfficePc").has_access(_player)).is_true()
	assert_array(view.texts()).contains(["patched on this subnet"])
	assert_object(view.run_button(&"halcyon_share_overflow")).is_null()


func test_the_firewall_tool_edits_a_routers_rules() -> void:
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_session.refresh()
	await _driver.frames(15)
	_screen.refresh()
	assert_bool(_screen.graph.select("RTR-01")).is_true()
	assert_array(_screen.menu_texts()).contains(["Norsk EdgeGuard 1.8"])
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
