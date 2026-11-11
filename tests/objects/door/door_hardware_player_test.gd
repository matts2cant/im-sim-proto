extends GdUnitTestSuite
## Integration (ADR 0098): the player works a door by what it looks at
## (tests/objects/fixtures/door_wall_player: a 1.2 m doorway at z 0 in a 0.25 m wall, the player on
## its front). E on the leaf opens and closes it (its handle stands out of the jamb when open) and the
## pin lock is picked there, from either face; E on the keypad box enters the code; E on the card
## reader box swipes the card: the door opens and stays locked, so once closed it needs the card again.
## A keypad stays unlocked once its code is in.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
## Relative to the fixture (Helpers.ORIGIN): the player 1.2 m in front of or behind the wall's middle
## plane, at the doorway's centre; the leaf's middle at eye level.
const FEET_FRONT := Vector3(0, 0, 1.2)
const FEET_BACK := Vector3(0, 0, -1.2)
const LEAF := Vector3(0, 1.4, 0)
## 0.6 s to open or close, and margin (physics frames).
const SLIDE_FRAMES := 45

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


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_each_box_and_the_leaf_do_their_own_thing() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.add_keycard(_entity, &"vault")
	Helpers.add_mechanical(_entity, 3)
	Helpers.lock(_entity)
	_player.inventory.give(Items.KEYCARD, 1, {"key_id": "vault"})
	await _driver.frames(2)
	# Two boxes on each face, the keypad on top; the pin lock's keyholes on the leaf.
	assert_int(_door.hardware.controls(true).size()).is_equal(2)
	assert_int(_door.hardware.controls(false).size()).is_equal(2)

	# The leaf: what opens it, and E does nothing (no code, no card from here).
	await _aim(FEET_FRONT, Helpers.ORIGIN + LEAF)
	assert_object(_player.interactor.target).is_same(_entity)
	assert_str(_player.interactor.prompt).is_equal("Locked: keypad or keycard or lockpick")
	await _press(&"use")
	assert_bool(_screen.is_open()).is_false()
	assert_bool(_door.is_open()).is_false()

	# The keypad box: the keypad screen.
	await _aim(FEET_FRONT, Helpers.box_point(_door, true, 0))
	assert_str(_player.interactor.prompt).is_equal("E: enter code")
	await _press(&"use")
	assert_bool(_screen.is_open()).is_true()
	await _press(&"ui_cancel")
	assert_bool(_screen.is_open()).is_false()

	# The card reader box: the card opens it, and it stays locked.
	await _aim(FEET_FRONT, Helpers.box_point(_door, true, 1))
	assert_str(_player.interactor.prompt).is_equal("E: open (keycard)")
	await _press(&"use")
	await _driver.frames(SLIDE_FRAMES)
	assert_bool(_door.is_open()).is_true()
	assert_bool(_door.is_locked()).is_true()
	assert_array(EventLog.find(&"lock.granted")).has_size(1)

	# The handle stands out of the jamb: E there closes it, and it is locked again.
	await _aim(FEET_FRONT, _door.hardware.handle_point(true))
	assert_str(_player.interactor.prompt).is_equal("E: close")
	await _press(&"use")
	await _driver.frames(SLIDE_FRAMES)
	assert_bool(_door.is_open()).is_false()
	assert_bool(_door.is_locked()).is_true()
	await _aim(FEET_FRONT, Helpers.ORIGIN + LEAF)
	assert_str(_player.interactor.prompt).is_equal("Locked: keypad or keycard or lockpick")
	# The card is needed again.
	await _aim(FEET_FRONT, Helpers.box_point(_door, true, 1))
	assert_str(_player.interactor.prompt).is_equal("E: open (keycard)")


func test_a_pin_lock_is_picked_on_the_leaf_from_either_face() -> void:
	var lock := Helpers.add_mechanical(_entity, 3)
	Helpers.lock(_entity)
	_player.inventory.give(Items.LOCKPICK, 1)
	_player.inventory.hold(_player.inventory.inventory.stacks_of(&"lockpick")[0])
	await _driver.frames(2)
	var picking := LockpickScreen.of(_player)
	for feet: Vector3 in [FEET_FRONT, FEET_BACK]:
		var front := feet.z > 0.0
		# LMB on the handle with the keyhole starts the minigame; its success unlocks the door.
		await _aim(feet, _door.hardware.handle_point(front))
		assert_object(_player.interactor.target).override_failure_message(str(feet)).is_same(_entity)
		await _driver.hold(&"fire", 2)
		await _driver.frames(1)
		assert_bool(picking.is_open()).override_failure_message(str(feet)).is_true()
		lock.complete_pick(_player)
		picking.close()
		await _driver.frames(2)
		assert_bool(_door.is_locked()).override_failure_message(str(feet)).is_false()
		await _driver.frames(SLIDE_FRAMES)
		assert_bool(_door.is_open()).override_failure_message(str(feet)).is_true()
		# Closed and locked again for the other face.
		_door.close()
		await _driver.frames(SLIDE_FRAMES)
		Helpers.lock(_entity)
	assert_array(EventLog.find(&"lock.picked")).has_size(2)


func test_a_keypad_stays_unlocked_once_its_code_is_in() -> void:
	Helpers.add_keypad(_entity, &"storage_door", "2817")
	Helpers.lock(_entity)
	await _driver.frames(2)
	await _aim(FEET_FRONT, Helpers.box_point(_door))
	await _press(&"use")
	for key: String in ["2", "8", "1", "7", "OK"]:
		(_screen.grid.get_node("Key%s" % key) as Button).pressed.emit()
	await _driver.frames(SLIDE_FRAMES)
	assert_bool(_door.is_open()).is_true()

	# Closed from its keypad box: it stays unlocked, the leaf opens it.
	assert_str(_player.interactor.prompt).is_equal("E: close")
	await _press(&"use")
	await _driver.frames(SLIDE_FRAMES)
	assert_bool(_door.is_open()).is_false()
	assert_bool(_door.is_locked()).is_false()
	await _aim(FEET_FRONT, Helpers.ORIGIN + LEAF)
	assert_str(_player.interactor.prompt).is_equal("E: open")


func _aim(feet: Vector3, target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, Helpers.ORIGIN + feet, target))
	await _driver.frames(3)


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)
