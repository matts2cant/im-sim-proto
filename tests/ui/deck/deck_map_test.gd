extends GdUnitTestSuite
## Integration (ADR 0113): the deck's Map and Icebreaker on the real Player in the lab fixture
## (fixtures/deck_lab.tscn), plugged into the wall jack. A device's menu: a login the Journal knows
## logs in without trace and hacking the router reveals the subnet behind it; the Icebreaker cracks
## an account and the Journal lists it; the skill assists by tier; a computer with an account offers
## its desktop remotely; saving and loading keeps the crack progress and the trace.

const DeckUi := preload("res://tests/ui/deck/deck_ui.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _session: DeckSession
var _ice: IcebreakerTool
var _screen: DeckScreen


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
	_ice = IcebreakerTool.of(_player)
	_screen = DeckScreen.of(_player)
	await _driver.settle()
	_player.inventory.give(DECK, 1)
	var stack := _player.inventory.inventory.stacks_of(&"deck")[0]
	_player.inventory.hold(stack)
	_player.load_state(PlayerDriver.state(Lab.ORIGIN + Lab.AT_JACK, 0.0))
	await _driver.frames(2)
	_session.plug_and_raise(_lab.device("Jack"))
	# The office scan (2 s).
	await _driver.frames(130)
	_screen.refresh()


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


# Presses the open menu's button `text`, else any button `text` on the screen.
func _press(text: String) -> void:
	var button := DeckUi.menu_button(_screen, text)
	if button == null:
		button = DeckUi.find_button(_screen, text)
	(
		assert_object(button)
		. override_failure_message("no button '%s' in %s" % [text, DeckUi.menu_texts(_screen)])
		. is_not_null()
	)
	if button != null:
		button.pressed.emit()


func test_a_known_login_logs_in_without_trace_and_hacking_the_router_reveals_its_subnet() -> void:
	var note := LogEntry.make(&"note.fw", "Router notes", "", "Datapad", {&"rtr01": "admin:Gh7vQx2e"})
	DeviceAccounts.of(_lab.node("Rtr01")).credentials_id = &"rtr01"
	PersonalLog.of(_player).add(note)
	assert_bool(_screen.graph.select("RTR-01")).is_true()
	var texts := DeckUi.menu_texts(_screen)
	assert_array(texts).contains(["ACCOUNTS", "admin", "Medium", "Log in (from Router notes)"])
	assert_bool(texts.has("SEC-CONSOLE")).is_false()
	var trace := _lab.tracer().trace_of(_player)
	_press("Log in (from Router notes)")
	# No trace for the login; the scan of the revealed subnet adds its 10 %.
	assert_float(_lab.tracer().trace_of(_player)).is_equal_approx(trace + 10.0, 0.001)
	assert_bool(DeviceAccounts.of(_lab.node("Rtr01")).has_access(_player)).is_true()
	await _driver.frames(130)
	_screen.refresh()
	assert_array(_screen.graph.node_names()).contains(["SW-SECURITY", "SEC-CONSOLE", "CAM-GATE", "RTR-02"])
	assert_bool(_screen.graph.node_names().has("FILE-SERVER")).is_false()
	# The hacked router is amber; the console's menu offers the Icebreaker; the camera says who it
	# trusts.
	assert_bool(_screen.graph.node_color("RTR-01").is_equal_approx(Color.WHITE)).is_true()
	_screen.graph.close_menu()
	assert_bool(_screen.graph.node_color("RTR-01").is_equal_approx(DeckStyle.ACCESS_COLOR)).is_true()
	_screen.graph.select("CAM-GATE")
	assert_array(DeckUi.menu_texts(_screen)).contains(
		["No accounts. Trusts SEC-CONSOLE: control it from that computer's Security app."]
	)


func test_the_icebreaker_cracks_an_account_into_the_journal() -> void:
	_player.skills.set_tier(&"computer", 3)
	_screen.graph.select("OFFICE-PC")
	_press("Icebreaker")
	assert_str(String(_screen.tool)).is_equal(String(DeckScreen.ICEBREAKER))
	assert_bool(_ice.is_running()).is_true()
	await _driver.frames(60)
	_screen.refresh()
	var texts := DeckUi.ice_texts(_screen)
	assert_array(texts).contains(["Icebreaker · kbrandt@OFFICE-PC", "Stop (keeps progress)"])
	# Master: Weak in 3 s.
	await _driver.frames(130)
	_screen.refresh()
	assert_bool(_ice.job.is_done()).is_true()
	assert_array(DeckUi.ice_texts(_screen)).contains(
		["Cracked: added to the Journal (Codes and logins)", "Back to the map"]
	)
	var codes := JournalRules.codes(PersonalLog.of(_player).book)
	assert_int(codes.size()).is_equal(1)
	assert_str(str(codes[0]["value"])).is_equal("kbrandt / ferry19")
	# Back on the map, the PC is amber with its account and offers its desktop remotely.
	_press("Back to the map")
	_screen.refresh()
	_screen.graph.select("OFFICE-PC")
	assert_array(DeckUi.menu_texts(_screen)).contains(["access", "Open its desktop (remote)"])
	_press("Open its desktop (remote)")
	assert_object(_session.remote).is_same(Computer.of(_lab.node("OfficePc")))
	var desktop := ComputerScreen.of(_player)
	assert_bool(desktop.is_remote()).is_true()
	desktop.back_button.pressed.emit()
	assert_bool(desktop.is_open()).is_false()
	assert_object(_session.remote).is_null()
	assert_bool(_screen.is_open()).is_true()


func test_the_skill_assists_by_tier() -> void:
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_session.refresh()
	await _driver.frames(130)
	_screen.refresh()
	# Untrained: no estimates; Medium is too strong.
	_screen.graph.select("SEC-CONSOLE")
	var texts := DeckUi.menu_texts(_screen)
	assert_array(texts).contains(["dmarsh", "Medium", "too strong"])
	# Trained: crack time per account; time left while cracking.
	_player.skills.set_tier(&"computer", 1)
	_screen.graph.select("OFFICE-PC")
	_screen.graph.select("SEC-CONSOLE")
	assert_array(DeckUi.menu_texts(_screen)).contains(["Medium · 18 s", "Icebreaker"])
	_press("Icebreaker")
	_screen.refresh()
	assert_array(DeckUi.ice_texts(_screen)).contains(["Computer skill · 18 s left"])
	_ice.stop()
	# Advanced: + the trace an action adds (12 s x 4 %/s x 0.6 = 29 %).
	_player.skills.set_tier(&"computer", 2)
	_screen.show_tool(DeckScreen.MAP)
	_screen.graph.select("OFFICE-PC")
	_screen.graph.select("SEC-CONSOLE")
	var advanced := DeckUi.menu_texts(_screen)
	assert_bool(advanced.any(func(text: String) -> bool: return text.begins_with("Computer skill · about +"))).is_true()
	# Master: + the hidden subnets a router routes to.
	_player.skills.set_tier(&"computer", 3)
	_screen.graph.select("RTR-02")
	assert_array(DeckUi.menu_texts(_screen)).contains(["Computer skill · routes to 1 hidden subnet"])


func test_saving_and_loading_keeps_crack_progress_and_trace() -> void:
	_player.skills.set_tier(&"computer", 1)
	DeviceAccounts.of(_lab.node("Rtr01")).grant(_player, "admin")
	_session.refresh()
	await _driver.frames(130)
	assert_bool(_ice.start(_lab.device("Console"), "dmarsh")).is_true()
	await _driver.frames(270)
	_ice.stop()
	var kept := _ice.saved_progress(_lab.device("Console"), "dmarsh")
	assert_float(kept).is_between(0.2, 0.3)
	var trace := _lab.tracer().trace_of(_player)
	assert_float(trace).is_greater(20.0)
	# What a save writes (JSON), then a load over a changed state.
	var player_data: Variant = JSON.from_native(_player.save_state())
	var tracer_data: Variant = JSON.from_native(_lab.tracer().save_state())
	var accounts_data: Variant = JSON.from_native(DeviceAccounts.of(_lab.node("Rtr01")).save_state())
	_session.unplug()
	_lab.tracer().model.from_dict({})
	DeviceAccounts.of(_lab.node("Rtr01")).load_state({"access": {}})
	_player.load_state(JSON.to_native(player_data) as Dictionary)
	_lab.tracer().load_state(JSON.to_native(tracer_data) as Dictionary)
	DeviceAccounts.of(_lab.node("Rtr01")).load_state(JSON.to_native(accounts_data) as Dictionary)
	assert_float(_lab.tracer().trace_of(_player)).is_equal_approx(trace, 0.001)
	assert_bool(DeviceAccounts.of(_lab.node("Rtr01")).has_access(_player)).is_true()
	# Plugged in again with the loaded deck: the crack resumes where it stopped.
	var stack := _player.inventory.inventory.stacks_of(&"deck")[0]
	_player.inventory.hold(stack)
	assert_bool(_session.plug(_lab.device("Jack"), stack)).is_true()
	assert_float(_ice.saved_progress(_lab.device("Console"), "dmarsh")).is_equal_approx(kept, 0.0001)
	assert_bool(_ice.start(_lab.device("Console"), "dmarsh")).is_true()
	assert_float(_ice.job.progress).is_equal_approx(kept, 0.0001)
