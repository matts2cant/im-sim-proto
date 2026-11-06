extends GdUnitTestSuite
## Unit: Belt slots reference inventory stacks (auto-assign, move between slots, cleared when the
## stack empties, selection, the mouse wheel's next / previous non-empty slot) and its to_dict round
## trip; InventoryAmmo counting and reloads.

const Items := preload("res://tests/items/item_test_helpers.gd")
const PISTOL_DATA: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const FRAME := 1.0 / 60.0

var _inventory: Inventory
var _belt: Belt


func before_test() -> void:
	_inventory = Inventory.new(Vector2i(6, 5))
	_belt = Belt.new(_inventory)


func test_key_labels_run_one_to_zero() -> void:
	assert_int(_belt.size()).is_equal(10)
	assert_str(Belt.key_label(0)).is_equal("1")
	assert_str(Belt.key_label(8)).is_equal("9")
	assert_str(Belt.key_label(9)).is_equal("0")


func test_slots_hold_references_not_copies() -> void:
	_inventory.add(Items.MEDKIT, 3)
	var stack := _inventory.stacks[0]

	assert_int(_belt.auto_assign(stack)).is_equal(0)
	_inventory.add(Items.MEDKIT, 2)

	assert_object(_belt.stack_in(0)).is_same(stack)
	assert_int(_belt.stack_in(0).count).is_equal(5)
	assert_int(_belt.auto_assign(stack)).is_equal(0)


func test_auto_assign_takes_the_first_free_slot() -> void:
	_inventory.add(Items.MULTITOOL, 1)
	_inventory.add(Items.LOCKPICK, 1)
	_inventory.add(Items.BIOCELL, 1)
	_belt.assign(0, _inventory.stacks[0])
	_belt.assign(2, _inventory.stacks[1])

	assert_int(_belt.auto_assign(_inventory.stacks[2])).is_equal(1)


func test_assigning_moves_a_stack_between_slots() -> void:
	_inventory.add(Items.MULTITOOL, 1)
	_inventory.add(Items.LOCKPICK, 1)
	var tool := _inventory.stacks[0]
	_belt.assign(0, tool)
	_belt.select(0)

	assert_bool(_belt.assign(4, tool)).is_true()

	assert_object(_belt.stack_in(0)).is_null()
	assert_int(_belt.slot_of(tool)).is_equal(4)
	assert_int(_belt.selected).is_equal(4)
	# Replacing a slot's stack drops the old reference.
	_belt.assign(4, _inventory.stacks[1])
	assert_int(_belt.slot_of(tool)).is_equal(-1)
	assert_int(_belt.selected).is_equal(-1)
	assert_bool(_belt.assign(10, tool)).is_false()
	assert_bool(_belt.assign(1, ItemStack.new(Items.MEDKIT))).is_false()


func test_emptied_stack_clears_its_slot_and_selection() -> void:
	_inventory.add(Items.MEDKIT, 2)
	var stack := _inventory.stacks[0]
	_belt.assign(3, stack)
	_belt.select(3)

	_inventory.remove(stack, 1)
	assert_object(_belt.stack_in(3)).is_same(stack)
	_inventory.remove(stack, 1)

	assert_object(_belt.stack_in(3)).is_null()
	assert_int(_belt.selected).is_equal(-1)


func test_next_filled_skips_empty_slots_both_ways() -> void:
	_fill_slots([1, 4, 7])

	assert_int(_belt.next_filled(1, 1)).is_equal(4)
	assert_int(_belt.next_filled(4, 1)).is_equal(7)
	assert_int(_belt.next_filled(7, -1)).is_equal(4)
	assert_int(_belt.next_filled(4, -1)).is_equal(1)


func test_next_filled_wraps_around() -> void:
	_fill_slots([1, 4, 7])

	assert_int(_belt.next_filled(7, 1)).is_equal(1)
	assert_int(_belt.next_filled(1, -1)).is_equal(7)


