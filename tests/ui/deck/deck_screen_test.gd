extends GdUnitTestSuite
## Integration (ADR 0113): the real Player and its deck in the lab fixture (fixtures/deck_lab.tscn).
## LMB with the deck in hand on the wall jack plugs it in and raises the screen (input off, mouse
## free, HUD hidden, the world running); Esc lowers it without opening the game menu and the deck
## stays plugged in, its scan still running; LMB on the jack raises it again; walking away unplugs
## it; LMB on an autonomous device plugs into its maintenance port.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Lab := preload("res://tests/ui/deck/fixtures/deck_lab.gd")
const DECK: ItemData = preload("res://items/deck/deck.tres")
const LAB: String = "res://tests/ui/deck/fixtures/deck_lab.tscn"

var _runner: GdUnitSceneRunner
var _driver: PlayerDriver
var _lab: Lab
var _player: Player
var _session: DeckSession
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
	_screen = DeckScreen.of(_player)
	await _driver.settle()
	_player.inventory.give(DECK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"deck")[0])
	await _driver.frames(2)


func after_test() -> void:
	if is_instance_valid(_session):
		_session.unplug()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


# Stands at `feet` (relative to the lab's origin) looking at `entity_name`, then holds LMB 2 frames.
func _click(feet: Vector3, entity_name: String) -> void:
	var target := _lab.node(entity_name).global_position
	_player.load_state(Objects.aiming_state(_player, Lab.ORIGIN + feet, target))
	await _driver.frames(3)
	await _driver.hold(&"fire", 2)
	await _driver.frames(1)


func test_lmb_on_a_jack_plugs_the_deck_in_and_esc_lowers_it() -> void:
	await _click(Lab.AT_JACK, "Jack")
	assert_bool(_session.is_plugged()).is_true()
	assert_object(_session.port).is_same(_lab.device("Jack"))
	assert_str(_session.source.address).is_equal("10.0.10.40")
	assert_bool(_screen.is_open()).is_true()
	assert_bool(_player.input_enabled).is_false()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_bool((_player.get_node("Hud") as CanvasLayer).visible).is_false()
	assert_str(_screen.title_meta.text).is_equal("Plugged into OFFICE-JACK (wall jack) · 10.0.10.40")
	# The world keeps running: the scan of the office subnet finishes while the screen is open.
	await _driver.frames(150)
	_screen.refresh()
	assert_bool(get_tree().paused).is_false()
	assert_array(_screen.graph.node_names()).contains(["OFFICE-JACK", "SW-OFFICE", "OFFICE-PC", "FW-01"])
	assert_array(_screen.trace_texts()).has_size(1)
	assert_str(_screen.trace_texts()[0]).starts_with("Sentry tracer")
	# Esc lowers it: input back, the game menu stays shut, the deck stays plugged in.
	_runner.simulate_action_pressed(&"ui_cancel")
	await _driver.frames(2)
	assert_bool(_screen.is_open()).is_false()
	assert_bool(_player.input_enabled).is_true()
	assert_bool((_player.get_node("GameMenu") as GameMenu).is_open()).is_false()
	assert_bool(_session.is_plugged()).is_true()
	# LMB on the jack again raises it.
	await _click(Lab.AT_JACK, "Jack")
	assert_bool(_screen.is_open()).is_true()
	# The ✕ lowers it too.
	_screen.close_button.pressed.emit()
	assert_bool(_screen.is_open()).is_false()
	assert_bool(_session.is_plugged()).is_true()


func test_walking_away_unplugs_the_deck_and_stops_its_tools() -> void:
	_player.skills.set_tier(&"computer", 3)
	await _click(Lab.AT_JACK, "Jack")
	await _driver.frames(150)
	var ice := IcebreakerTool.of(_player)
	assert_bool(ice.start(_lab.device("OfficePc"), "kbrandt")).is_true()
	_runner.simulate_action_pressed(&"ui_cancel")
	await _driver.frames(30)
	# Lowered: the Icebreaker keeps running.
	assert_bool(ice.is_running()).is_true()
	assert_float(ice.job.progress).is_greater(0.0)
	# Walk south, away from the wall, past the tether.
	await _driver.hold(&"move_back", 120)
	await _driver.frames(2)
	assert_bool(_session.is_plugged()).is_false()
	assert_str(String(_session.unplug_reason)).is_equal("walked_away")
	assert_bool(ice.is_running()).is_false()
	assert_bool(_screen.is_open()).is_false()
	var stack := _player.inventory.inventory.stacks_of(&"deck")[0]
	assert_bool((stack.state[IcebreakerTool.CRACKS] as Dictionary).is_empty()).is_false()


func test_lmb_on_an_autonomous_device_plugs_into_its_maintenance_port() -> void:
	await _click(Lab.AT_KIOSK, "Kiosk")
	assert_bool(_session.is_plugged()).is_true()
	assert_object(_session.port).is_same(_lab.device("Kiosk"))
	assert_str(_screen.title_meta.text).is_equal("Plugged into KIOSK (maintenance port) · port:10.0.40.9")
	await _driver.frames(150)
	_screen.refresh()
	assert_array(_screen.graph.node_names()).is_equal(["KIOSK"])
	# LMB on a computer plugs into it: the deck uses the computer's address.
	_screen.close()
	await _click(Vector3(2, 0, 4.2), "OfficePc")
	assert_object(_session.port).is_same(_lab.device("OfficePc"))
	assert_str(_session.source.address).is_equal("10.0.10.12")
	assert_str(_screen.title_meta.text).is_equal("Plugged into OFFICE-PC (computer) · 10.0.10.12")
	# LMB on a cabled device without a port does nothing.
	_session.unplug()
	await _click(Vector3(9, 0, 4.2), "Camera")
	assert_bool(_session.is_plugged()).is_false()
	assert_bool(_screen.is_open()).is_false()
