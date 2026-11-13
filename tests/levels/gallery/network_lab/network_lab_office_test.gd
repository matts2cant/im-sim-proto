extends GdUnitTestSuite
## Network lab (gallery room 8, design/levels/hub-and-gallery.md "8 Network lab"), the Office
## stations with the real Player in the room fixture (fixtures/lab_player.tscn): the deck from the
## entrance table plugs into the wall jack with LMB and its Map shows the Office subnet and RTR-01
## only; the sticky note's login opens Office PC 1 bare-handed (Fill in) and its mail is an implicit
## clue (nothing learned); PC 2 takes the guess from that mail and the photo (a wrong guess adds the
## Sentry tracer's failed-login trace) and its mail teaches the security console's login.

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


func test_the_deck_from_the_table_plugs_into_the_jack_and_maps_the_office_and_rtr01() -> void:
	assert_bool(await _lab.take_deck()).is_true()
	await _lab.click(Helpers.AT_JACK, "Devices/Jack")
	var session := DeckSession.of(_lab.player)
	assert_bool(session.is_plugged()).is_true()
	assert_object(session.port).is_same(_lab.device("Devices/Jack"))
	assert_str(session.source.address).is_equal("10.0.10.40")
	# The office subnet (the jack's own) shows at once, without a scan or trace (ADR 0121).
	await _lab.seconds(0.1)
	var screen := DeckScreen.of(_lab.player)
	screen.refresh()
	assert_array(screen.graph.node_names()).contains_exactly_in_any_order(
		["OFFICE-JACK", "SW-OFFICE", "OFFICE-PC1", "OFFICE-PC2", "RTR-01"]
	)
	assert_float(_lab.tracer().trace_of(_lab.player)).is_equal(0.0)


func test_the_sticky_note_opens_pc1_and_its_mail_is_an_implicit_clue() -> void:
	var pc1 := _lab.computer("Devices/OfficePc1")
	await _lab.stand(Helpers.AT_PC1, _lab.node("Items/StickyNote").position)
	await _lab.read("Items/StickyNote")
	await _lab.stand(Helpers.AT_PC1, _lab.node("Devices/OfficePc1").position)
	assert_bool(pc1.use_by(_lab.player)).is_true()
	var screen := ComputerScreen.of(_lab.player)
	assert_array(screen.known_users()).contains_exactly(["achen"])
	screen.fill_in(0)
	screen.login_button.pressed.emit()
	assert_bool(screen.desktop_shown()).is_true()
	screen.dock_button(Computer.MAIL).pressed.emit()
	assert_str(screen.mail_app.titles()[0]).is_equal("Re: my password")
	var personal_log := PersonalLog.of(_lab.player)
	assert_bool(personal_log.has(&"gallery.network_lab.pc1_mail_password")).is_true()
	# A clue, not a login: PC 2's login is still unknown.
	assert_array(_lab.computer("Devices/OfficePc2").known_logins(_lab.player)).is_empty()
	assert_str(screen.mail_app.learned_label.text).is_equal(DocumentApp.CLUE)


func test_the_guess_from_the_mail_and_the_photo_opens_pc2_and_teaches_the_console_login() -> void:
	await _lab.stand(Helpers.AT_PC2, _lab.node("Items/Photo").position)
	await _lab.read("Items/Photo")
	await _lab.stand(Helpers.AT_PC2, _lab.node("Devices/OfficePc2").position)
	var pc2 := _lab.computer("Devices/OfficePc2")
	assert_bool(pc2.use_by(_lab.player)).is_true()
	var screen := ComputerScreen.of(_lab.player)
	assert_array(screen.known_users()).is_empty()
	# A first wrong guess (capitalised): the error line, and the tracer watching the office adds its
	# failed-login trace (15 %, Untrained x1).
	screen.user_field.text = "jnovak"
	screen.password_field.text = "Mishka2029"
	screen.login_button.pressed.emit()
	assert_str(screen.error_label.text).is_equal(ComputerScreen.WRONG_LOGIN)
	assert_float(_lab.tracer().trace_of(_lab.player)).is_equal_approx(15.0, 0.5)
	screen.password_field.text = "mishka2029"
	screen.login_button.pressed.emit()
	assert_bool(screen.desktop_shown()).is_true()
	assert_bool(pc2.is_logged_in()).is_true()
	# Its mail (shown first, so read) teaches the console's login: Fill in offers it there.
	screen.dock_button(Computer.MAIL).pressed.emit()
	var known := _lab.computer("Devices/Console").known_logins(_lab.player)
	assert_int(known.size()).is_equal(1)
	assert_str(known[0].user).is_equal("ops")
	assert_str(known[0].password).is_equal("relay52")
