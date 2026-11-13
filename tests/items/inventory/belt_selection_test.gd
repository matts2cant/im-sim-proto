extends GdUnitTestSuite
## Integration: choosing the item in hand from the belt (ADR 0059): the mouse wheel steps through
## the non-empty slots without using anything, H holsters, the HUD's highlight and item name follow,
## and the wheel is ignored while the Tab interface is open or the player is dead.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _hud: Hud


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_wheel_down_from_holstered_takes_the_first_then_the_next_item() -> void:
	await _load()
	_loadout_with_gap()

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_int(_player.inventory.belt.selected).is_equal(0)
	assert_str(_player.weapons.weapon().id).is_equal("pistol")
	assert_str(_hud.item_name_label.text).is_equal("Pistol")

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_int(_player.inventory.belt.selected).is_equal(3)
	assert_str(_player.weapons.weapon().id).is_equal("baton")
	assert_str(_hud.item_name_label.text).is_equal("Stun baton")


func test_wheel_up_from_holstered_takes_the_last_item_and_wraps() -> void:
	await _load()
	_loadout_with_gap()

	await _wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_int(_player.inventory.belt.selected).is_equal(6)
	assert_object(_player.inventory.held.item).is_same(Items.MEDKIT)
	assert_bool(_player.weapons.is_armed()).is_false()

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_int(_player.inventory.belt.selected).is_equal(0)
	assert_object(_player.inventory.held).is_null()
	assert_str(_player.weapons.weapon().id).is_equal("pistol")


func test_scrolling_onto_a_medkit_does_not_use_it() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 2)
	_player.body.take_damage(&"damage.blunt", 40.0, &"torso")
	EventLog.clear()

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)

	assert_object(_player.inventory.held.item).is_same(Items.MEDKIT)
	assert_int(_player.inventory.inventory.count_of(&"medkit")).is_equal(2)
	assert_array(EventLog.find(&"actor.healed")).is_empty()
	# The HUD updates in _process, which lags physics frames under the time factor: refresh it now.
	_hud.refresh_weapon()
	assert_str(_hud.weapon_label.text).is_equal("Medkit")


func test_h_holsters_the_drawn_pistol_and_clears_the_highlight() -> void:
	await _load()
	_loadout_with_gap()
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_bool(_player.weapons.is_armed()).is_true()

	await _driver.press(&"holster")

	assert_bool(_player.weapons.is_armed()).is_false()
	assert_object(_player.inventory.in_hand()).is_null()
	assert_int(_player.inventory.belt.selected).is_equal(-1)
	assert_str(_hud.item_name_label.text).is_equal("")
	assert_str(_hud.weapon_label.text).is_equal("")
	assert_array(EventLog.find(&"weapon.holstered")).has_size(1)
	# From empty hands the wheel starts again at the first item.
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_int(_player.inventory.belt.selected).is_equal(0)


func test_h_puts_a_held_item_away() -> void:
	await _load()
	_player.inventory.give(Items.LOCKPICK, 1)
	await _driver.press(&"belt_1")
	assert_object(_player.inventory.held.item).is_same(Items.LOCKPICK)

	await _driver.press(&"holster")

	assert_object(_player.inventory.held).is_null()
	assert_int(_player.inventory.belt.selected).is_equal(-1)


func test_item_name_hides_after_its_time() -> void:
	await _load()
	_loadout_with_gap()
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert_str(_hud.item_name_label.text).is_equal("Pistol")

	# 1.5 s of game time is 90 physics frames (delta stays 1/60 s with the time factor): wait 120.
	await _driver.frames(120)

	assert_str(_hud.item_name_label.text).is_equal("")
	assert_int(_player.inventory.belt.selected).is_equal(0)


func test_wheel_is_ignored_while_the_tab_interface_is_open() -> void:
	await _load()
	_loadout_with_gap()
	var screen := TabInterface.of(_player)
	await _driver.press(&"inventory")
	assert_bool(screen.is_open()).is_true()

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _driver.press(&"inventory")
	assert_bool(screen.is_open()).is_false()
	await _driver.frames(2)

	assert_int(_player.inventory.belt.selected).is_equal(-1)
	assert_object(_player.inventory.in_hand()).is_null()


func test_wheel_and_h_are_ignored_when_dead() -> void:
	await _load()
	_loadout_with_gap()
	_player.reload_on_reset = false
	_player.body.take_damage(&"damage.ballistic", 30.0, &"head")
	await _driver.frames(1)
	assert_bool(_player.is_dead()).is_true()

	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await _driver.press(&"holster")

	assert_int(_player.inventory.belt.selected).is_equal(-1)
	assert_bool(_player.weapons.is_armed()).is_false()


# Pistol in slot 0 (key 1), baton moved to slot 3, medkits moved to slot 6; the rest empty.
func _loadout_with_gap() -> void:
	Items.arm(_player)
	_player.inventory.give(Items.MEDKIT, 2)
	var inventory := _player.inventory
	inventory.belt.assign(3, inventory.inventory.stacks_of(&"baton")[0])
	inventory.belt.assign(6, inventory.inventory.stacks_of(&"medkit")[0])
	assert_object(inventory.belt.stack_in(1)).is_null()


# One wheel notch (press and release, as the OS sends it), then the physics tick that applies it.
func _wheel(button: MouseButton) -> void:
	_driver.runner.simulate_mouse_button_pressed(button)
	await _driver.frames(2)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = _player.get_node("Hud") as Hud
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
