extends GdUnitTestSuite
## Network lab (gallery room 8, design/levels/hub-and-gallery.md "8 Network lab"), the Security and
## server stations with the real Player in the room fixture (fixtures/lab_player.tscn): the console
## (its login learned from PC 2's mail, Fill in) lists only the camera and the closet door, which
## trust it, and its Security app disables the camera and opens the door to the closet's biocells;
## the breaker beside the closet's room switch cuts only that switch (the camera and the door
## offline, the fail-secure door shut; the console and RTR-02 on the same subnet stay reachable);
## from the wall jack the deck's Icebreaker cracks RTR-01 (Weak, Untrained), the console's file gives
## RTR-02's login, and the file server
## behind RTR-02 appears, is cracked and opens remotely on its one file.

const Helpers := preload("res://tests/levels/gallery/network_lab/network_lab_helpers.gd")

var _lab: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_lab = Helpers.new()
	await _lab.setup(scene_runner(Helpers.FIXTURE))


func after_test() -> void:
	var session := DeckSession.of(_lab.player)
	if session != null:
		session.unplug()
	var screen := ComputerScreen.of(_lab.player)
	if screen != null and screen.is_open():
		screen.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


# Reads PC 2's mail with the console's login into the player's log (as PC 2's desktop would).
func _learn_console_login() -> void:
	var pc2 := _lab.computer("Devices/OfficePc2")
	pc2.read(pc2.data.mail[0], _lab.player, "Mail")


# Uses the console bare-handed with the login the log knows, on its Security app.
func _console_desktop() -> ComputerScreen:
	await _lab.stand(Helpers.AT_CONSOLE, _lab.node("Devices/Console").position)
	_lab.computer("Devices/Console").use_by(_lab.player)
	var screen := ComputerScreen.of(_lab.player)
	screen.fill_in(0)
	screen.login_button.pressed.emit()
	screen.show_app(ComputerScreen.App.SECURITY)
	return screen


func test_the_console_disables_the_camera_and_opens_the_closet_that_trust_it() -> void:
	_learn_console_login()
	var screen := await _console_desktop()
	assert_bool(screen.desktop_shown()).is_true()
	var app := screen.security_app
	assert_array(app.device_names()).contains_exactly_in_any_order(["CAM-CLOSET", "DOOR-CLOSET"])
	assert_bool(app.select("CAM-CLOSET")).is_true()
	app.action_button("Disable").pressed.emit()
	await _lab.driver.frames(3)
	assert_bool(SecurityCamera.of(_lab.node("Devices/ClosetCamera")).disabled).is_true()
	assert_bool(app.select("DOOR-CLOSET")).is_true()
	app.action_button("Open").pressed.emit()
	var door := Door.of(_lab.node("Doors/ClosetDoor"))
	for i in 90:
		if door.is_open() and not door.is_moving():
			break
		await _lab.driver.frames(1)
	assert_bool(door.is_open()).is_true()
	screen.close()
	# Into the closet: the biocells on its shelf are within reach.
	await _lab.stand(Helpers.IN_CLOSET, _lab.node("Items/Biocell1").position)
	assert_bool(_lab.player.inventory.pick_up(ItemPickup.of(_lab.node("Items/Biocell1")))).is_true()
	# The office PCs reach them but are not trusted.
	var pc1 := _lab.computer("Devices/OfficePc1")
	assert_array(pc1.devices()).is_empty()
	assert_bool(pc1.send(Device.CLOSE, _lab.device("Doors/ClosetDoor"))).is_false()


