extends GdUnitTestSuite
## Integration (ADR 0078, 0098): the player and a door 1.2 m ahead (tests/objects/fixtures/door_wall_player:
## player at z 1.2 facing the panel at z 0). E on the leaf opens it and E on its handle (standing out
## of the jamb) closes it; each lock opens only by its own method, on its own hardware: a keypad box
## by its code on the keypad screen (keys or clicks; Esc leaves while typing, E does not; the reminder
## shows a code from the log), a card reader box by a carried card with its key id, a mechanical lock
## (keyhole on the leaf) through the lockpicking minigame, started by LMB with a lockpick on the leaf
## (ADR 0107; the minigame itself: tests/ui/lockpick/).

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
## Relative to the fixture (Helpers.ORIGIN).
const FEET := Vector3(0, 0, 1.2)
const PANEL := Vector3(0, 1.4, 0)

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

	await _driver.press(&"use")
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	assert_float(_door.openness).is_equal(1.0)

	# Open, the leaf is in the wall: its handle stands out of the jamb.
	await _aim_world(_door.hardware.handle_point(true))
	assert_object(_player.interactor.target).is_same(_entity)
	assert_str(_player.interactor.prompt).is_equal("E: close")
	await _driver.press(&"use")
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_false()


func test_keypad_opens_with_its_code_typed_on_the_screen() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	# The leaf names the keypad; the keypad box beside the frame takes the code.
	assert_str(_player.interactor.prompt).is_equal("Locked: keypad")
	await _aim_world(Helpers.box_point(_door))
	assert_str(_player.interactor.prompt).is_equal("E: enter code")

	await _driver.press(&"use")
	assert_bool(_screen.is_open()).is_true()
	# The world keeps running (ADR 0110): the player's input is off instead.
	assert_bool(get_tree().paused).is_false()
	assert_bool(_player.accepts_input()).is_false()
	assert_bool(_screen.reminder_label.visible).is_false()
	await _type([KEY_1, KEY_1, KEY_1, KEY_1, KEY_ENTER])
	assert_bool(_screen.is_open()).is_true()
	assert_str(_screen.message_label.text).is_equal("Wrong code")
	assert_bool(_door.is_locked()).is_true()

	await _type([KEY_2, KEY_8, KEY_KP_1, KEY_7, KEY_ENTER])

	assert_bool(_screen.is_open()).is_false()
	assert_bool(_player.accepts_input()).is_true()
	assert_bool(_door.is_locked()).is_false()
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	var entered := EventLog.find(&"lock.code_entered")
	assert_array(entered.map(func(entry: EventLogEntry) -> bool: return entry.data["correct"])).is_equal([false, true])


func test_keypad_buttons_can_be_clicked() -> void:
	var keypad := Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	await _aim_world(Helpers.box_point(_door))
	await _driver.press(&"use")

	for key: String in ["2", "8", "1", "7", "OK"]:
		(_screen.grid.get_node("Key%s" % key) as Button).pressed.emit()
	await _driver.frames(2)

	assert_bool(_screen.is_open()).is_false()
	assert_bool(keypad.is_locked()).is_false()


func test_esc_leaves_the_keypad_while_typing_and_e_does_not() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	await _aim_world(Helpers.box_point(_door))
	await _driver.press(&"use")
	await _type([KEY_2, KEY_8])
	assert_str(_screen.display_label.text).is_equal("28")
	# E never leaves a screen (ADR 0083): only Esc does.
	await _driver.press(&"use")
	assert_bool(_screen.is_open()).is_true()
	assert_str(_screen.display_label.text).is_equal("28")

	await _driver.press(&"ui_cancel")

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
	await _aim_world(Helpers.box_point(_door))

	await _driver.press(&"use")

	assert_bool(_screen.is_open()).is_true()
	assert_bool(_screen.reminder_label.visible).is_true()
	assert_str(_screen.reminder_label.text).is_equal("Note: 2817, from 'Storage access'")
	# The player still types it.
	assert_bool(_door.is_locked()).is_true()
	await _driver.press(&"ui_cancel")


func test_keycard_reader_opens_only_with_the_matching_card() -> void:
	Helpers.add_keycard(_entity, &"vault")
	Helpers.lock(_entity)
	_player.inventory.add(Items.KEYCARD, 1, {"key_id": "office"})
	await _driver.frames(2)
	await _aim_world(Helpers.box_point(_door))
	assert_str(_player.interactor.prompt).is_equal("Locked: keycard")
	await _driver.press(&"use")
	assert_bool(_door.is_locked()).is_true()
	# A lockpick does nothing to a card reader.
	await _hold_pick(1.5)
	assert_bool(_door.is_locked()).is_true()

	_player.inventory.add(Items.KEYCARD, 1, {"key_id": "vault"})
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("E: open (keycard)")
	await _driver.press(&"use")

	# The card opens it without unlocking it (ADR 0098): it is locked again once closed.
	assert_bool(_door.is_locked()).is_true()
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()


func test_lmb_with_a_lockpick_on_the_leaf_starts_the_lockpicking_minigame() -> void:
	var lock := Helpers.add_mechanical(_entity, 3)
	Helpers.lock(_entity)
	await _driver.frames(2)
	assert_str(_player.interactor.prompt).is_equal("Locked: lockpick")
	# E and LMB with empty hands do nothing.
	await _driver.press(&"use")
	await _driver.hold(&"fire", 30)
	var picking := LockpickScreen.of(_player)
	assert_bool(picking.is_open()).is_false()
	assert_bool(_door.is_locked()).is_true()

	await _hold_pick(0.05)
	assert_bool(picking.is_open()).is_true()
	assert_object(picking.lock).is_same(lock)
	# The minigame's success unlocks the door, which opens; success consumes nothing.
	lock.complete_pick(_player)
	picking.close()
	await _driver.frames(45)
	assert_bool(_door.is_locked()).is_false()
	assert_bool(_door.is_open()).is_true()
	assert_int(_player.inventory.grid.count_of(&"lockpick")).is_equal(1)


func test_a_keypad_is_not_picked() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)

	await _hold_pick(3.5)

	assert_bool(_door.is_locked()).is_true()
	assert_array(EventLog.find(&"lock.pick_started")).is_empty()


# A lockpick in hand (given if missing), LMB held for `seconds`, then released.
func _hold_pick(seconds: float) -> void:
	if _player.inventory.grid.count_of(&"lockpick") == 0:
		_player.inventory.add(Items.LOCKPICK, 1)
	_player.inventory.hold(_player.inventory.grid.stacks_of(&"lockpick")[0])
	await _driver.frames(2)
	await _driver.hold(&"fire", roundi(seconds * 60.0))
	await _driver.frames(2)


func _aim(target: Vector3) -> void:
	await _aim_world(Helpers.ORIGIN + target)


# Looks at `target` (world) from FEET.
func _aim_world(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Helpers.ORIGIN + FEET, target))
	await _driver.frames(3)


func _type(keys: Array[Key]) -> void:
	for key in keys:
		_driver.runner.simulate_key_pressed(key)
		await _driver.frames(1)
	await _driver.frames(1)
