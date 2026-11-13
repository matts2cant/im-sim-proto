extends GdUnitTestSuite
## Integration (ADR 0114): the Halcyon OS overlay (ComputerScreen) on the security showcase's console
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout; camera and turret start
## disabled). Login: fields, an error line, "Fill in" for each login the PersonalLog knows for this
## computer only, Enter logs in. Desktop: the dock's Mail and Files read into the PersonalLog. The
## overlay rules: the world keeps running, the player's input is off, Esc or ✕ leaves and never
## also opens the game menu, E never leaves, death or knockout closes it, walking away closes a
## bare-handed session. Remote desktops (open_desktop(..., true)): "Remote desktop", "Back to the
## map" closes and emits `desktop_closed`, walking away does not close it.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
## 1 m in front of the console.
const AT_CONSOLE := Vector3(-6, 0, -7)

var _show: Showcase
var _screen: ComputerScreen
var _computer: Computer


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_show = Showcase.new()
	await _show.setup(scene_runner(Showcase.SHOWCASE))
	await _show.command(Device.DISABLE, "Camera")
	await _show.command(Device.DISABLE, "Turret")
	_screen = ComputerScreen.of(_show.player)
	_computer = _show.computer()
	await _show.place_player(AT_CONSOLE)
	EventLog.clear()


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.close()
	PauseScreens.reset(get_tree())
	StimulusSystem.clear()


func test_fill_in_offers_this_computers_known_logins_and_enter_logs_in() -> void:
	# Another device's login and a keypad code are known too: never offered here.
	PersonalLog.of(_show.player).add(
		LogEntry.make(&"elsewhere", "Elsewhere", "", "Datapad", {&"other_pc": "kbrandt:ferry19", &"door": "1234"})
	)
	_read_datapad()
	assert_bool(Usable.of(_show.node("Console")).use(_show.player)).is_true()
	assert_bool(_screen.is_open()).is_true()
	assert_bool(_screen.desktop_shown()).is_false()
	assert_array(_screen.known_users()).contains_exactly(["jmercer"])
	assert_int(_screen.fill_buttons().size()).is_equal(1)
	assert_str(_texts()).contains("jmercer  · from Security login")
	_screen.fill_buttons()[0].pressed.emit()
	assert_str(_screen.user_field.text).is_equal("jmercer")
	assert_str(_screen.password_field.text).is_equal("falcon7")
	# Enter in the focused field logs in.
	_screen.user_field.grab_focus()
	await _key(KEY_ENTER)
	assert_bool(_computer.is_logged_in()).is_true()
	assert_bool(_screen.desktop_shown()).is_true()
	assert_str(_screen.title_label.text).is_equal("Halcyon OS")
	assert_str(_screen.meta_label.text).is_equal("SHOW-CONSOLE")
	assert_str(_screen.account_label.text).is_equal("jmercer · user")


func test_without_a_known_login_it_says_so_and_a_wrong_one_shows_the_error_line() -> void:
	_computer.use_by(_show.player)
	assert_array(_screen.known_users()).is_empty()
	assert_str(_texts()).contains(ComputerScreen.NO_KNOWN)
	_screen.user_field.text = "jmercer"
	_screen.password_field.text = "hunter2"
	_screen.password_field.grab_focus()
	await _key(KEY_ENTER)
	assert_bool(_computer.is_logged_in()).is_false()
	assert_str(_screen.error_label.text).is_equal(ComputerScreen.WRONG_LOGIN)
	assert_str(_screen.password_field.text).is_empty()
	# Right this time, by the button; Log out goes back to the login.
	_screen.password_field.text = "falcon7"
	_screen.login_button.pressed.emit()
	assert_bool(_screen.desktop_shown()).is_true()
	assert_str(_screen.error_label.text).is_empty()
	_screen.logout_button.pressed.emit()
	assert_bool(_computer.is_logged_in()).is_false()
	assert_bool(_screen.desktop_shown()).is_false()


func test_an_open_session_opens_on_the_desktop() -> void:
	_computer.session_user = "jmercer"
	_computer.use_by(_show.player)
	assert_bool(_screen.desktop_shown()).is_true()
	assert_str(_screen.who_label.text).is_equal("jmercer\nuser")


