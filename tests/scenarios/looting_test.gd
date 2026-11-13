extends GdUnitTestSuite
## Scenario (ADR 0142), across the systems side (Lootable, ItemLoadout, WeaponDrop, Keychain kinds,
## the Interactor's tap) and the loot screen: in the carry room
## (tests/objects/fixtures/carry_room.tscn) the player taps E (0.2 s) on a knocked-out pistol guard
## whose loadout holds a keycard: the real loot screen opens on the guard, whose pistol went into its
## own inventory when it went down; Take all moves the pistol and the ammo into the player's
## inventory and the keycard onto the player's keychain as a card, which then opens a keycard reader.
## A locked locker opens for looting with E once its key is on the player's keychain.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const PISTOL_GUARD: PackedScene = preload("res://actors/guard/guard_pistol.tscn")
const LOCKER: PackedScene = preload("res://objects/containers/locker.tscn")
const KEY: ItemData = preload("res://items/key/key.tres")
## The guard lies along +X with its feet here, 1 m ahead of the player (as in
## player_carry_body_test.gd); the locker stands 1.6 m ahead, 0.8 m to the right, facing the player.
const BODY_FEET := Vector3(-1.2, 0, -1.0)
const LOCKER_AT := Vector3(0.8, 0, -1.6)
const TAP_FRAMES := 12

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	var screen := Screens.find(_player, Lootable.SCREEN) if is_instance_valid(_player) else null
	if screen != null:
		screen.close_screen()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_tap_e_on_a_downed_guard_take_all_and_swipe_its_keycard() -> void:
	await _load()
	var guard := _downed_guard()
	await _driver.frames(60)
	var torso := Hitboxes.of(guard).box(&"torso") as Node3D
	await _aim_at(Vector3.ZERO, torso.global_position)
	assert_int(Inventory.of(guard).grid.count_of(&"pistol")).is_equal(1)
	assert_bool(Keychain.of(guard).has_key(&"vault", Keychain.CARD)).is_true()

	await _driver.hold(&"use", TAP_FRAMES)
	await _driver.frames(2)

	var screen := Screens.find(_player, Lootable.SCREEN) as LootScreen
	assert_object(screen).is_not_null()
	assert_bool(screen.shows(guard)).is_true()
	assert_bool(_player.carry.is_carrying()).is_false()
	screen.take_all()
	screen.close()

	assert_int(_player.inventory.grid.count_of(&"pistol")).is_equal(1)
	assert_int(_player.inventory.grid.count_of(&"pistol_ammo")).is_greater(0)
	assert_array(Inventory.of(guard).stacks()).is_empty()
	assert_int(Keychain.of(guard).size()).is_equal(0)
	assert_bool(Keychain.of(_player).has_key(&"vault", Keychain.CARD)).is_true()
	var reader := _reader_box(&"vault").get_node("Reader") as KeycardLock
	assert_bool(reader.use_locked(_player)).is_true()
	assert_str(str(EventLog.find(&"lock.granted")[0].data["how"])).is_equal("keycard")


func test_a_locked_locker_opens_for_looting_once_its_key_is_on_the_keychain() -> void:
	await _load()
	var locker := LOCKER.instantiate() as Node3D
	locker.name = "Locker"
	var lock := Lock.locks_of(locker)[0] as MechanicalLock
	lock.data = lock.data.duplicate() as MechanicalLockData
	lock.data.key_id = &"locker_a"
	var medkits := StartingItem.new()
	medkits.item = Items.MEDKIT
	ItemLoadout.of(locker).items = [medkits] as Array[StartingItem]
	locker.position = LOCKER_AT
	locker.rotation.y = atan2(-LOCKER_AT.x, -LOCKER_AT.z)
	_driver.runner.scene().add_child(locker)
	await _driver.frames(5)
	await _aim_at(Vector3.ZERO, locker.global_position + Vector3.UP * 1.0)

	await _driver.press(&"use")
	assert_object(Screens.find(_player, Lootable.SCREEN)).is_null()
	assert_bool(Lockable.of(locker).locked).is_true()
	Inventory.of(_player).add(KEY, 1, {ItemStack.KEY_ID: "locker_a", ItemStack.KEY_NAME: "Locker key"})
	await _driver.press(&"use")

	assert_bool(Lockable.of(locker).locked).is_false()
	var screen := Screens.find(_player, Lootable.SCREEN) as LootScreen
	assert_bool(screen.shows(locker)).is_true()
	screen.take_all()
	assert_int(_player.inventory.grid.count_of(&"medkit")).is_equal(1)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


# A knocked-out pistol guard lying along +X from BODY_FEET, a vault keycard in its loadout.
func _downed_guard() -> Node3D:
	var guard := PISTOL_GUARD.instantiate() as Node3D
	guard.name = "Guard"
	(guard.get_node("Tags") as Tags).initial_tags = [&"actor.guard", ActorState.UNCONSCIOUS] as Array[StringName]
	var card := StartingItem.new()
	card.item = Items.KEYCARD
	card.state = {ItemStack.KEY_ID: "vault", ItemStack.KEY_NAME: "Vault keycard"}
	ItemLoadout.of(guard).items = [card] as Array[StartingItem]
	guard.position = BODY_FEET
	guard.rotation.y = PI * 0.5
	_driver.runner.scene().add_child(guard)
	return guard


func _aim_at(feet: Vector3, target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, feet, target))
	await _driver.frames(5)


# A locked minimal entity with a keycard reader for `access_id`, behind the player.
func _reader_box(access_id: StringName) -> Node3D:
	var box := Node3D.new()
	var lockable := Lockable.new()
	lockable.name = "Lockable"
	lockable.locked = true
	box.add_child(lockable)
	var reader := KeycardLock.new()
	reader.name = "Reader"
	reader.data = KeycardLockData.new()
	reader.data.access_id = access_id
	box.add_child(reader)
	return Fixtures.compose(box, _driver.runner.scene(), "Box", Vector3(0, 0, 3), [])
