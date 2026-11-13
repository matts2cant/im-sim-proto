extends GdUnitTestSuite
## Unit + integration (ADR 0130): the Keychain component. Keys by id, never twice, saved and loaded;
## any character can hold one (a bare node here). The player picks a key up onto its keychain, never
## into the grid ("Key added to the keychain: <name>"), cannot drop it, and the Inventory tab lists
## it with where it was found. A mechanical lock opens with E for any holder of its key.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const KEY: ItemData = preload("res://items/key/key.tres")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_holds_keys_by_id_once_and_saves() -> void:
	var holder := auto_free(Node3D.new()) as Node3D
	holder.name = "Guard"
	var keychain := Keychain.new()
	holder.add_child(keychain)
	add_child(holder)

	assert_bool(keychain.add(&"bay_a", "Linking bay A", "Found in the office desk")).is_true()
	assert_bool(keychain.add(&"bay_a", "Copy")).is_false()
	assert_bool(keychain.add(&"", "Nameless")).is_false()
	assert_bool(keychain.has_key(&"bay_a")).is_true()
	assert_bool(keychain.has_key(&"office")).is_false()
	assert_bool(keychain.has_key(&"")).is_false()
	assert_bool(keychain.is_in_group(&"saveable")).is_true()
	assert_array(EventLog.find(&"keychain.key_added")).has_size(1)

	var other := Keychain.new()
	other.load_state(keychain.save_state())
	assert_array(other.keys()).is_equal(keychain.keys())
	assert_str(str(other.keys()[0]["found"])).is_equal("Found in the office desk")
	other.free()


func test_any_holder_of_the_key_opens_a_mechanical_lock() -> void:
	var holder := auto_free(Node3D.new()) as Node3D
	var keychain := Keychain.new()
	holder.add_child(keychain)
	var box := auto_free(StaticBody3D.new()) as StaticBody3D
	var lockable := Lockable.new()
	lockable.locked = true
	box.add_child(lockable)
	var lock := MechanicalLock.new()
	lock.data = MechanicalLockData.new()
	lock.data.key_id = &"locker"
	box.add_child(lock)
	add_child(holder)
	add_child(box)

	assert_bool(lock.use_locked(holder)).is_false()
	keychain.add(&"locker", "Locker")
	assert_bool(lock.use_locked(holder)).is_true()
	assert_bool(lockable.locked).is_false()


func test_picking_up_a_key_puts_it_on_the_keychain_not_the_grid() -> void:
	await _load()
	var pickup := Items.spawn_pickup(
		_driver.runner.scene(), KEY, Vector3(0, 0.05, -0.9), 1, {"key_id": "bay_a", "key_name": "Linking bay A"}
	)
	ItemPickup.of(pickup).found_text = "Found in the office desk"
	await _driver.frames(20)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, pickup.global_position))
	await _driver.frames(3)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.PICK_UP)

	await _driver.hold(&"use", 2)
	await _driver.frames(2)

	var keychain := Keychain.of(_player)
	assert_bool(keychain.has_key(&"bay_a")).is_true()
	assert_bool(is_instance_valid(pickup) and not pickup.is_queued_for_deletion()).is_false()
	assert_array(_player.inventory.inventory.stacks).is_empty()
	var hud := _player.get_node("Hud") as Hud
	assert_str(hud.message_label.text).is_equal("Key added to the keychain: Linking bay A")
	# Nothing in hand to drop: Q does nothing and the key stays.
	await _driver.hold(&"drop_throw", 2)
	assert_bool(keychain.has_key(&"bay_a")).is_true()
	# Saved with the level like any saveable component.
	var data := keychain.save_state()
	keychain.load_state({})
	assert_int(keychain.size()).is_equal(0)
	keychain.load_state(data)
	assert_bool(keychain.has_key(&"bay_a")).is_true()


func test_the_inventory_tab_lists_the_keys() -> void:
	await _load()
	var keychain := Keychain.of(_player)
	keychain.add(&"bay_a", "Linking bay A", "Found in the office desk")
	_player.inventory.give(KEY, 1, {"key_id": "gate", "key_name": "Gate padlock"})
	var tab := TabInterface.of(_player).page(0) as InventoryTab

	await _driver.hold(&"inventory", 2)
	await _driver.frames(1)

	assert_bool(TabInterface.of(_player).is_open()).is_true()
	assert_bool(tab.keychain_list.is_visible_in_tree()).is_true()
	assert_array(tab.keychain_list.names()).contains_exactly(["Linking bay A", "Gate padlock"])
	assert_array(_player.inventory.inventory.stacks).is_empty()
	var head := tab.keychain_list.get_child(0) as Label
	assert_str(head.text).is_equal(KeychainList.caption_text(2).to_upper())


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
