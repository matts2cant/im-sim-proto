extends GdUnitTestSuite
## Integration (ADR 0114, from the terminal's ADR 0080 / 0083): the computer in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout). The console is cabled through
## the switch to the camera, the turret, the alarm controller, the siren and the door; the datapad on
## the desk carries its login; its DeviceAccounts hold the account. Camera and turret start disabled
## so the player is never shot. Computer.devices() lists the security devices it controls with
## their kind, status words (DeviceStatus, from their components) and commands; the screen is in
## tests/ui/computer/.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## 1 m in front of the console.
const AT_CONSOLE := Vector3(-6, 0, -7)
const LISTED: Array[String] = ["Camera", "Turret", "Controller", "Siren", "Door"]

var _show: Showcase
var _screen: ComputerScreen


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Camera")
	await _show.command(Device.DISABLE, "Turret")
	_screen = ComputerScreen.of(_show.player)
	await _show.place_player(AT_CONSOLE)
	EventLog.clear()


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.close()
	StimulusSystem.clear()


func test_a_login_goes_through_the_accounts_and_opens_a_session() -> void:
	var computer := _show.computer()
	assert_bool(computer.log_in("jmercer", "hunter2", _show.player)).is_false()
	assert_bool(computer.is_logged_in()).is_false()
	assert_bool(EventLog.find(&"computer.login")[0].data["ok"]).is_false()
	# User names ignore case and spaces; the session is the account's own name.
	assert_bool(computer.log_in(" JMercer ", "falcon7", _show.player)).is_true()
	assert_str(computer.session_user).is_equal("jmercer")
	assert_str(computer.access_level("jmercer")).is_equal("user")
	assert_array(computer.device_status()).contains_exactly(["logged in"])
	# Saved and loaded with the level.
	assert_dict(computer.save_state()).is_equal({"session_user": "jmercer"})
	computer.log_out()
	assert_bool(computer.is_logged_in()).is_false()
	computer.load_state({"session_user": "jmercer"})
	assert_bool(computer.is_logged_in()).is_true()


func test_a_wrong_login_beeps_without_a_noise_stimulus() -> void:
	_show.computer().log_in("jmercer", "hunter2", _show.player)
	await _show.frames(2)
	var noises := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise" and entry.source == "Console"
	)
	assert_array(noises).is_empty()
	assert_bool((_show.node("Console").get_node("Sound") as AudioStreamPlayer3D).stream != null).is_true()


func test_known_logins_come_from_the_personal_log_by_the_computers_code_id() -> void:
	var computer := _show.computer()
	assert_array(computer.known_logins(_show.player)).is_empty()
	_read_datapad()
	var known := computer.known_logins(_show.player)
	assert_int(known.size()).is_equal(1)
	assert_str(known[0].user).is_equal("jmercer")
	assert_str(known[0].password).is_equal("falcon7")
	assert_str(known[0].source).is_equal("Security login")
	# A second account learned elsewhere is offered too; the same user learned again replaces it.
	var log_book := PersonalLog.of(_show.player)
	log_book.add(LogEntry.make(&"other", "Other note", "", "Datapad", {&"showcase_console": "admin:root"}))
	log_book.add(LogEntry.make(&"newer", "Newer note", "", "Datapad", {&"showcase_console": "jmercer:eagle8"}))
	log_book.add(LogEntry.make(&"keypad", "Keypad", "", "Datapad", {&"another_device": "x:y"}))
	var users: Array[String] = []
	for login in computer.known_logins(_show.player):
		users.append("%s/%s/%s" % [login.user, login.password, login.source])
	assert_array(users).contains_exactly(["jmercer/eagle8/Newer note", "admin/root/Other note"])


func test_devices_are_the_controlled_security_devices_with_kinds_views_and_commands() -> void:
	var rows := _show.computer().devices()
	assert_array(_names(rows)).contains_exactly_in_any_order(LISTED)
	# The switch has no kind (not a security device); the computer never lists itself.
	assert_str(_row("Camera").kind.name).is_equal("Camera")
	assert_str(_row("Controller").kind.group).is_equal("Alarm")
	assert_str(_row("Door").kind.group).is_equal("Doors")
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


