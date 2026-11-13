extends GdUnitTestSuite
## Unit: InventoryGrid placement (scan order, footprints), stack merging and overflow, refusal when
## full, move validity, remove, split, take, and the to_dict / from_dict round trip.

const Items := preload("res://tests/items/item_test_helpers.gd")

var _inventory: InventoryGrid


func before_test() -> void:
	_inventory = InventoryGrid.new(Vector2i(6, 5))


func test_new_stacks_scan_rows_top_to_bottom_left_to_right() -> void:
	var square := Items.make_item(&"square", Vector2i(1, 1))

	for i in 8:
		assert_int(_inventory.add(square, 1)).is_equal(0)

	var cells := _inventory.stacks.map(func(stack: ItemStack) -> Vector2i: return stack.cell)
	(
		assert_array(cells)
		. contains_exactly(
			[
				Vector2i(0, 0),
				Vector2i(1, 0),
				Vector2i(2, 0),
				Vector2i(3, 0),
				Vector2i(4, 0),
				Vector2i(5, 0),
				Vector2i(0, 1),
				Vector2i(1, 1),
			]
		)
	)


func test_footprints_skip_occupied_cells() -> void:
	var pistol := Items.make_item(&"pistol", Vector2i(2, 1))
	var baton := Items.make_item(&"baton", Vector2i(1, 3))
	var square := Items.make_item(&"square", Vector2i(1, 1))

	_inventory.add(square, 1)
	_inventory.add(pistol, 1)
	_inventory.add(baton, 1)
	_inventory.add(pistol, 1)

	assert_vector(_inventory.stacks[1].cell).is_equal(Vector2i(1, 0))
	# The baton's 1 x 3 column first fits at (3, 0).
	assert_vector(_inventory.stacks[2].cell).is_equal(Vector2i(3, 0))
	assert_vector(_inventory.stacks[3].cell).is_equal(Vector2i(4, 0))
	assert_object(_inventory.stack_at(Vector2i(3, 2))).is_same(_inventory.stacks[2])
	assert_object(_inventory.stack_at(Vector2i(2, 0))).is_same(_inventory.stacks[1])
	assert_object(_inventory.stack_at(Vector2i(0, 1))).is_null()


func test_tall_item_needs_rows_below() -> void:
	var baton := Items.make_item(&"baton", Vector2i(1, 3))
	var row := Items.make_item(&"row", Vector2i(6, 1))
	_inventory.add(row, 1)
	_inventory.add(row, 1)
	_inventory.add(row, 1)

	# Rows 3 and 4 are free: two rows, not three.
	assert_int(_inventory.add(baton, 1)).is_equal(1)
	assert_vector(_inventory.first_free(Vector2i(6, 2))).is_equal(Vector2i(0, 3))


func test_stackables_merge_into_existing_stacks_first() -> void:
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	_inventory.add(ammo, 60)
	_inventory.add(Items.make_item(&"square", Vector2i(1, 1)), 1)

	assert_int(_inventory.add(ammo, 70)).is_equal(0)

	assert_int(_inventory.stacks.size()).is_equal(3)
	assert_int(_inventory.stacks[0].count).is_equal(100)
	assert_int(_inventory.stacks[2].count).is_equal(30)
	assert_vector(_inventory.stacks[2].cell).is_equal(Vector2i(2, 0))
	assert_int(_inventory.count_of(&"ammo")).is_equal(130)


func test_overflow_returns_what_did_not_fit() -> void:
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	var block := Items.make_item(&"block", Vector2i(6, 5))
	var small := InventoryGrid.new(Vector2i(2, 1))

	assert_int(small.add(ammo, 250)).is_equal(50)
	assert_int(small.count_of(&"ammo")).is_equal(200)
	assert_int(_inventory.add(block, 1)).is_equal(0)
	assert_int(_inventory.add(block, 1)).is_equal(1)


func test_full_inventory_refuses_and_stays_unchanged() -> void:
	var square := Items.make_item(&"square", Vector2i(1, 1))
	var changes: Array[int] = [0]
	for i in 30:
		_inventory.add(square, 1)
	_inventory.changed.connect(func() -> void: changes[0] += 1)

	assert_int(_inventory.add(square, 1)).is_equal(1)
	assert_int(_inventory.stacks.size()).is_equal(30)
	assert_int(changes[0]).is_equal(0)
	# A full stack of a stackable item takes nothing more either.
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 5)
	var one := InventoryGrid.new(Vector2i(1, 1))
	one.add(ammo, 5)
	assert_int(one.add(ammo, 2)).is_equal(2)


