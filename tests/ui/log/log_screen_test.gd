extends GdUnitTestSuite
## Integration (ADR 0060): the log screen. L opens it (paused, mouse free), L or Esc closes it; it
## lists entry titles newest first, shows the selected entry's text and the known codes with the
## entry they came from; it does not open while dead or over the inventory / reading overlay, and
## the inventory does not open over it.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _screen: LogScreen
var _log: PersonalLog


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_l_opens_pauses_and_l_or_esc_closes() -> void:
	await _load()

	await _press(&"personal_log")
	assert_bool(_screen.is_open()).is_true()
	assert_bool(_screen.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	# Empty log: says how to fill it, no codes.
	assert_int(_screen.entry_list.item_count).is_equal(0)
	assert_str(_screen.text_label.text).is_equal(LogScreen.EMPTY_TEXT)
	assert_str(_screen.codes_label.text).is_equal(LogScreen.NO_CODES)

	await _press(&"personal_log")
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

	await _press(&"personal_log")
	await _press(&"ui_cancel")
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_lists_entries_newest_first_with_codes() -> void:
	await _load()
	_log.read(LogEntry.make(&"a", "Inventory bay", "Press I.", "Datapad"))
	_log.read(LogEntry.make(&"b", "Storage access", "Code 2817.", "Datapad", {&"storage_door": "2817"}))
	_close_overlay()

	await _press(&"personal_log")

	assert_int(_screen.entry_list.item_count).is_equal(2)
	assert_str(_screen.entry_list.get_item_text(0)).is_equal("Storage access")
	assert_str(_screen.entry_list.get_item_text(1)).is_equal("Inventory bay")
	# The newest is selected and shown.
	assert_array(Array(_screen.entry_list.get_selected_items())).contains_exactly([0])
	assert_str(_screen.shown_title()).is_equal("Storage access")
	assert_str(_screen.text_label.text).is_equal("Code 2817.")
	assert_str(_screen.codes_label.text).is_equal("Storage Door: 2817  (Storage access)")

	_screen.entry_list.select(1)
	_screen.entry_list.item_selected.emit(1)
	assert_str(_screen.shown_title()).is_equal("Inventory bay")
	assert_str(_screen.text_label.text).is_equal("Press I.")
	await _press(&"ui_cancel")


func test_does_not_open_while_dead() -> void:
	await _load()
	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")

	await _press(&"personal_log")

	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_does_not_stack_with_the_inventory_or_the_reading_overlay() -> void:
	await _load()
	var inventory := _player.get_node("InventoryScreen") as InventoryScreen
	var overlay := _player.get_node("ReadingOverlay") as ReadingOverlay

	await _press(&"inventory")
	await _press(&"personal_log")
	assert_bool(inventory.is_open()).is_true()
	assert_bool(_screen.is_open()).is_false()
	await _press(&"inventory")

	await _press(&"personal_log")
	await _press(&"inventory")
	assert_bool(_screen.is_open()).is_true()
	assert_bool(inventory.is_open()).is_false()
	await _press(&"personal_log")

	_log.read(LogEntry.make(&"a", "Memo", "Hello"))
	assert_bool(overlay.is_open()).is_true()
	await _press(&"personal_log")
	assert_bool(_screen.is_open()).is_false()
	await _press(&"ui_cancel")
	assert_bool(overlay.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func _close_overlay() -> void:
	(_player.get_node("ReadingOverlay") as ReadingOverlay).close()


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_player.reload_on_reset = false
	_screen = _player.get_node("LogScreen") as LogScreen
	_log = PersonalLog.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
