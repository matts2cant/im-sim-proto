extends GdUnitTestSuite
## Integration: picking items up with E (prompt, stacking, auto-belt, no room, partial pickup) and
## dropping them back into the world as physics pickups (Q with the item in hand, drop_stack()),
## including the round trip of instance state (magazine, key_id).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
## On the floor about 1.8 m from the eyes of a player standing at the origin.
const FLOOR_SPOT := Vector3(0, 0.05, -0.9)

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_e_picks_up_a_stack_and_belts_it() -> void:
	await _load()
	var body := Items.spawn_pickup(_driver.runner.scene(), Items.LOCKPICK, FLOOR_SPOT, 3)
	await _driver.frames(20)
	await _look_at(body.global_position)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Lockpick (3)")

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(is_instance_valid(body)).is_false()
	assert_int(_player.inventory.grid.count_of(&"lockpick")).is_equal(3)
	assert_object(_player.inventory.belt.stack_in(0).item).is_same(Items.LOCKPICK)
	var picked := EventLog.find(&"item.picked_up")
	assert_array(picked).has_size(1)
	assert_dict(picked[0].data).is_equal({"item": "lockpick", "count": 3, "left": 0})
	# The contract PickUpObjective reads (ADR 0136): the picker as an entity.
	assert_object(picked[0].source_entity()).is_same(_player)


func test_ammo_and_keycards_are_not_belted() -> void:
	await _load()
	_player.inventory.add(Items.AMMO, 20)
	_player.inventory.add(Items.KEYCARD, 1, {"key_id": "office"})
	_player.inventory.add(Items.MEDKIT, 1)

	assert_int(_player.inventory.belt.slot_of(_player.inventory.grid.stacks[2])).is_equal(0)
	assert_int(_player.inventory.belt.first_free()).is_equal(1)


func test_full_inventory_refuses_and_the_item_stays() -> void:
	await _load()
	_player.inventory.add(Items.KEYCARD, 30)
	var body := Items.spawn_pickup(_driver.runner.scene(), Items.MEDKIT, FLOOR_SPOT)
	await _driver.frames(20)
	await _look_at(body.global_position)
	var hud := _player.get_node("Hud") as Hud

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_bool(is_instance_valid(body)).is_true()
	assert_int(_player.inventory.grid.count_of(&"medkit")).is_equal(0)
	assert_array(EventLog.find(&"item.pickup_refused")).has_size(1)
	assert_array(EventLog.find(&"item.picked_up")).is_empty()
	assert_str(hud.message_label.text).is_equal("No room in inventory")


func test_partial_pickup_leaves_the_rest_on_the_floor() -> void:
	await _load()
	_player.inventory.add(Items.KEYCARD, 29)
	_player.inventory.add(Items.AMMO, 80)
	var body := Items.spawn_pickup(_driver.runner.scene(), Items.AMMO, FLOOR_SPOT, 50)
	await _driver.frames(20)
	await _look_at(body.global_position)

	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_int(_player.inventory.grid.count_of(&"pistol_ammo")).is_equal(100)
	assert_bool(is_instance_valid(body)).is_true()
	assert_int(ItemPickup.of(body).count).is_equal(30)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Pistol ammo (30)")


func test_q_drops_the_weapon_in_hand_as_a_physics_pickup() -> void:
	await _load()
	_player.inventory.add(Items.PISTOL, 1)
	await _driver.hold(&"belt_1", 2)
	assert_bool(_player.weapons.is_armed()).is_true()
	_player.inventory.weapon_state(_player.inventory.grid.stacks[0]).magazine = 4

	await _driver.hold(&"drop_throw", 2)

	assert_bool(_player.weapons.is_armed()).is_false()
	assert_array(_player.inventory.grid.stacks).is_empty()
	assert_object(_player.inventory.belt.stack_in(0)).is_null()
	var dropped := EventLog.find(&"item.dropped")
	assert_array(dropped).has_size(1)
	var body := _driver.runner.scene().find_child("Pistol", false, false) as RigidBody3D
	assert_object(body).is_not_null()
	assert_int(ItemPickup.of(body).state["magazine"]).is_equal(4)
	# 0.8 m ahead (-Z) at chest height, tossed forward.
	assert_float(body.global_position.z).is_less(-0.5)
	await _driver.frames(60)
	assert_array(Objects.logged(&"object.impact", "object", "Pistol")).is_not_empty()
	assert_float(body.global_position.y).is_less(0.2)


func test_drop_round_trip_keeps_instance_state() -> void:
	await _load()
	_player.inventory.add(Items.PISTOL, 1, {"magazine": 3})
	_player.inventory.add(Items.KEYCARD, 1, {"key_id": "office"})
	_player.inventory.add(Items.AMMO, 25)
	var stacks := _player.inventory.grid.stacks.duplicate()

	for stack: ItemStack in stacks:
		var body := _player.inventory.drop_stack(stack)
		assert_object(body).is_not_null()
		await _driver.frames(50)
		await _pick_up(body)
		assert_bool(is_instance_valid(body)).is_false()

	var inventory := _player.inventory.grid
	assert_int(inventory.stacks_of(&"pistol")[0].state["magazine"]).is_equal(3)
	assert_str(inventory.stacks_of(&"keycard")[0].state["key_id"]).is_equal("office")
	assert_int(inventory.count_of(&"pistol_ammo")).is_equal(25)
	assert_array(EventLog.find(&"item.dropped")).has_size(3)
	assert_array(EventLog.find(&"item.picked_up")).has_size(3)


func test_drop_against_a_wall_stays_on_this_side() -> void:
	await _load()
	# The wall's face is at z = -5.8; stand 0.5 m from it.
	await _driver.place(Vector3(0, 0, -5.3))
	_player.inventory.add(Items.MEDKIT, 1)

	var body := _player.inventory.drop_stack(_player.inventory.grid.stacks[0])
	await _driver.frames(40)

	assert_float(body.global_position.z).is_greater(-5.8)


# Steps to 0.7 m from `body` (horizontally), looks at it and presses E.
func _pick_up(body: Node3D) -> void:
	var away := _player.global_position - body.global_position
	away.y = 0.0
	var feet := body.global_position + away.normalized() * 0.7
	feet.y = 0.0
	_player.load_state(Objects.aiming_state(_player, feet, body.global_position))
	await _driver.frames(3)
	await _driver.hold(&"use", 2)
	await _driver.frames(1)


func _look_at(target: Vector3) -> void:
	_player.load_state(Objects.aiming_state(_player, _player.global_position, target))
	await _driver.frames(3)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
