extends GdUnitTestSuite
## Integration (ADR 0083): the terminal screen's tabs in the security showcase
## (tests/objects/fixtures/showcase/security_helpers.gd has the layout: the terminal cabled through the
## switch to camera, turret, alarm controller, siren and door; camera and turret start disabled so
## the player is never shot). Camera tab: the devices with a view, a live feed of the selected one
## (a SubViewport whose camera sits on the device's eye), "No signal" when it sees nothing, its
## commands below. Network tab: a node per device, the cables, a node's menu with its status and
## commands; the map opens fitted and F fits it again (ADR 0099). Cutting the switch greys the branch
## with no commands. Esc leaves, E never does.

const Showcase := preload("res://tests/objects/fixtures/showcase/security_helpers.gd")
## 1 m in front of the terminal.
const AT_TERMINAL := Vector3(-6, 0, -7)
## A refresh (0.25 s) plus slack.
const REFRESH := 0.4

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


func test_camera_tab_lists_the_devices_with_a_view_and_shows_a_live_feed() -> void:
	_log_in()
	assert_int(_screen.tab).is_equal(TerminalScreen.Tab.CAMERA)
	assert_array(_screen.camera_names()).contains_exactly_in_any_order(["Camera", "Turret"])
	assert_object(_screen.camera_entry("Camera")).is_not_null()
	# Disabled: no signal, but its commands are there.
	assert_bool(_screen.select_camera("Camera")).is_true()
	_screen.update_feed()
	assert_bool(_screen.feed_live()).is_false()
	assert_bool(_screen.no_signal_label.visible).is_true()
	assert_str(_screen.no_signal_label.text).is_equal("No signal")
	assert_str(_screen.camera_status.text).is_equal("online · disabled")
	_screen.camera_button("Enable").pressed.emit()
	await _show.seconds(REFRESH)
	_screen.update_feed()
	assert_bool(_screen.feed_live()).is_true()
	assert_bool(_screen.no_signal_label.visible).is_false()
	assert_object(_screen.feed_rect.texture).is_instanceof(ViewportTexture)
	assert_vector(Vector2(_screen.feed_viewport.size)).is_equal(Vector2(480, 270))
	# The feed's camera sits on the camera's eye and looks where it looks.
	var eye := DeviceStatus.view_of(_show.node("Camera"))
	assert_vector(_screen.feed_camera.global_position).is_equal_approx(eye.global_position, Vector3.ONE * 0.001)
	var forward := -_screen.feed_camera.global_basis.z
	assert_float(forward.dot(-eye.global_basis.z)).is_greater(0.999)
	assert_str(_screen.camera_status.text).is_equal("online · enabled · sweeping")
	# Disabled again: no signal.
	_screen.camera_button("Disable").pressed.emit()
	await _show.seconds(REFRESH)
	_screen.update_feed()
	assert_bool(_screen.feed_live()).is_false()


func test_camera_tab_buttons_send_the_selected_devices_commands() -> void:
	_log_in()
	_screen.select_camera("Camera")
	var before := _show.camera().yaw()
	_screen.camera_button("Pan left").pressed.emit()
	await _show.frames(3)
	assert_float(_show.camera().yaw()).is_equal_approx(minf(before + 15.0, 40.0), 0.5)
	assert_bool(_show.camera().model.sweeping).is_false()
	_screen.select_camera("Turret")
	assert_object(_screen.camera_button("Pan left")).is_null()
	_screen.camera_button("Target guards").pressed.emit()
	await _show.frames(3)
	assert_array(_show.turret().hostile_tags()).contains_exactly([&"actor.guard"])
	assert_str(_screen.status_label.text).is_equal("Turret: Target guards sent.")


