extends GdUnitTestSuite
## Integration (ADR 0130): a door locked by a mechanical lock that names a key
## (tests/objects/fixtures/door_wall_player: the player 1.2 m in front of the leaf). The frame's lock
## line says what opens it; E without the key says so in a HUD message and changes nothing; with the
## key on the player's keychain E unlocks it (EventLog `lock.unlocked`, how `key`) and it opens.

const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
## Relative to the fixture (Helpers.ORIGIN).
const FEET := Vector3(0, 0, 1.2)
const PANEL := Vector3(0, 1.4, 0)

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _entity: StaticBody3D
var _door: Door
var _lock: MechanicalLock


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_driver = PlayerDriver.new(scene_runner(Helpers.WALL_PLAYER))
	_player = _driver.player
	_player.reload_on_reset = false
	_hud = _player.get_node("Hud") as Hud
	_entity = Helpers.door_entity(_driver.runner.scene())
	_door = Door.of(_entity)
	_lock = Helpers.add_mechanical(_entity, 3)
	_lock.data.key_id = &"store_room"
	Helpers.lock(_entity)
	await _driver.settle()
	await _aim()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_frame_says_what_opens_it() -> void:
	assert_object(_hud.target_frame.target).is_same(_entity)
	assert_str(_hud.target_frame.lock_text()).is_equal("Locked · key or lockpick")

	_lock.data.key_id = &""
	_hud.target_frame.refresh(_player)
	assert_str(_hud.target_frame.lock_text()).is_equal("Locked · lockpick")


func test_e_without_the_key_says_why() -> void:
	await _press_use()

	assert_bool(_door.is_locked()).is_true()
	assert_str(_hud.message_label.text).is_equal("Locked: needs a key or a lockpick")
	assert_array(EventLog.find(&"lock.unlocked")).is_empty()


func test_e_with_the_key_unlocks_and_opens() -> void:
	# A key for another lock does nothing.
	Keychain.of(_player).add(&"office", "Office")
	await _press_use()
	assert_bool(_door.is_locked()).is_true()

	Keychain.of(_player).add(&"store_room", "Store room")
	await _press_use()

	assert_bool(_door.is_locked()).is_false()
	var unlocked := EventLog.find(&"lock.unlocked")
	assert_array(unlocked).has_size(1)
	assert_str(str(unlocked[0].data["how"])).is_equal("key")
	await _driver.frames(45)
	assert_bool(_door.is_open()).is_true()
	assert_str(_hud.target_frame.lock_text()).is_equal("")


func _press_use() -> void:
	await _driver.hold(&"use", 2)
	await _driver.frames(1)
	_hud.target_frame.refresh(_player)


func _aim() -> void:
	_player.load_state(Objects.aiming_state(_player, Helpers.ORIGIN + FEET, Helpers.ORIGIN + PANEL))
	await _driver.frames(3)
	_hud.target_frame.refresh(_player)
