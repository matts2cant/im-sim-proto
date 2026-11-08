extends GdUnitTestSuite
## Integration (ADR 0080, ADR 0083): the terminal in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout). The terminal is cabled through
## the switch to the camera, the turret, the alarm controller, the siren and the door; the datapad on
## the desk carries its credentials. Camera and turret start disabled so the player is never shot.
## Terminal.devices() is the physical network with each device's status words (DeviceStatus, from
## its components); the screen's tabs are in tests/ui/terminal/terminal_screen_test.gd.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## 1 m in front of the terminal.
const AT_TERMINAL := Vector3(-6, 0, -7)
const NETWORK: Array[String] = ["Terminal", "Switch", "Camera", "Turret", "Controller", "Siren", "Door"]

var _show: Showcase
var _screen: TerminalScreen


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Camera")
	await _show.command(Device.DISABLE, "Turret")
	_screen = TerminalScreen.of(_show.player)
	await _show.place_player(AT_TERMINAL)
	EventLog.clear()


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.close()
	StimulusSystem.clear()


func test_known_credentials_from_the_datapad_log_in() -> void:
	_read_datapad()
	assert_bool(_show.terminal().use(_show.player)).is_true()
	assert_bool(_screen.is_open()).is_true()
	# The game keeps running and the player's input is off while the screen is open.
	assert_bool(_show.scene.get_tree().paused).is_false()
	assert_bool(_show.player.input_enabled).is_false()
	assert_bool(_screen.known_label.is_visible_in_tree()).is_true()
	assert_str(_screen.known_label.text).is_equal("Known: jmercer from 'Security login'")
	_screen.fill_button.pressed.emit()
	assert_str(_screen.user_field.text).is_equal("jmercer")
	assert_str(_screen.password_field.text).is_equal("falcon7")
	_screen.login_button.pressed.emit()
	assert_bool(_show.terminal().logged_in).is_true()
	assert_bool(EventLog.find(&"terminal.login")[0].data["ok"]).is_true()
	assert_array(_screen.graph.node_names()).contains_exactly_in_any_order(NETWORK)


func test_without_the_datapad_there_is_no_reminder() -> void:
	_show.terminal().use(_show.player)
	assert_bool(_screen.known_label.is_visible_in_tree()).is_false()


func test_a_wrong_password_is_refused_with_a_beep() -> void:
	_show.terminal().use(_show.player)
	_screen.user_field.text = "jmercer"
	_screen.password_field.text = "hunter2"
	_screen.login_button.pressed.emit()
	assert_bool(_show.terminal().logged_in).is_false()
	assert_str(_screen.message_label.text).is_equal("Wrong password.")
	await _show.frames(2)
	var beeps := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise" and entry.source == "Terminal"
	)
	assert_array(beeps).has_size(1)
	assert_float(float(beeps[0].data["intensity"])).is_equal(4.0)


func test_devices_are_the_cabled_network_with_views_and_commands() -> void:
	var rows := _show.terminal().devices()
	assert_array(_names(rows)).contains_exactly_in_any_order(NETWORK)
	# Its own row first; every cable once (all on the switch).
	assert_bool(rows[0].is_self).is_true()
	assert_str(rows[0].name).is_equal("Terminal")
	var cables := Terminal.cables(rows)
	assert_int(cables.size()).is_equal(6)
	for cable in cables:
		assert_bool(rows[cable.x].name == "Switch" or rows[cable.y].name == "Switch").is_true()
	# A view is a property: whatever offers one (the camera's and the turret's eyes).
	var with_view: Array[String] = []
	for row in rows:
		if row.has_view:
			with_view.append(row.name)
	assert_array(with_view).contains_exactly_in_any_order(["Camera", "Turret"])
	# Each device offers the commands its receptrons accept, in the table's order.
	assert_array(_labels("Camera")).contains_exactly(
		["Enable", "Disable", "Stop sweep", "Resume sweep", "Pan left", "Pan right"]
	)
	assert_array(_labels("Turret")).contains_exactly(
		["Enable", "Disable", "Target intruders", "Target guards", "Target everyone"]
	)
	assert_array(_labels("Siren")).contains_exactly(["Ring", "Test", "Silence"])
	assert_array(_labels("Door")).contains_exactly(["Open", "Close", "Lock", "Unlock"])
	assert_array(_labels("Switch")).is_empty()