func test_mail_and_files_are_read_into_the_journal() -> void:
	_computer.session_user = "jmercer"
	_computer.use_by(_show.player)
	var personal_log := PersonalLog.of(_show.player)
	_screen.dock_button(Computer.MAIL).pressed.emit()
	assert_array(_screen.mail_app.titles()).contains_exactly(["Night rounds"])
	# The first mail is shown, so read: in the Journal like a datapad, no reading overlay.
	assert_str(_screen.mail_app.from_label.text).is_equal("From J. Mercer")
	assert_bool(personal_log.has(&"showcase.console.mail_rounds")).is_true()
	assert_str(personal_log.entries()[0].source).is_equal("Mail")
	assert_bool((_show.player.get_node("ReadingOverlay") as ReadingOverlay).visible).is_false()
	_screen.dock_button(Computer.FILES).pressed.emit()
	assert_bool(_screen.files_app.is_visible_in_tree()).is_true()
	assert_bool(_screen.mail_app.is_visible_in_tree()).is_false()
	assert_array(_screen.files_app.titles()).contains_exactly(["notes.txt"])
	assert_bool(personal_log.has(&"showcase.console.file_notes")).is_true()
	assert_str(personal_log.entries()[0].source).is_equal("Files")
	assert_str(_screen.files_app.learned_label.text).is_equal(DocumentApp.NOTE_ONLY)


func test_the_dock_shows_only_the_apps_installed() -> void:
	# The console has Security installed: three apps, Security works.
	_computer.session_user = "jmercer"
	_computer.use_by(_show.player)
	assert_array(_dock()).is_equal(["Mail", "Files", "Security"])
	_screen.dock_button(Computer.SECURITY).pressed.emit()
	assert_bool(_screen.security_app.is_visible_in_tree()).is_true()
	assert_array(_screen.security_app.device_names()).is_not_empty()
	_screen.close()
	# The same computer without a list of apps: Mail and Files only, bare-handed and remote, and
	# asking for Security shows Mail.
	_computer.data = _computer.data.duplicate()
	_computer.data.apps = []
	assert_array(_computer.apps()).is_equal([Computer.MAIL, Computer.FILES])
	for remote: bool in [false, true]:
		_computer.open_desktop(_show.player, "jmercer", remote)
		assert_array(_dock()).is_equal(["Mail", "Files"])
		_screen.show_app(Computer.SECURITY)
		assert_str(String(_screen.app)).is_equal(String(Computer.MAIL))
		assert_bool(_screen.security_app.is_visible_in_tree()).is_false()
		_screen.close()


# The dock's visible app buttons.
func _dock() -> Array[String]:
	var names: Array[String] = []
	for button in _screen.dock_buttons:
		if button.visible:
			names.append(String(button.name))
	return names


func test_the_world_keeps_running_and_esc_leaves_without_the_game_menu() -> void:
	var runner := _show.runner
	_show.player.input_enabled = true
	_computer.use_by(_show.player)
	assert_bool(_show.scene.get_tree().paused).is_false()
	assert_bool(_show.player.accepts_input()).is_false()
	assert_bool((_show.player.get_node("Hud") as CanvasLayer).visible).is_false()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	var ticks := Engine.get_physics_frames()
	await _show.frames(3)
	assert_int(Engine.get_physics_frames()).is_greater(ticks)
	# E never leaves, also while typing; Esc does, every time, and the game menu stays shut.
	_screen.user_field.grab_focus()
	runner.simulate_action_pressed(&"use")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_true()
	runner.simulate_action_pressed(&"ui_cancel")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	assert_bool((_show.player.get_node("GameMenu") as GameMenu).is_open()).is_false()
	assert_bool(_show.player.accepts_input()).is_true()
	assert_bool((_show.player.get_node("Hud") as CanvasLayer).visible).is_true()
	# The ✕ leaves too; the hint names only Esc.
	_computer.use_by(_show.player)
	assert_str(_texts()).contains("Esc: leave")
	assert_str(_texts()).not_contains("E: leave")
	_screen.close_button.pressed.emit()
	assert_bool(_screen.is_open()).is_false()


func test_walking_away_closes_a_bare_handed_session() -> void:
	_computer.use_by(_show.player)
	await _show.place_player(Vector3(-6, 0, -3))
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()