func test_statuses_come_from_the_devices_components() -> void:
	assert_array(_status("Camera")).contains_exactly(["online", "disabled"])
	assert_array(_status("Turret")).contains_exactly(["online", "disabled", "targets intruders"])
	assert_array(_status("Controller")).contains_exactly(["online", "armed", "silent"])
	assert_array(_status("Siren")).contains_exactly(["online", "silent"])
	assert_array(_status("Door")).contains_exactly_in_any_order(["online", "closed", "unlocked"])
	var computer := _show.computer()
	computer.send(Device.ENABLE, _show.device("Camera"))
	computer.send(Device.TEST, _show.device("Siren"))
	computer.send(Device.TARGET_GUARDS, _show.device("Turret"))
	computer.send(Device.LOCK, _show.device("Door"))
	computer.send(Device.OPEN, _show.device("Door"))
	computer.send(Device.DISARM, _show.device("Controller"))
	await _show.frames(3)
	assert_array(_status("Camera")).contains_exactly(["online", "enabled", "sweeping"])
	assert_array(_status("Siren")).contains_exactly(["online", "ringing"])
	assert_array(_status("Turret")).contains_exactly(["online", "disabled", "targets guards"])
	assert_array(_status("Door")).contains_exactly_in_any_order(["online", "open", "locked"])
	assert_array(_status("Controller")).contains_exactly(["online", "disarmed", "silent"])


func test_a_cut_switch_or_a_broken_device_is_offline_never_broken() -> void:
	# Broken (shot): offline, no commands; the rest still online.
	Breakable.of(_show.node("Camera")).take_damage(&"damage.ballistic", 100.0)
	await _show.frames(2)
	assert_array(_status("Camera")).contains_exactly(["offline"])
	assert_array(_row("Camera").commands).is_empty()
	assert_bool(_row("Siren").online).is_true()
	# The switch unpowered: everything behind it is offline but still listed (its cables intact).
	Powered.of(_show.node("Switch")).on = false
	await _show.frames(2)
	var rows := _show.computer().devices()
	assert_array(_names(rows)).contains_exactly_in_any_order(LISTED)
	for row in rows:
		assert_array(Array(row.status)).override_failure_message(row.name).contains_exactly(["offline"])
		assert_array(row.commands).override_failure_message(row.name).is_empty()
	assert_bool(_show.computer().send(Device.OPEN, _show.device("Door"))).is_false()
	Powered.of(_show.node("Switch")).on = true
	await _show.frames(2)
	assert_bool(_row("Door").online).is_true()


func test_a_cabled_door_opens_from_the_computer_with_no_door_code() -> void:
	var door := Usable.of(_show.node("Door")) as Door
	assert_bool(_show.computer().send(Device.OPEN, _show.device("Door"), _show.player)).is_true()
	await _show.seconds(1.0)
	assert_bool(door.is_open()).is_true()
	assert_bool(EventLog.find(&"door.command")[0].data["done"]).is_true()
	assert_str(EventLog.find(&"device.command")[0].data["by"]).is_equal("Player")
	# Locked from the computer, then closed: still openable remotely (an authorised open).
	_show.computer().send(Device.LOCK, _show.device("Door"))
	_show.computer().send(Device.CLOSE, _show.device("Door"))
	await _show.seconds(1.0)
	assert_bool(door.is_open()).is_false()
	assert_bool(door.is_locked()).is_true()


func test_a_dead_computer_does_nothing_and_lists_nothing() -> void:
	var use := Usable.of(_show.node("Console"))
	assert_object(use).is_instanceof(ComputerUse)
	assert_str(use.target_name()).is_equal("security console")
	assert_bool(use.available(_show.player)).is_true()
	Powered.of(_show.node("Console")).on = false
	await _show.frames(2)
	assert_bool(use.available(_show.player)).is_false()
	assert_bool(use.use(_show.player)).is_false()
	assert_bool(_screen.is_open()).is_false()
	assert_array(_show.computer().devices()).is_empty()


func test_a_user_without_a_screen_cannot_use_it() -> void:
	var stand_in := Fixtures.entity(_show.scene, "Visitor", AT_CONSOLE, [])
	assert_bool(_show.computer().use_by(stand_in)).is_false()
	assert_bool(Usable.of(_show.node("Console")).use(stand_in)).is_false()


func _read_datapad() -> void:
	Usable.of(_show.node("Datapad")).use(_show.player)
	(_show.player.get_node("ReadingOverlay") as ReadingOverlay).close()


func _names(rows: Array[Computer.DeviceRow]) -> Array[String]:
	var names: Array[String] = []
	for row in rows:
		names.append(row.name)
	return names


func _row(device_name: String) -> Computer.DeviceRow:
	for row in _show.computer().devices():
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
			labels.append(_show.computer().config.label_for(command))
	return labels
