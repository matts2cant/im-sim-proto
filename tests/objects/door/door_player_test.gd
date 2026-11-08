extends GdUnitTestSuite
## Integration (ADR 0078): the player and a door 1.2 m ahead (tests/objects/fixtures/door_wall_player:
## player at z 1.2 facing the panel at z 0). E opens and closes it; each lock opens only by its own
## method: a keypad by its code on the keypad screen (keys or clicks; Esc leaves while typing; the
## reminder shows a code from the log), a keycard reader by a carried card with its key id, a
## mechanical lock by holding LMB with a lockpick for pins x 1 s x lockpick_time_mult.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const FEET := Vector3(0, 0, 1.2)
const PANEL := Vector3(0, 1.4, 0)
const CONTROL := Vector3(-0.9, 1.25, 0.15)

var _driver: PlayerDriver
var _player: Player
var _entity: StaticBody3D
var _door: Door
var _screen: KeypadScreen


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(Helpers.WALL_PLAYER))
	_player = _driver.player
	_player.reload_on_reset = false
	_screen = KeypadScreen.of(_player)
	_entity = Helpers.door_entity(_driver.runner.scene())
	_door = Door.of(_entity)
	await _driver.settle()
	await _aim(PANEL)


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_e_opens_and_closes_the_door() -> void:
	assert_str(_player.interactor.prompt).is_equal("E: open")

	await _press(&"use")
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	assert_float(_door.openness).is_equal(1.0)

	await _aim(CONTROL)
	assert_str(_player.interactor.prompt).is_equal("E: close")
	await _press(&"use")
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_false()


func test_keypad_opens_with_its_code_typed_on_the_screen() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("E: enter code")

	await _press(&"use")
	assert_bool(_screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(_screen.reminder_label.visible).is_false()
	await _type([KEY_1, KEY_1, KEY_1, KEY_1, KEY_ENTER])
	assert_bool(_screen.is_open()).is_true()
	assert_str(_screen.message_label.text).is_equal("Wrong code")
	assert_bool(_door.is_locked()).is_true()

	await _type([KEY_2, KEY_8, KEY_KP_1, KEY_7, KEY_ENTER])

	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_door.is_locked()).is_false()
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	var entered := EventLog.find(&"lock.code_entered")
	assert_array(entered.map(func(entry: EventLogEntry) -> bool: return entry.data["correct"])).is_equal([false, true])


func test_keypad_buttons_can_be_clicked() -> void:
	var keypad := Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	await _press(&"use")

	for key: String in ["2", "8", "1", "7", "OK"]:
		(_screen.grid.get_node("Key%s" % key) as Button).pressed.emit()
	await _driver.frames(2)

	assert_bool(_screen.is_open()).is_false()
	assert_bool(keypad.is_locked()).is_false()


func test_esc_leaves_the_keypad_while_typing() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	await _press(&"use")
	await _type([KEY_2, KEY_8])
	assert_str(_screen.display_label.text).is_equal("28")

	await _press(&"ui_cancel")

	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_door.is_locked()).is_true()
	# The Esc closed the keypad only, not into the game menu.
	var menu := _player.get_node("GameMenu") as CanvasLayer
	assert_bool(menu.visible).is_false()


func test_keypad_shows_the_reminder_of_a_code_read_earlier() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	PersonalLog.of(_player).read(
		LogEntry.make(&"gallery.storage", "Storage access", "Code 2817", "Datapad", {&"storage_door": "2817"})
	)
	# Reading opened the reading overlay: close it first.
	(_player.get_node("ReadingOverlay") as ReadingOverlay).close()
	await _driver.frames(2)
	assert_bool(_screen.is_open()).is_false()

	await _press(&"use")

	assert_bool(_screen.is_open()).is_true()
	assert_bool(_screen.reminder_label.visible).is_true()
	assert_str(_screen.reminder_label.text).is_equal("Note: 2817, from 'Storage access'")
	# The player still types it.
	assert_bool(_door.is_locked()).is_true()
	await _press(&"ui_cancel")


func test_keycard_reader_opens_only_with_the_matching_card() -> void:
	Helpers.add_keycard(_entity, &"vault")
	Helpers.lock(_entity)
	_player.inventory.give(Items.KEYCARD, 1, {"key_id": "office"})
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("Locked: keycard")
	await _press(&"use")
	assert_bool(_door.is_locked()).is_true()
	# A lockpick does nothing to a card reader.
	await _hold_pick(1.5)
	assert_bool(_door.is_locked()).is_true()

	_player.inventory.give(Items.KEYCARD, 1, {"key_id": "vault"})
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("E: open (keycard)")
	await _press(&"use")

	assert_bool(_door.is_locked()).is_false()
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()


func test_holding_lmb_with_a_lockpick_picks_a_mechanical_lock() -> void:
	var lock := Helpers.add_mechanical(_entity, 3)
	Helpers.lock(_entity)
	_player.skills.set_tier(&"lockpicking", 1)
	assert_float(lock.pick_time(_player)).is_equal_approx(2.25, 0.001)
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("Locked: lockpick")
	# E and LMB with empty hands do nothing.
	await _press(&"use")
	await _driver.hold(&"fire", 30)
	assert_bool(_door.is_locked()).is_true()

	# 1.2 s, let go: the progress is lost.
	await _hold_pick(1.2)
	assert_array(EventLog.find(&"lock.pick_cancelled")).has_size(1)
	assert_bool(_door.is_locked()).is_true()
	# 1.5 s into a new attempt: still locked, the prompt shows the progress.
	_driver.runner.simulate_action_press(&"fire")
	await _driver.frames(90)
	assert_bool(_door.is_locked()).is_true()
	assert_str(_player.interactor.prompt).starts_with("Picking ")
	# 2.6 s in all: picked.
	await _driver.frames(66)
	_driver.runner.simulate_action_release(&"fire")
	await _driver.frames(2)

	assert_bool(_door.is_locked()).is_false()
	assert_array(EventLog.find(&"lock.picked")).has_size(1)
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	# Success consumes nothing.
	assert_int(_player.inventory.inventory.count_of(&"lockpick")).is_equal(1)


func test_a_keypad_is_not_picked() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)

	await _hold_pick(3.5)

	assert_bool(_door.is_locked()).is_true()
	assert_array(EventLog.find(&"lock.pick_started")).is_empty()


# A lockpick in hand (given if missing), LMB held for `seconds`, then released.
func _hold_pick(seconds: float) -> void:
	if _player.inventory.inventory.count_of(&"lockpick") == 0:
		_player.inventory.give(Items.LOCKPICK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"lockpick")[0])
	await _driver.frames(2)
	await _driver.hold(&"fire", roundi(seconds * 60.0))
	await _driver.frames(2)


func _aim(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, FEET, target))
	await _driver.frames(3)


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _type(keys: Array[Key]) -> void:
	for key in keys:
		_driver.runner.simulate_key_pressed(key)
		await _driver.frames(1)
	await _driver.frames(1)
