extends GdUnitTestSuite
## Integration (ADR 0080): the terminal and its screen in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout). The terminal is cabled through
## the switch to the camera, the turret, the alarm controller and the siren; the datapad on the desk
## carries its credentials. Camera and turret start disabled so the player is never shot.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
## 1 m in front of the terminal.
const AT_TERMINAL := Vector3(-6, 0, -7)

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
	assert_array(_screen.listed_names()).contains_exactly_in_any_order(["Camera", "Turret", "Controller", "Siren"])


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


func test_buttons_send_commands_to_the_devices() -> void:
	_log_in()
	# Each device offers the commands its receptrons accept, in the table's order.
	var camera_labels := _labels("Camera")
	assert_array(camera_labels).contains_exactly(
		["Enable", "Disable", "Stop sweep", "Resume sweep", "Pan left", "Pan right"]
	)
	assert_array(_labels("Turret")).contains_exactly(
		["Enable", "Disable", "Target intruders", "Target guards", "Target everyone"]
	)
	assert_array(_labels("Siren")).contains_exactly(["Ring", "Test", "Silence"])
	var before := _show.camera().yaw()
	_screen.button("Camera", "Pan left").pressed.emit()
	await _show.frames(3)
	assert_float(_show.camera().yaw()).is_equal_approx(minf(before + 15.0, 40.0), 0.5)
	assert_bool(_show.camera().model.sweeping).is_false()
	_screen.button("Turret", "Target guards").pressed.emit()
	await _show.frames(3)
	assert_array(_show.turret().hostile_tags()).contains_exactly([&"actor.guard"])
	_screen.button("Siren", "Test").pressed.emit()
	await _show.frames(3)
	assert_array(EventLog.find(&"siren.started")).has_size(1)
	var sent := EventLog.find(&"device.command").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["from"] == "Terminal"
	)
	assert_int(sent.size()).is_equal(3)
	for entry: EventLogEntry in sent:
		assert_bool(entry.data["sent"]).is_true()


func test_unplugging_the_switch_empties_the_list_and_a_dead_device_shows_its_state() -> void:
	_log_in()
	# The camera unpowered: still listed (behind a live switch), its buttons off.
	Powered.of(_show.node("Camera")).on = false
	await _show.seconds(1.2)
	assert_str(_state_of("Camera")).is_equal("unpowered")
	assert_bool(_screen.button("Camera", "Pan left").disabled).is_true()
	# The switch off: nothing is reached; refreshed within a second.
	Powered.of(_show.node("Switch")).on = false
	await _show.seconds(1.2)
	assert_array(_screen.listed_names()).is_empty()
	Powered.of(_show.node("Switch")).on = true
	await _show.seconds(1.2)
	assert_array(_screen.listed_names()).contains_exactly_in_any_order(["Camera", "Turret", "Controller", "Siren"])


func test_esc_always_leaves_and_e_leaves_only_when_not_typing() -> void:
	var runner := _show.runner
	_show.terminal().use(_show.player)
	_screen.user_field.grab_focus()
	runner.simulate_action_pressed(&"use")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_true()
	runner.simulate_action_pressed(&"ui_cancel")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	# Input comes back as it was before (the helper turned it off).
	assert_bool(_show.player.input_enabled).is_false()
	_show.terminal().use(_show.player)
	_screen.user_field.release_focus()
	runner.simulate_action_pressed(&"use")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()


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


func _labels(device_name: String) -> Array[String]:
	var labels: Array[String] = []
	for row in _show.terminal().listing():
		if row.name == device_name:
			for command in row.commands:
				labels.append(_show.terminal().config.label_for(command))
	return labels


func _state_of(device_name: String) -> String:
	for child in _screen.device_list.get_children():
		var name_label := child.get_node_or_null(^"Name") as Label
		if name_label != null and name_label.text == device_name:
			return (child.get_node(^"State") as Label).text
	return ""
