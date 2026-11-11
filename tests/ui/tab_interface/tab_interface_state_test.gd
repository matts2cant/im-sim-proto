extends GdUnitTestSuite
## Integration (ADR 0110): the Tab interface and the player's state and other screens. It does not
## open while dead or knocked out, closes when the player dies or is knocked out (HUD, input and
## the game menu come back: the player can always leave), does not open over the reading overlay
## (whose input-off keeps it shut) and swallows the debug panel key while open. Getting hit does not
## close it: the edges flash and fade.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _tabs: TabInterface


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	DebugPanel.set_open(false)
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_does_not_open_while_dead_or_knocked_out() -> void:
	await _load()
	_player.body.take_damage(&"damage.stun", 1000.0)
	await _driver.frames(1)

	await _press(&"tab_interface")
	await _press(&"inventory")
	assert_bool(_tabs.is_open()).is_false()


func test_closes_on_death_and_the_player_can_leave() -> void:
	await _load()
	await _press(&"personal_log")
	assert_bool(_tabs.is_open()).is_true()

	_player.body.take_damage(&"damage.ballistic", 1000.0, &"head")
	await _driver.frames(2)

	assert_bool(_tabs.is_open()).is_false()
	assert_bool(_player.input_enabled).is_true()
	assert_bool((_player.get_node("Hud") as CanvasLayer).visible).is_true()
	# The losing screen's game menu (Load) opens on Esc.
	await _press(&"ui_cancel")
	assert_bool((_player.get_node("GameMenu") as GameMenu).is_open()).is_true()


func test_closes_on_knockout() -> void:
	await _load()
	await _press(&"tab_interface")

	_player.body.take_damage(&"damage.stun", 1000.0)
	await _driver.frames(2)

	assert_bool(ActorState.can_act(_player)).is_false()
	assert_bool(_tabs.is_open()).is_false()
	assert_bool(_player.input_enabled).is_true()


func test_not_over_the_reading_overlay() -> void:
	await _load()
	var overlay := _player.get_node("ReadingOverlay") as ReadingOverlay
	PersonalLog.of(_player).read(LogEntry.make(&"note", "Note", "Text.", "Datapad"))
	assert_bool(overlay.is_open()).is_true()

	await _press(&"tab_interface")
	assert_bool(_tabs.is_open()).is_false()

	await _press(&"ui_cancel")
	assert_bool(overlay.is_open()).is_false()
	await _press(&"tab_interface")
	assert_bool(_tabs.is_open()).is_true()


func test_swallows_the_debug_panel_key_while_open() -> void:
	await _load()
	await _press(&"tab_interface")

	await _press(&"debug_panel_toggle")

	assert_bool(DebugPanel.is_open()).is_false()
	assert_bool(_tabs.is_open()).is_true()


func test_a_hit_flashes_the_edges_and_keeps_it_open() -> void:
	await _load()
	await _press(&"tab_interface")

	_player.body.take_damage(&"damage.blunt", 5.0, &"torso")
	await _driver.frames(1)

	assert_bool(_tabs.is_open()).is_true()
	assert_float(_tabs.flash_strength()).is_greater(0.5)
	await _driver.frames(40)
	assert_float(_tabs.flash_strength()).is_equal(0.0)


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_tabs = TabInterface.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