func test_the_breaker_cuts_only_the_closet_switch_and_the_fail_secure_door_stays_shut() -> void:
	var console := _lab.computer("Devices/Console")
	assert_bool(console.log_in("ops", "relay52")).is_true()
	var breaker := _lab.node("Devices/Breaker").get_node("CircuitBreaker") as CircuitBreaker
	await _lab.stand(Helpers.AT_BREAKER, _lab.node("Devices/Breaker").position)
	assert_bool(breaker.use(_lab.player)).is_true()
	await _lab.driver.frames(2)
	assert_bool(_lab.device("Devices/ClosetSwitch").is_up()).is_false()
	# The closet's camera and door go offline; the rest of the Security subnet stays reachable.
	for row in console.devices():
		assert_bool(row.online).override_failure_message(row.name + " still online").is_false()
	assert_bool(console.send(Device.OPEN, _lab.device("Doors/ClosetDoor"))).is_false()
	await _lab.driver.frames(3)
	assert_bool(Door.of(_lab.node("Doors/ClosetDoor")).is_locked()).is_true()
	assert_bool(console.device.reaches(_lab.node("Devices/Rtr02"))).is_true()
	assert_bool(console.device.reaches(_lab.node("Devices/SecuritySwitch"))).is_true()
	# The deck on the jack, RTR-01 hacked: the console is online, the closet's devices are not.
	assert_bool(await _lab.take_deck()).is_true()
	await _lab.click(Helpers.AT_JACK, "Devices/Jack")
	var session := DeckSession.of(_lab.player)
	DeviceAccounts.of(_lab.node("Devices/Rtr01")).grant(_lab.player, "admin")
	session.refresh()
	assert_bool(session.is_online(_lab.device("Devices/Console"))).is_true()
	assert_bool(session.is_online(_lab.device("Devices/Rtr02"))).is_true()
	assert_bool(session.is_online(_lab.device("Devices/ClosetCamera"))).is_false()
	# The breaker back on: online again.
	breaker.use(_lab.player)
	await _lab.driver.frames(2)
	session.refresh()
	assert_bool(session.is_online(_lab.device("Devices/ClosetCamera"))).is_true()
	assert_bool(console.send(Device.OPEN, _lab.device("Doors/ClosetDoor"))).is_true()


func test_cracking_rtr01_then_logging_in_on_rtr02_reveals_the_file_server() -> void:
	assert_bool(await _lab.take_deck()).is_true()
	await _lab.click(Helpers.AT_JACK, "Devices/Jack")
	await _lab.seconds(2.2)
	var screen := DeckScreen.of(_lab.player)
	screen.refresh()
	assert_bool(screen.graph.node_names().has("SEC-CONSOLE")).is_false()
	# RTR-01: the Icebreaker cracks its Weak admin password Untrained (10 s, +40 % trace).
	assert_bool(screen.graph.select("RTR-01")).is_true()
	_press(screen, "Icebreaker")
	await _lab.seconds(10.2)
	assert_bool(IcebreakerTool.of(_lab.player).job.is_done()).is_true()
	assert_bool(DeviceAccounts.of(_lab.node("Devices/Rtr01")).has_access(_lab.player)).is_true()
	_press(screen, "Back to the map")
	await _lab.seconds(2.2)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains(
		["SW-SECURITY", "SEC-CONSOLE", "CAM-CLOSET", "DOOR-CLOSET", "RTR-02"]
	)
	assert_bool(screen.graph.node_names().has("FILE-SERVER")).is_false()
	assert_array(EventLog.find(&"tracer.full")).is_empty()
	# RTR-02: the console's file teaches its login; the Map logs in with it.
	var console := _lab.computer("Devices/Console")
	console.read(console.data.files[0], _lab.player, "Files")
	screen.refresh()
	assert_bool(screen.graph.select("RTR-02")).is_true()
	_press(screen, "Log in (from rtr02.txt)")
	await _lab.seconds(2.2)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains(["SW-SERVERS", "FILE-SERVER"])
	# The file server (Weak; Master for a 3 s test) cracked, then its desktop opened from the Map.
	_lab.player.skills.set_tier(&"computer", 3)
	assert_bool(screen.graph.select("FILE-SERVER")).is_true()
	_press(screen, "Icebreaker")
	await _lab.seconds(3.2)
	_press(screen, "Back to the map")
	screen.refresh()
	assert_bool(screen.graph.select("FILE-SERVER")).is_true()
	_press(screen, "Open its desktop (remote)")
	var desktop := ComputerScreen.of(_lab.player)
	assert_bool(desktop.is_remote()).is_true()
	desktop.dock_buttons[ComputerScreen.App.FILES].pressed.emit()
	assert_array(desktop.files_app.titles()).contains_exactly(["well_done.txt"])


# Presses the deck screen's open menu button `text`, else any button `text` on it.
func _press(screen: DeckScreen, text: String) -> void:
	var button := screen.menu_button(text)
	if button == null:
		button = screen.find_button(text)
	assert_object(button).override_failure_message("no button '%s' in %s" % [text, screen.menu_texts()]).is_not_null()
	if button != null:
		button.pressed.emit()