func test_the_feed_renders_only_while_the_camera_tab_shows() -> void:
	_log_in()
	_screen.select_camera("Camera")
	_screen.camera_button("Enable").pressed.emit()
	await _show.seconds(REFRESH)
	_screen.update_feed()
	assert_bool(_screen.feed_live()).is_true()
	_screen.show_tab(TerminalScreen.Tab.NETWORK)
	assert_int(_screen.feed_viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	_screen.show_tab(TerminalScreen.Tab.CAMERA)
	assert_bool(_screen.feed_live()).is_true()
	_screen.close()
	assert_int(_screen.feed_viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func test_network_tab_shows_nodes_cables_and_a_menu_that_sends_commands() -> void:
	_log_in()
	_screen.network_tab_button.pressed.emit()
	assert_bool(_screen.graph.is_visible_in_tree()).is_true()
	var graph := _screen.graph
	assert_array(graph.node_names()).contains_exactly_in_any_order(
		["Terminal", "Switch", "Camera", "Turret", "Controller", "Siren", "Door"]
	)
	assert_array(graph.cable_names()).has_size(6)
	for cable: String in graph.cable_names():
		assert_str(cable).contains("Switch")
	assert_str(graph.node_status("Siren")).is_equal("silent")
	assert_str(graph.node_status("Switch")).is_equal("online")
	# A node's menu: its status and its commands.
	graph.node_button("Siren").pressed.emit()
	assert_bool(graph.menu.visible).is_true()
	assert_str(graph.menu_title.text).is_equal("Siren")
	assert_array(graph.menu_labels()).contains_exactly(["Ring", "Test", "Silence"])
	graph.menu_button("Test").pressed.emit()
	await _show.seconds(REFRESH)
	assert_array(EventLog.find(&"siren.started")).has_size(1)
	assert_str(graph.node_status("Siren")).is_equal("ringing")
	# Still open on the siren, with its new status.
	assert_str(graph.menu_title.text).is_equal("Siren")
	assert_str(graph.menu_status.text).is_equal("online · ringing")
	# The door: open and locked from its menu.
	graph.select("Door")
	graph.menu_button("Lock").pressed.emit()
	graph.menu_button("Open").pressed.emit()
	await _show.seconds(REFRESH)
	assert_str(graph.node_status("Door")).contains("open")
	assert_str(graph.node_status("Door")).contains("locked")
	assert_str(graph.node_status("Door")).not_contains("unlocked")
	# The terminal's own node has no commands.
	graph.select("Terminal")
	assert_array(graph.menu_labels()).is_empty()


func test_cutting_the_switch_greys_the_branch_with_no_commands_never_broken() -> void:
	_log_in()
	_screen.show_tab(TerminalScreen.Tab.NETWORK)
	var graph := _screen.graph
	Powered.of(_show.node("Switch")).on = false
	Breakable.of(_show.node("Siren")).take_damage(&"damage.ballistic", 100.0)
	await _show.seconds(REFRESH)
	# Still drawn (the cables are there), all offline, never "broken" or "unpowered".
	assert_array(graph.node_names()).has_size(7)
	for device_name: String in ["Switch", "Camera", "Turret", "Controller", "Siren", "Door"]:
		assert_str(graph.node_status(device_name)).override_failure_message(device_name).is_equal("offline")
		graph.select(device_name)
		assert_array(graph.menu_labels()).override_failure_message(device_name).is_empty()
		assert_str(graph.menu_status.text).is_equal("offline")
	assert_str(graph.node_status("Terminal")).is_equal("logged in")
	# The Camera tab: still listed, greyed, no signal and no commands.
	_screen.show_tab(TerminalScreen.Tab.CAMERA)
	assert_array(_screen.camera_names()).contains_exactly_in_any_order(["Camera", "Turret"])
	_screen.select_camera("Camera")
	_screen.update_feed()
	assert_bool(_screen.feed_live()).is_false()
	assert_str(_screen.camera_status.text).is_equal("offline")
	assert_object(_screen.camera_button("Enable")).is_null()
	# Back on: online again within a refresh.
	Powered.of(_show.node("Switch")).on = true
	await _show.seconds(REFRESH)
	assert_str(_screen.status_of("Camera")).is_equal("online · disabled")
	assert_object(_screen.camera_button("Enable")).is_not_null()


func test_the_network_tab_opens_fitted_and_f_fits_it_again() -> void:
	_log_in()
	_screen.network_tab_button.pressed.emit()
	await _show.frames(2)
	var graph := _screen.graph
	var panel := Rect2(Vector2.ZERO, graph.size).grow(0.01)
	for device_name in graph.node_names():
		assert_bool(panel.encloses(graph.node_screen_rect(device_name))).override_failure_message(device_name).is_true()
	assert_str(_texts()).contains("Wheel: zoom")
	var fitted_zoom := graph.view.zoom
	var fitted_offset := graph.view.offset
	graph.zoom_at(graph.size * 0.5, 1.6)
	graph.pan(Vector2(-200, 50))
	assert_float(absf(graph.view.zoom - fitted_zoom)).is_greater(0.1)
	# F (by its physical key) fits it again.
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		key.keycode = KEY_F
		key.pressed = pressed
		get_viewport().push_input(key)
	assert_float(graph.view.zoom).is_equal_approx(fitted_zoom, 0.0001)
	assert_vector(graph.view.offset).is_equal_approx(fitted_offset, Vector2.ONE * 0.01)
	# Esc still leaves from the map; reopened, the map is fitted again.
	graph.pan(Vector2(150, 0))
	_show.runner.simulate_action_pressed(&"ui_cancel")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()
	_show.terminal().use(_show.player)
	await _show.frames(2)
	assert_vector(graph.view.offset).is_equal_approx(fitted_offset, Vector2.ONE * 0.01)


func test_esc_leaves_every_time_and_e_never_does() -> void:
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
	# No field focused, logged in: E still does not leave; Esc does.
	_log_in()
	_screen.user_field.release_focus()
	runner.simulate_action_pressed(&"use")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_true()
	runner.simulate_action_pressed(&"ui_cancel")
	await _show.frames(2)
	assert_bool(_screen.is_open()).is_false()


func test_the_hint_only_mentions_esc() -> void:
	_show.terminal().use(_show.player)
	var texts := _texts()
	assert_str(texts).contains("Esc: leave")
	assert_str(texts).not_contains("E: leave")


# Every label's text on the screen.
func _texts() -> String:
	var texts := ""
	for node in _screen.find_children("*", "Label", true, false):
		texts += (node as Label).text + "\n"
	return texts


func _log_in() -> void:
	if not _screen.is_open():
		_show.terminal().use(_show.player)
	_screen.user_field.text = "jmercer"
	_screen.password_field.text = "falcon7"
	_screen.submit_login()
	assert_bool(_show.terminal().logged_in).is_true()