func test_statuses_come_from_the_devices_components() -> void:
	_log_in()
	assert_array(_status("Terminal")).contains_exactly(["online", "logged in"])
	assert_array(_status("Switch")).contains_exactly(["online"])
	assert_array(_status("Camera")).contains_exactly(["online", "disabled"])
	assert_array(_status("Turret")).contains_exactly(["online", "disabled", "targets intruders"])
	assert_array(_status("Controller")).contains_exactly(["online", "armed", "silent"])
	assert_array(_status("Siren")).contains_exactly(["online", "silent"])
	assert_array(_status("Door")).contains_exactly_in_any_order(["online", "closed", "unlocked"])
	var terminal := _show.terminal()
	terminal.send(Device.ENABLE, _show.device("Camera"))
	terminal.send(Device.TEST, _show.device("Siren"))
	terminal.send(Device.TARGET_GUARDS, _show.device("Turret"))
	terminal.send(Device.LOCK, _show.device("Door"))
	terminal.send(Device.OPEN, _show.device("Door"))
	terminal.send(Device.DISARM, _show.device("Controller"))
	await _show.frames(3)
	assert_array(_status("Camera")).contains_exactly(["online", "enabled", "sweeping"])
	assert_array(_status("Siren")).contains_exactly(["online", "ringing"])
	assert_array(_status("Turret")).contains_exactly(["online", "disabled", "targets guards"])
	assert_array(_status("Door")).contains_exactly_in_any_order(["online", "open", "locked"])
	assert_array(_status("Controller")).contains_exactly(["online", "disarmed", "silent"])
	terminal.send(Device.STOP_SWEEP, _show.device("Camera"))
	await _show.frames(3)
	assert_array(_status("Camera")).contains_exactly(["online", "enabled", "holding"])


func test_a_cut_switch_or_a_broken_device_is_offline_never_broken() -> void:
	# Broken (shot): offline, no commands; the rest still online.
	Breakable.of(_show.node("Camera")).take_damage(&"damage.ballistic", 100.0)
	await _show.frames(2)
	assert_array(_status("Camera")).contains_exactly(["offline"])
	assert_array(_row("Camera").commands).is_empty()
	assert_bool(_row("Siren").online).is_true()
	# The switch unpowered: everything behind it is offline (still on the network, its cables
	# intact), the terminal itself still online.
	Powered.of(_show.node("Switch")).on = false
	await _show.frames(2)
	var rows := _show.terminal().devices()
	assert_array(_names(rows)).contains_exactly_in_any_order(NETWORK)
	assert_int(Terminal.cables(rows).size()).is_equal(6)
	for row in rows:
		if row.is_self:
			assert_bool(row.online).is_true()
			continue
		assert_array(Array(row.status)).override_failure_message(row.name).contains_exactly(["offline"])
		assert_array(row.commands).override_failure_message(row.name).is_empty()
	assert_bool(_show.terminal().send(Device.OPEN, _show.device("Door"))).is_false()
	Powered.of(_show.node("Switch")).on = true
	await _show.frames(2)
	assert_bool(_row("Door").online).is_true()


func test_a_cabled_door_opens_from_the_terminal_with_no_door_code() -> void:
	_log_in()
	var door := Usable.of(_show.node("Door")) as Door
	assert_bool(_show.terminal().send(Device.OPEN, _show.device("Door"))).is_true()
	await _show.seconds(1.0)
	assert_bool(door.is_open()).is_true()
	assert_bool(EventLog.find(&"door.command")[0].data["done"]).is_true()
	# Locked from the terminal, then closed: still openable remotely (an authorised open).
	_show.terminal().send(Device.LOCK, _show.device("Door"))
	_show.terminal().send(Device.CLOSE, _show.device("Door"))
	await _show.seconds(1.0)
	assert_bool(door.is_open()).is_false()
	assert_bool(door.is_locked()).is_true()


func test_it_closes_when_its_user_walks_away_or_the_terminal_dies() -> void:
	_show.terminal().use(_show.player)
	await _show.place_player(Vector3(-6, 0, -3))
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	await _show.place_player(AT_TERMINAL)
	_show.terminal().use(_show.player)
	Powered.of(_show.node("Terminal")).on = false
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	assert_bool(_show.terminal().use(_show.player)).is_false()
	assert_array(_show.terminal().devices()).is_empty()


func test_a_user_without_a_screen_cannot_use_it() -> void:
	var stand_in := Fixtures.entity(_show.scene, "Visitor", AT_TERMINAL, [])
	assert_bool(_show.terminal().use(stand_in)).is_false()


func _read_datapad() -> void:
	Usable.of(_show.node("Datapad")).use(_show.player)
	(_show.player.get_node("ReadingOverlay") as ReadingOverlay).close()


func _log_in() -> void:
	_show.terminal().use(_show.player)
	_screen.user_field.text = "jmercer"
	_screen.password_field.text = "falcon7"
	_screen.submit_login()
	assert_bool(_show.terminal().logged_in).is_true()


func _names(rows: Array[Terminal.Row]) -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		names.append(row.name)
	return names


func _row(device_name: String) -> Terminal.Row:
	for row in _show.terminal().devices():
		if row.name == device_name:
			return row
	return null


func _status(device_name: String) -> Array:
	var row := _row(device_name)
	return Array(row.status) if row != null else []


func _labels(device_name: String) -> Array[String]:
	var labels: Array[String] = []
	var row := _row(device_name)
	if row != null:
		for command in row.commands:
			labels.append(_show.terminal().config.label_for(command))
	return labels
