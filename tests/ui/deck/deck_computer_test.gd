extends GdUnitTestSuite
## Integration across the M12a contract (ADR 0113 network and deck, ADR 0114 computers): the real
## Player in the deck lab (fixtures/deck_lab.tscn). A computer the user has an account on opens its
## desktop remotely from the deck's Map, over the deck's content area; its Security app commands a
## device that trusts it and shows only the commands that apply; Back to the map and Esc return to
## the Map. A failed bare-handed login raises the tracer watching that computer, whose bar shows in
## the computer overlay. A device that trusts another computer is not listed.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const Net := preload("res://tests/objects/network/network_fixtures.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _session: DeckSession
var _deck: DeckScreen
var _desktop: ComputerScreen


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_runner = scene_runner(LAB)
	_driver = PlayerDriver.new(_runner)
	_lab = _runner.scene() as Lab
	_player = _driver.player
	_player.reload_on_reset = false
	_session = DeckSession.of(_player)
	_deck = DeckScreen.of(_player)
	_desktop = ComputerScreen.of(_player)
	await _driver.settle()


func after_test() -> void:
	if is_instance_valid(_desktop):
		_desktop.close()
	if is_instance_valid(_session):
		_session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func _plug_with_access() -> void:
	_player.inventory.give(DECK, 1)
	var stack := _player.inventory.inventory.stacks_of(&"deck")[0]
	_player.inventory.hold(stack)
	_player.load_state(PlayerDriver.state(Lab.ORIGIN + Lab.AT_JACK, 0.0))
	await _driver.frames(2)
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	DeviceAccounts.of(_lab.node("Console")).grant(_player, "dmarsh")
	_session.plug_and_raise(_lab.device("Jack"))
	# Scans of the office and security subnets (2 s each, at once).
	await _driver.frames(130)
	_deck.refresh()


func test_a_remote_desktop_from_the_map_commands_a_trusting_device_and_goes_back() -> void:
	await _plug_with_access()
	assert_bool(_deck.graph.select("SEC-CONSOLE")).is_true()
	_deck.menu_button("Open its desktop (remote)").pressed.emit()
	assert_bool(_desktop.is_remote()).is_true()
	assert_object(_desktop.computer).is_same(Computer.of(_lab.node("Console")))
	assert_str(_desktop.account).is_equal("dmarsh")
	# Over the deck's content area.
	assert_bool(_desktop.remote_area.is_equal_approx(_deck.content_anchors())).is_true()
	# Inside the deck's 85 % panel, right of its tools column and under its bar.
	var area := _desktop.remote_area
	assert_float(area.position.x).is_greater(0.075)
	assert_float(area.position.y).is_greater(0.075)
	assert_float(area.end.x).is_less_equal(0.925 + 0.001)
	assert_float(area.end.y).is_less_equal(0.925 + 0.001)
	# The desktop really fits there (its title bar holds the compact trace bars).
	_deck.refresh_computer_traces()
	await _driver.frames(2)
	var shown := _desktop.panel.get_global_rect()
	var room := _deck.content_area.get_global_rect()
	assert_float(shown.end.x).override_failure_message("%s in %s" % [shown, room]).is_less_equal(room.end.x + 1.0)
	assert_float(shown.end.y).is_less_equal(room.end.y + 1.0)
	# The address in its title bar comes from the network layer.
	assert_str(Computer.of(_lab.node("Console")).address()).is_equal("10.0.20.5")
	# Its Security app lists the camera (it trusts the console) with only the commands that apply.
	_desktop.show_app(ComputerScreen.App.SECURITY)
	_desktop.security_app.refresh(true)
	assert_array(_desktop.security_app.device_names()).contains(["Camera"])
	assert_bool(_desktop.security_app.select("Camera")).is_true()
	assert_array(_desktop.security_app.action_labels()).is_equal(["Disable"])
	_desktop.security_app.action_button("Disable").pressed.emit()
	await _driver.frames(3)
	assert_bool(DeviceSwitch.of(_lab.node("Camera")).disabled).is_true()
	_desktop.security_app.refresh(true)
	_desktop.security_app.select("Camera")
	assert_array(_desktop.security_app.action_labels()).is_equal(["Enable"])
	# Back to the map: the desktop closes, the deck shows its Map again.
	_desktop.back_button.pressed.emit()
	assert_bool(_desktop.is_open()).is_false()
	assert_object(_session.remote).is_null()
	assert_bool(_deck.is_open()).is_true()
	assert_bool(_player.input_enabled).is_false()
	# Esc in a remote desktop goes back to the Map too, never further (the deck stays up, no menu).
	_deck.graph.select("SEC-CONSOLE")
	_deck.menu_button("Open its desktop (remote)").pressed.emit()
	assert_bool(_desktop.is_remote()).is_true()
	_runner.simulate_action_pressed(&"ui_cancel")
	await _driver.frames(2)
	assert_bool(_desktop.is_open()).is_false()
	assert_object(_session.remote).is_null()
	assert_bool(_deck.is_open()).is_true()
	assert_bool((_player.get_node("GameMenu") as GameMenu).is_open()).is_false()


func test_a_failed_bare_handed_login_raises_the_tracer_shown_in_the_computer_overlay() -> void:
	var console := Computer.of(_lab.node("Console"))
	_player.load_state(PlayerDriver.state(Lab.ORIGIN + Vector3(7, 0, 4.2), PI))
	await _driver.frames(2)
	assert_bool(console.use_by(_player)).is_true()
	_desktop.user_field.text = "dmarsh"
	_desktop.password_field.text = "anchor77"
	_desktop.submit_login()
	assert_float(_lab.tracer().trace_of(_player)).is_equal_approx(15.0, 0.001)
	var login := EventLog.find(&"network.login")
	assert_str(str(login[0].data["reason"])).is_equal("wrong")
	assert_str(str(login[0].data["address"])).is_equal("10.0.20.5")
	_deck.refresh_computer_traces()
	var bars := _desktop.trace_bars().get_children().filter(
		func(bar: Node) -> bool: return not bar.is_queued_for_deletion()
	)
	assert_int(bars.size()).is_equal(1)
	var texts: Array[String] = []
	for child in (bars[0] as Node).get_children():
		if child is Label:
			texts.append((child as Label).text)
	assert_array(texts).is_equal(["unknown tracer", "15 %"])
	# The right password logs in: no more trace.
	_desktop.password_field.text = "harbor77"
	_desktop.submit_login()
	assert_str(_desktop.account).is_equal("dmarsh")
	assert_float(_lab.tracer().trace_of(_player)).is_equal_approx(15.0, 0.001)


func test_a_device_that_trusts_another_computer_is_not_listed() -> void:
	var yard := Net.body_device(_lab, "YardCam", Lab.ORIGIN + Vector3(9, 2.5, 5), [])
	ActorState.set_tag(yard, &"object.camera", true)
	Net.link(_lab.node("SecuritySwitch"), yard)
	var yard_device := Device.of(yard)
	yard_device.trusted.append(yard_device.get_path_to(_lab.node("OfficePc")))
	var console := Computer.of(_lab.node("Console"))
	var names: Array[String] = []
	for row in console.devices():
		names.append(row.name)
	assert_array(names).contains(["Camera"])
	assert_bool(names.has("Yard Cam")).is_false()
	assert_bool(console.controls(yard_device)).is_false()
	assert_bool(Computer.of(_lab.node("OfficePc")).controls(yard_device)).is_true()
	# Its commands are refused from the console too.
	assert_bool(console.send(Device.DISABLE, yard_device)).is_false()