func test_next_filled_from_empty_hands_takes_the_first_or_last() -> void:
	_fill_slots([2, 5, 8])

	assert_int(_belt.next_filled(-1, 1)).is_equal(2)
	assert_int(_belt.next_filled(-1, -1)).is_equal(8)


func test_next_filled_with_one_item_stays_and_empty_belt_gives_none() -> void:
	assert_int(_belt.next_filled(-1, 1)).is_equal(-1)
	assert_int(_belt.next_filled(-1, -1)).is_equal(-1)
	assert_int(_belt.next_filled(3, 1)).is_equal(-1)

	_fill_slots([3])
	assert_int(_belt.next_filled(3, 1)).is_equal(3)
	assert_int(_belt.next_filled(3, -1)).is_equal(3)
	assert_int(_belt.next_filled(-1, 1)).is_equal(3)


func test_to_dict_round_trip() -> void:
	var catalog := ItemCatalog.default()
	_inventory.add(Items.PISTOL, 1)
	_inventory.add(Items.MEDKIT, 4)
	_belt.assign(0, _inventory.stacks[0])
	_belt.assign(9, _inventory.stacks[1])
	_belt.select(0)

	var inventory := Inventory.new(Vector2i(6, 5))
	inventory.from_dict(_inventory.to_dict(), catalog)
	var belt := Belt.new(inventory)
	belt.from_dict(_belt.to_dict())

	assert_object(belt.stack_in(0)).is_same(inventory.stacks[0])
	assert_object(belt.stack_in(9)).is_same(inventory.stacks[1])
	assert_int(belt.stack_in(9).count).is_equal(4)
	assert_int(belt.selected).is_equal(0)
	assert_dict(belt.to_dict()).is_equal(_belt.to_dict())


func test_inventory_ammo_counts_every_ammo_stack() -> void:
	_inventory.add(Items.AMMO, 130)
	_inventory.add(Items.MEDKIT, 1)
	var ammo := InventoryAmmo.new(_inventory, &"pistol_ammo")

	assert_int(ammo.available()).is_equal(130)
	assert_int(ammo.take(40)).is_equal(40)
	assert_int(ammo.available()).is_equal(90)
	ammo.restore(500)
	assert_int(ammo.available()).is_equal(90)


func test_reload_pulls_rounds_from_ammo_stacks() -> void:
	_inventory.add(Items.AMMO, 4)
	_inventory.add(Items.MEDKIT, 1)
	_inventory.add(Items.AMMO, 100)
	_inventory.split(_inventory.stacks[0], 2)
	# Ammo stacks: 98 (4 + 96 merged, minus the split), 4 (the overflow), 2 (split off).
	var state := WeaponState.new(PISTOL_DATA, InventoryAmmo.new(_inventory, &"pistol_ammo"))
	state.magazine = 3

	assert_int(state.reserve).is_equal(104)
	assert_bool(state.start_reload()).is_true()
	for i in 97:
		state.step(FRAME)

	assert_int(state.magazine).is_equal(10)
	assert_int(state.reserve).is_equal(97)
	# The two small stacks were used up first.
	(
		assert_array(_inventory.stacks_of(&"pistol_ammo").map(func(stack: ItemStack) -> int: return stack.count))
		. contains_exactly([97])
	)


func test_no_ammo_in_the_inventory_means_no_reload() -> void:
	var state := WeaponState.new(PISTOL_DATA, InventoryAmmo.new(_inventory, &"pistol_ammo"))
	state.magazine = 0

	assert_int(state.reserve).is_equal(0)
	assert_bool(state.start_reload()).is_false()


# A distinct one-cell item in each of `indices` (nothing auto-belts: the items are bare).
func _fill_slots(indices: Array[int]) -> void:
	for index in indices:
		var item := Items.make_item(StringName("thing_%d" % index), Vector2i.ONE)
		_inventory.add(item, 1)
		_belt.assign(index, _inventory.stacks[-1])