func test_death_and_knockout_close_it_and_give_the_input_back() -> void:
	_show.player.input_enabled = true
	_computer.use_by(_show.player)
	_show.player.body.take_damage(&"damage.stun", 1000.0)
	await _show.frames(2)
	assert_bool(ActorState.can_act(_show.player)).is_false()
	assert_bool(_screen.is_open()).is_false()
	assert_bool(_show.player.accepts_input()).is_true()


func test_a_dead_computer_closes_its_screen() -> void:
	_computer.use_by(_show.player)
	Powered.of(_show.node("Console")).on = false
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()


func test_a_remote_desktop_shows_in_the_deck_and_back_to_the_map_closes_it() -> void:
	var closed: Array[bool] = []
	_computer.desktop_closed.connect(func() -> void: closed.append(true))
	_computer.open_desktop(_show.player, "jmercer", true)
	assert_bool(_screen.is_remote()).is_true()
	assert_bool(_screen.desktop_shown()).is_true()
	assert_str(_screen.title_label.text).is_equal("Remote desktop")
	assert_str(_screen.meta_label.text).is_equal("Halcyon OS · SHOW-CONSOLE")
	assert_bool(_screen.back_button.is_visible_in_tree()).is_true()
	assert_bool(_screen.close_button.is_visible_in_tree()).is_false()
	assert_bool(_screen.logout_button.is_visible_in_tree()).is_false()
	assert_int(_screen.layer).is_equal(ComputerScreen.REMOTE_LAYER)
	assert_float(_screen.panel.anchor_left).is_equal_approx(ComputerScreen.REMOTE_AREA.position.x, 0.0001)
	# It never opens the computer's own session; walking away does not close it (the deck's tether).
	assert_bool(_computer.is_logged_in()).is_false()
	await _show.place_player(Vector3(-6, 0, 4))
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_true()
	assert_array(EventLog.find(&"computer.opened")).has_size(1)
	assert_bool(EventLog.find(&"computer.opened")[0].data["remote"]).is_true()
	_screen.back_button.pressed.emit()
	assert_bool(_screen.is_open()).is_false()
	assert_array(closed).has_size(1)
	# Bare-handed: no desktop_closed; open_desktop(..., false) opens the local session.
	await _show.place_player(AT_CONSOLE)
	_computer.open_desktop(_show.player, "jmercer", false)
	assert_bool(_screen.is_remote()).is_false()
	assert_bool(_computer.is_logged_in()).is_true()
	assert_int(_screen.layer).is_equal(ComputerScreen.LAYER)
	_screen.close()
	assert_array(closed).has_size(1)


func test_esc_in_a_remote_desktop_goes_back_to_the_map() -> void:
	var closed: Array[bool] = []
	_computer.desktop_closed.connect(func() -> void: closed.append(true))
	_computer.open_desktop(_show.player, "jmercer", true)
	_show.runner.simulate_action_pressed(&"ui_cancel")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	assert_array(closed).has_size(1)
	assert_bool((_show.player.get_node("GameMenu") as GameMenu).is_open()).is_false()


func test_the_title_bar_has_a_slot_for_trace_bars() -> void:
	var opened: Array[bool] = []
	_screen.opened.connect(func(_computer_opened: Computer, remote: bool) -> void: opened.append(remote))
	_computer.use_by(_show.player)
	assert_array(opened).contains_exactly([false])
	var bar := Label.new()
	bar.text = "Sentry tracer 12 %"
	_screen.add_trace_bar(bar)
	assert_bool(bar.is_visible_in_tree()).is_true()
	assert_object(bar.get_parent()).is_same(_screen.trace_bars())
	_screen.clear_trace_bars()
	await _show.frames(1)
	assert_int(_screen.trace_bars().get_child_count()).is_equal(0)


# Every label's text on the screen.
func _texts() -> String:
	var texts := ""
	for node in _screen.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree():
			texts += (node as Label).text + "\n"
	return texts


func _read_datapad() -> void:
	Usable.of(_show.node("Datapad")).use(_show.player)
	(_show.player.get_node("ReadingOverlay") as ReadingOverlay).close()


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		get_viewport().push_input(key)
	await _show.frames(1)
