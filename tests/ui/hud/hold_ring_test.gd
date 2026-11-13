extends GdUnitTestSuite
## Integration (ADR 0142): the HUD's hold ring around the crosshair. The real player (carry room) looks
## down at a small crate 1.2 m ahead made lootable (an Inventory and a Lootable: usable and carryable,
## so E has a hold action). Holding E (`use`) for 0.25 s of the 0.5 s hold time shows the ring about
## half full; releasing it (a tap: the loot screen opens) hides it. Nothing to hold: no ring.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const FEET := Vector3(0, 0, 0)
const CRATE := Vector3(0, 0.31, -1.2)
## Looking 50 degrees down from 1.65 m: the eye ray meets the floor about 1.4 m ahead, through the
## crate's top (0.6 m high, 1.2 m ahead).
const PITCH := -0.87

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	var screen := Screens.find(_player, Lootable.SCREEN) if is_instance_valid(_player) else null
	if screen != null:
		screen.close_screen()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_the_ring_fills_while_e_is_held_and_hides_on_release() -> void:
	await _load()
	_lootable_crate()
	await _driver.frames(10)
	var interactor := _player.interactor
	interactor.refresh()
	assert_int(interactor.hold_kind).is_equal(Interactor.Kind.CARRY)
	_hud.refresh_hold_ring()
	assert_bool(_hud.hold_ring.visible).is_false()

	_driver.runner.simulate_action_press(&"use")
	await _driver.frames(15)
	_hud.refresh_hold_ring()

	assert_bool(interactor.is_holding()).is_true()
	assert_bool(_hud.hold_ring.visible).is_true()
	assert_float(_hud.hold_ring.progress).is_between(0.3, 0.7)
	assert_float(_hud.hold_ring.radius()).is_greater(4.0)

	_driver.runner.simulate_action_release(&"use")
	await _driver.frames(2)
	_hud.refresh_hold_ring()

	assert_bool(interactor.is_holding()).is_false()
	assert_bool(_hud.hold_ring.visible).is_false()
	assert_float(_hud.hold_ring.progress).is_equal(0.0)
	# The release was a tap: the loot screen opened on the crate.
	assert_object(Screens.find(_player, Lootable.SCREEN)).is_not_null()


func test_no_ring_without_a_hold_action() -> void:
	await _load()
	_driver.runner.simulate_action_press(&"use")
	await _driver.frames(15)
	_hud.refresh_hold_ring()
	_driver.runner.simulate_action_release(&"use")

	assert_bool(_hud.hold_ring.visible).is_false()


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = Hud.of(_player)
	await _driver.settle()
	var state := PlayerDriver.state(FEET, 0.0)
	state["pitch"] = PITCH
	_player.load_state(state)
	await _driver.frames(5)


func _lootable_crate() -> Node3D:
	var room := _driver.runner.scene()
	var crate := Objects.spawn(room, Objects.SMALL_CRATE, CRATE, "LootCrate")
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	crate.add_child(inventory)
	var lootable := Lootable.new()
	lootable.name = "Lootable"
	crate.add_child(lootable)
	return crate
