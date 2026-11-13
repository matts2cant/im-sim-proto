extends GdUnitTestSuite
## Integration (playtest bug: buttons on the deck's Map only clicked while the cursor moved): the
## deck's screen on the real Player in the lab fixture (fixtures/deck_lab.tscn), plugged into the
## wall jack. Real mouse events pushed through the viewport. A still click (the cursor moved onto a
## button, rested past the deck's refreshes, then pressed and released at the same spot without
## motion, held across refreshes) presses the device menu's buttons, opens a device's menu, toggles
## the Icebreaker and presses the remote desktop's Security actions while the trace rises; a still
## cursor keeps its hover across refreshes and trace updates; only the background drags the map.

const DeckUi := preload("res://tests/ui/deck/deck_ui.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"
## Physics frames (60 Hz) the cursor rests on the button before the press: past two deck refreshes
## (0.25 s each).
const REST_FRAMES: int = 40
## Frames between press and release: a quick click (0.1 s), and one held across two refreshes.
const QUICK_CLICK: int = 6
const HELD_CLICK: int = 36
## A drag's motion (px): far past NetworkGraph.DRAG_THRESHOLD (4 px).
const DRAG: Vector2 = Vector2(36, 24)

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _session: DeckSession
var _ice: IcebreakerTool
var _screen: DeckScreen
var _refreshes: int = 0


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_refreshes = 0
	_runner = scene_runner(LAB)
	_driver = PlayerDriver.new(_runner)
	_lab = _runner.scene() as Lab
	_player = _driver.player
	_player.reload_on_reset = false
	_session = DeckSession.of(_player)
	_ice = IcebreakerTool.of(_player)
	_screen = DeckScreen.of(_player)
	await _driver.settle()
	_player.inventory.add(DECK, 1)
	var stack := _player.inventory.grid.stacks_of(&"deck")[0]
	_player.inventory.hold(stack)
	_player.load_state(PlayerDriver.state(Lab.ORIGIN + Lab.AT_JACK, 0.0))
	await _driver.frames(2)
	_session.plug_and_raise(_lab.device("Jack"))
	_session.changed.connect(_on_session_changed)
	# The office scan (2 s).
	await _driver.frames(130)
	_screen.refresh()


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_a_quick_still_click_on_the_icebreaker_button_starts_the_crack() -> void:
	await _open_menu("OFFICE-PC")
	await _still_click(DeckUi.menu_button(_screen, "Icebreaker"), QUICK_CLICK)
	assert_bool(_ice.is_running()).is_true()
	assert_str(String(_screen.tool)).is_equal(String(DeckScreen.ICEBREAKER))


func test_a_still_click_held_across_refreshes_starts_the_crack() -> void:
	await _open_menu("OFFICE-PC")
	var refreshes := await _still_click(DeckUi.menu_button(_screen, "Icebreaker"), HELD_CLICK)
	assert_int(refreshes).is_greater_equal(2)
	assert_bool(_ice.is_running()).is_true()


func test_a_still_click_on_log_in_logs_in() -> void:
	var note := LogEntry.make(&"note.fw", "Router notes", "", "Datapad", {&"rtr01": "admin:Gh7vQx2e"})
	DeviceAccounts.of(_lab.node("Rtr01")).credentials_id = &"rtr01"
	PersonalLog.of(_player).add(note)
	await _open_menu("RTR-01")
	var refreshes := await _still_click(DeckUi.menu_button(_screen, "Log in (from Router notes)"), HELD_CLICK)
	assert_int(refreshes).is_greater_equal(2)
	assert_bool(DeviceAccounts.of(_lab.node("Rtr01")).has_access(_player)).is_true()


func test_a_still_click_on_open_its_desktop_opens_it() -> void:
	DeviceAccounts.of(_lab.node("OfficePc")).grant(_player, "kbrandt")
	_session.refresh()
	await _open_menu("OFFICE-PC")
	await _still_click(DeckUi.menu_button(_screen, "Open its desktop (remote)"), HELD_CLICK)
	assert_object(_session.remote).is_same(Computer.of(_lab.node("OfficePc")))


func test_a_still_click_on_a_device_opens_its_menu() -> void:
	var refreshes := await _still_click(_screen.graph.node_button("OFFICE-PC"), HELD_CLICK)
	assert_int(refreshes).is_greater_equal(2)
	assert_object(_screen.graph.selected).is_same(_lab.device("OfficePc"))
	assert_array(DeckUi.menu_texts(_screen)).contains(["kbrandt", "Icebreaker"])


func test_still_clicks_stop_and_resume_the_running_crack() -> void:
	assert_bool(_ice.start(_lab.device("OfficePc"), "kbrandt")).is_true()
	_screen.show_tool(DeckScreen.ICEBREAKER)
	await _driver.frames(3)
	# Running: its progress redraws the Icebreaker at every refresh while the cursor rests on Stop.
	await _still_click(DeckUi.find_button(_screen, "Stop (keeps progress)"), HELD_CLICK)
	assert_bool(_ice.is_running()).is_false()
	await _driver.frames(3)
	await _still_click(DeckUi.find_button(_screen, "Resume"), HELD_CLICK)
	assert_bool(_ice.is_running()).is_true()


func test_a_still_click_on_a_security_action_lands_while_the_trace_rises() -> void:
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	DeviceAccounts.of(_lab.node("Console")).grant(_player, "dmarsh")
	_session.refresh()
	await _driver.frames(130)
	assert_bool(_ice.start(_lab.device("OfficePc"), "kbrandt")).is_true()
	_session.open_remote(_lab.device("Console"))
	var desktop := ComputerScreen.of(_player)
	desktop.show_app(Computer.SECURITY)
	assert_bool(desktop.security_app.select("CAM-GATE")).is_true()
	await _driver.frames(3)
	var trace := _lab.tracer().trace_of(_player)
	await _still_click(desktop.security_app.action_button("Disable"), HELD_CLICK)
	assert_float(_lab.tracer().trace_of(_player)).is_greater(trace)
	assert_str(desktop.security_app.result_label.text).is_equal("CAM-GATE: Disable sent.")


func test_a_still_cursor_keeps_its_hover_across_refreshes_and_trace_updates() -> void:
	await _open_menu("OFFICE-PC")
	await _assert_hover_stays(DeckUi.menu_button(_screen, "Icebreaker"))
	# The remote desktop's Back button beside its trace bar, while the Icebreaker raises the trace.
	DeviceAccounts.of(_lab.node("OfficePc")).grant(_player, "kbrandt")
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_player.skills.set_tier(&"computer", 1)
	_session.refresh()
	await _driver.frames(130)
	assert_bool(_ice.start(_lab.device("Console"), "dmarsh")).is_true()
	_session.open_remote(_lab.device("OfficePc"))
	await _driver.frames(3)
	var trace := _lab.tracer().trace_of(_player)
	var desktop := ComputerScreen.of(_player)
	var bars := desktop.trace_bars().get_children()
	assert_array(bars).is_not_empty()
	await _assert_hover_stays(desktop.back_button)
	assert_float(_lab.tracer().trace_of(_player)).is_greater(trace)
	# The trace bar updated in place.
	assert_array(desktop.trace_bars().get_children()).is_equal(bars)


func test_a_press_moved_on_the_background_pans_the_map() -> void:
	var start := _background_point()
	var before := _screen.graph.view.offset
	_push_button(start, true)
	await _driver.frames(1)
	_push_motion(start + DRAG * 0.5, true)
	_push_motion(start + DRAG, true)
	await _driver.frames(1)
	_push_button(start + DRAG, false)
	await _driver.frames(2)
	assert_vector(_screen.graph.view.offset - before).is_equal_approx(DRAG, Vector2.ONE)
	# A still click there pans nothing.
	before = _screen.graph.view.offset
	await _still_click_at(start + DRAG, QUICK_CLICK)
	assert_vector(_screen.graph.view.offset).is_equal(before)


func test_a_press_moved_on_a_device_or_a_menu_button_does_not_pan() -> void:
	var before := _screen.graph.view.offset
	await _press_and_move(_screen.graph.node_button("OFFICE-PC"))
	assert_vector(_screen.graph.view.offset).is_equal(before)
	await _open_menu("OFFICE-PC")
	await _press_and_move(DeckUi.menu_button(_screen, "Icebreaker"))
	assert_vector(_screen.graph.view.offset).is_equal(before)


func _on_session_changed() -> void:
	_refreshes += 1


func _open_menu(device_name: String) -> void:
	assert_bool(_screen.graph.select(device_name)).is_true()
	# Laid out.
	await _driver.frames(3)


# Moves the cursor onto the middle of `button`, rests REST_FRAMES, then presses and releases there
# `hold` frames apart with no motion; returns the deck refreshes during the hold.
func _still_click(button: BaseButton, hold: int) -> int:
	assert_object(button).is_not_null()
	if button == null:
		return 0
	return await _still_click_at(_middle(button), hold)


func _still_click_at(at: Vector2, hold: int) -> int:
	_push_motion(at, false)
	await _driver.frames(REST_FRAMES)
	_push_button(at, true)
	var before := _refreshes
	await _driver.frames(hold)
	var during := _refreshes - before
	_push_button(at, false)
	await _driver.frames(2)
	return during


func _assert_hover_stays(button: BaseButton) -> void:
	assert_object(button).is_not_null()
	if button == null:
		return
	_push_motion(_middle(button), false)
	await _driver.frames(1)
	var before := _refreshes
	for frame in REST_FRAMES:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != button or button.get_draw_mode() != BaseButton.DRAW_HOVER:
			assert_object(hovered).override_failure_message("hover lost at frame %d" % frame).is_same(button)
			assert_int(button.get_draw_mode()).is_equal(BaseButton.DRAW_HOVER)
			return
		await _driver.frames(1)
	assert_int(_refreshes - before).is_greater_equal(2)


func _press_and_move(button: BaseButton) -> void:
	assert_object(button).is_not_null()
	if button == null:
		return
	var at := _middle(button)
	_push_motion(at, false)
	await _driver.frames(1)
	_push_button(at, true)
	await _driver.frames(1)
	_push_motion(at + DRAG * 0.5, true)
	_push_motion(at + DRAG, true)
	await _driver.frames(1)
	_push_button(at + DRAG, false)
	await _driver.frames(2)


# A point of the Map's background (no node, menu or Fit button), in canvas coordinates.
func _background_point() -> Vector2:
	var graph := _screen.graph
	var to_canvas := graph.get_global_transform_with_canvas()
	for y in range(40, int(graph.size.y) - 40, 20):
		for x in range(40, int(graph.size.x) - 120, 20):
			var local := Vector2(x, y)
			var free := graph.node_name_at(local).is_empty() and graph.node_name_at(local + DRAG).is_empty()
			if free and not graph.fit_button.get_rect().has_point(local):
				return to_canvas * local
	fail("no background point on the map")
	return Vector2.ZERO


static func _middle(button: Control) -> Vector2:
	return button.get_global_transform_with_canvas() * (button.size * 0.5)


func _push_motion(at: Vector2, held: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event, true)


func _push_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	get_viewport().push_input(event, true)