func test_items_with_state_never_merge_and_copy_their_state() -> void:
	var pistol := Items.make_item(&"pistol", Vector2i(2, 1), 1, {"magazine": 10})

	_inventory.add(pistol, 2, {"magazine": 3})

	assert_int(_inventory.stacks.size()).is_equal(2)
	assert_int(_inventory.stacks[0].state["magazine"]).is_equal(3)
	_inventory.stacks[0].state["magazine"] = 7
	assert_int(_inventory.stacks[1].state["magazine"]).is_equal(3)
	assert_dict(pistol.default_state).is_equal({"magazine": 10})


func test_move_checks_bounds_overlap_and_ignores_its_own_footprint() -> void:
	var pistol := Items.make_item(&"pistol", Vector2i(2, 1))
	var square := Items.make_item(&"square", Vector2i(1, 1))
	_inventory.add(pistol, 1)
	_inventory.add(square, 1)
	var gun := _inventory.stacks[0]
	var box := _inventory.stacks[1]

	assert_bool(_inventory.move(gun, Vector2i(5, 0))).is_false()
	assert_bool(_inventory.move(gun, Vector2i(-1, 0))).is_false()
	assert_bool(_inventory.move(gun, Vector2i(0, 5))).is_false()
	assert_bool(_inventory.move(gun, Vector2i(1, 0))).is_false()
	assert_vector(gun.cell).is_equal(Vector2i(0, 0))
	# One cell down overlaps nothing; then back up overlapping only its own old cells.
	assert_bool(_inventory.move(gun, Vector2i(0, 1))).is_true()
	assert_bool(_inventory.move(box, Vector2i(1, 0))).is_true()
	assert_bool(_inventory.move(gun, Vector2i(1, 1))).is_true()
	assert_vector(gun.cell).is_equal(Vector2i(1, 1))
	assert_bool(_inventory.move(gun, Vector2i(4, 4))).is_true()
	assert_bool(_inventory.move(ItemStack.new(square), Vector2i(0, 0))).is_false()


func test_remove_and_split() -> void:
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	_inventory.add(ammo, 40)
	var stack := _inventory.stacks[0]
	var removed: Array[ItemStack] = []
	_inventory.stack_removed.connect(func(gone: ItemStack) -> void: removed.append(gone))

	var part := _inventory.split(stack, 15)

	assert_int(stack.count).is_equal(25)
	assert_int(part.count).is_equal(15)
	assert_vector(part.cell).is_equal(Vector2i(1, 0))
	assert_object(_inventory.split(stack, 25)).is_null()
	assert_object(_inventory.split(stack, 0)).is_null()
	assert_int(_inventory.remove(part, 5)).is_equal(5)
	assert_int(part.count).is_equal(10)
	assert_array(removed).is_empty()
	assert_int(_inventory.remove(part)).is_equal(10)
	assert_array(removed).contains_exactly([part])
	assert_bool(_inventory.stacks.has(part)).is_false()


func test_split_needs_a_free_cell() -> void:
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	var one := InventoryGrid.new(Vector2i(1, 1))
	one.add(ammo, 40)

	assert_object(one.split(one.stacks[0], 10)).is_null()
	assert_int(one.stacks[0].count).is_equal(40)


func test_take_empties_the_smallest_stacks_first() -> void:
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	_inventory.add(ammo, 100)
	_inventory.add(ammo, 30)
	_inventory.split(_inventory.stacks[0], 95)
	# Stacks: 5, 30, 95.

	assert_int(_inventory.take(&"ammo", 10)).is_equal(10)

	var counts := _inventory.stacks.map(func(stack: ItemStack) -> int: return stack.count)
	assert_array(counts).contains_exactly([25, 95])
	assert_int(_inventory.take(&"ammo", 500)).is_equal(120)
	assert_array(_inventory.stacks).is_empty()


func test_to_dict_round_trip() -> void:
	var catalog := ItemCatalog.new()
	var pistol := Items.make_item(&"pistol", Vector2i(2, 1), 1, {"magazine": 10})
	var ammo := Items.make_item(&"ammo", Vector2i(1, 1), 100)
	catalog.items.assign([pistol, ammo])
	_inventory.add(pistol, 1, {"magazine": 4})
	_inventory.add(ammo, 130)
	_inventory.move(_inventory.stacks[0], Vector2i(3, 2))

	var copy := InventoryGrid.new(Vector2i(6, 5))
	copy.from_dict(_inventory.to_dict(), catalog)

	assert_int(copy.stacks.size()).is_equal(3)
	assert_object(copy.stacks[0].item).is_same(pistol)
	assert_vector(copy.stacks[0].cell).is_equal(Vector2i(3, 2))
	assert_int(copy.stacks[0].state["magazine"]).is_equal(4)
	assert_int(copy.count_of(&"ammo")).is_equal(130)
	assert_dict(copy.to_dict()).is_equal(_inventory.to_dict())
