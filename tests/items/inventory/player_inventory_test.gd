extends GdUnitTestSuite
## Integration: the player's belt and item use (pistol pickup, belt keys equip / holster, reloads
## from ammo stacks, medkit heal from the belt, tools, biocell message, death) and the inventory's
## save_state / load_state through the Player.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const WALL_POINT := Vector3(0, 1.5, -5.8)

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_pistol_pickup_auto_belts_and_key_1_equips_it() -> void:
	await _load()
	var body := Items.spawn_pickup(_driver.runner.scene(), Items.PISTOL, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, body.global_position))
	await _driver.frames(3)
	assert_str(_player.interactor.prompt).is_equal("E: pick up Silenced pistol")
	await _driver.hold(&"use", 2)
	await _driver.frames(1)

	assert_object(_player.inventory.belt.stack_in(0).item).is_same(Items.PISTOL)
	await _press(&"belt_1")
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	assert_int(_player.inventory.belt.selected).is_equal(0)
	assert_str(_hud.weapon_label.text).is_equal("Silenced pistol")
	assert_str(_hud.ammo_label.text).is_equal("10 / 0")

	await _press(&"belt_1")
	assert_bool(_player.weapons.is_armed()).is_false()
	assert_int(_player.inventory.belt.selected).is_equal(-1)


func test_reload_consumes_ammo_stacks_and_hud_shows_the_total() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1, {"magazine": 2})
	_player.inventory.give(Items.AMMO, 5)
	_player.inventory.give(Items.MEDKIT, 1)
	_player.inventory.give(Items.AMMO, 98)
	# Ammo stacks: 100 and 3.
	await _press(&"belt_1")
	await _driver.frames(1)
	assert_str(_hud.ammo_label.text).is_equal("2 / 103")

	await _press(&"reload")
	await _driver.frames(100)

	var pistol := _player.inventory.inventory.stacks_of(&"pistol")[0]
	assert_int(_player.weapons.state().magazine).is_equal(10)
	assert_int(pistol.state["magazine"]).is_equal(10)
	assert_int(_player.inventory.inventory.count_of(&"pistol_ammo")).is_equal(95)
	assert_array(_player.inventory.inventory.stacks_of(&"pistol_ammo")).has_size(1)
	assert_str(_hud.ammo_label.text).is_equal("10 / 95")


func test_shots_are_kept_on_the_stack_magazine() -> void:
	await _load()
	Items.arm(_player)
	await _press(&"belt_1")
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, WALL_POINT))
	await _driver.frames(3)

	await _press(&"fire")
	await _driver.frames(3)

	assert_int(_player.inventory.inventory.stacks_of(&"pistol")[0].state["magazine"]).is_equal(9)
	assert_str(_hud.ammo_label.text).is_equal("9 / 30")


func test_medkit_from_the_belt_heals_and_decrements() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 2)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")
	_player.body.take_damage(&"damage.blunt", 4.0, &"head")
	EventLog.clear()

	await _press(&"belt_1")

	var healed := EventLog.find(&"actor.healed")
	assert_array(healed).has_size(1)
	assert_float(healed[0].data["amount"]).is_equal_approx(30.0, 0.001)
	assert_float(_player.body.health(&"torso")).is_equal_approx(86.0, 0.001)
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(1)
	var used := EventLog.find(&"item.used")
	assert_array(used).has_size(1)
	assert_str(used[0].data["action"]).is_equal("heal")
	# The belt keeps the (now smaller) stack; the last medkit clears the slot.
	assert_int(_player.inventory.belt.stack_in(0).count).is_equal(1)
	await _press(&"belt_1")
	assert_object(_player.inventory.belt.stack_in(0)).is_null()


func test_medkit_is_refused_when_unhurt() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 1)

	await _press(&"belt_1")

	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(1)
	assert_array(EventLog.find(&"item.use_refused")).has_size(1)
	assert_str(_hud.message_label.text).is_equal("You are not hurt")


func test_e_picks_a_medkit_up_instead_of_using_it() -> void:
	await _load()
	var body := Items.spawn_pickup(_driver.runner.scene(), Items.MEDKIT, Vector3(0, 0.05, -0.9))
	await _driver.frames(20)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, body.global_position))
	await _driver.frames(3)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")

	await _press(&"use")

	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(1)
	assert_array(EventLog.find(&"actor.healed")).is_empty()


func test_tool_goes_in_hand_and_a_weapon_replaces_it() -> void:
	await _load()
	_player.inventory.give(Items.MULTITOOL, 2)
	_player.inventory.give(Items.PISTOL, 1)

	await _press(&"belt_1")
	assert_object(_player.inventory.tool.item).is_same(Items.MULTITOOL)
	assert_str(_hud.weapon_label.text).is_equal("Multitool")
	await _press(&"fire")
	assert_array(EventLog.find(&"weapon.fired")).is_empty()

	await _press(&"belt_2")
	assert_object(_player.inventory.tool).is_null()
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	assert_int(_player.inventory.belt.selected).is_equal(1)


func test_biocell_says_nothing_happens_and_empty_slots_do_nothing() -> void:
	await _load()
	_player.inventory.give(Items.BIOCELL, 3)

	await _press(&"belt_1")
	assert_str(_hud.message_label.text).is_equal("Nothing happens")
	assert_int(_player.inventory.inventory.count_of(&"biocell")).is_equal(3)
	await _press(&"belt_5")
	assert_array(EventLog.find(&"item.used")).has_size(1)


func test_death_puts_the_weapon_away() -> void:
	await _load()
	Items.arm(_player)
	await _press(&"belt_2")
	assert_str(_player.weapons.weapon().id).is_equal("baton")

	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")
	await _driver.frames(1)

	assert_bool(_player.weapons.is_armed()).is_false()
	assert_object(_player.inventory.in_hand()).is_null()


func test_save_and_load_restore_the_inventory_belt_and_hand() -> void:
	await _load()
	Items.arm(_player)
	_player.inventory.give(Items.DATAPAD, 1, {"title": "Note", "text": "1234"})
	_player.inventory.belt.assign(7, _player.inventory.inventory.stacks_of(&"datapad")[0])
	await _press(&"belt_1")
	_player.weapons.state().magazine = 6
	var saved := _player.save_state()

	_player.load_state({"inventory": {}})
	assert_array(_player.inventory.inventory.stacks).is_empty()
	assert_bool(_player.weapons.is_armed()).is_false()
	_player.load_state(saved)

	var inventory := _player.inventory.inventory
	assert_int(inventory.stacks.size()).is_equal(4)
	assert_int(inventory.count_of(&"pistol_ammo")).is_equal(30)
	assert_str(_player.inventory.belt.stack_in(7).state["text"]).is_equal("1234")
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	assert_int(_player.weapons.state().magazine).is_equal(6)
	assert_int(_player.inventory.belt.selected).is_equal(0)


func _press(action: StringName) -> void:
	await _driver.hold(action, 2)
	await _driver.frames(1)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
