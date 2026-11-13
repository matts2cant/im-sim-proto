extends GdUnitTestSuite
## LootRules (ADR 0142) on two holders built in code: drops with the footprint check, merging ammo,
## planting, quick moves, Take all, keys and cards moving between keychains with their kind, and the
## subject's line.

const Helpers := preload("res://tests/ui/loot/loot_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")

var _you: Node3D
var _them: Node3D


func before_test() -> void:
	EventLog.clear()
	_you = auto_free(Helpers.holder(self, "You", Vector2i(6, 5)))
	_them = auto_free(Helpers.holder(self, "Them", Vector2i(6, 5), "Locker"))


func test_a_drop_lands_where_the_footprint_fits() -> void:
	var theirs := Helpers.inventory(_them)
	var yours := Helpers.inventory(_you)
	theirs.add(Items.PISTOL, 1)
	yours.add(Items.BATON, 1)
	var pistol := theirs.stacks()[0]

	# Onto the baton (0, 0..2), and hanging off the right edge: refused, nothing moves.
	assert_bool(LootRules.drop_fits(theirs, pistol, yours, Vector2i(0, 1))).is_false()
	assert_int(LootRules.drop(theirs, pistol, yours, Vector2i(5, 2))).is_equal(0)
	assert_bool(theirs.has(pistol)).is_true()
	# Beside it: lands at that cell, gone from the other side.
	assert_int(LootRules.drop(theirs, pistol, yours, Vector2i(2, 3))).is_equal(1)
	assert_int(theirs.stacks().size()).is_equal(0)
	assert_vector(yours.grid.stacks_of(&"pistol")[0].cell).is_equal(Vector2i(2, 3))
	# Within one side it moves (its own old footprint does not block it).
	var moved := yours.grid.stacks_of(&"pistol")[0]
	assert_int(LootRules.drop(yours, moved, yours, Vector2i(3, 3))).is_equal(1)
	assert_vector(moved.cell).is_equal(Vector2i(3, 3))


func test_ammo_merges_into_the_other_sides_stack() -> void:
	var theirs := Helpers.inventory(_them)
	var yours := Helpers.inventory(_you)
	yours.add(Items.AMMO, 12)
	yours.add(Items.MEDKIT, 1)
	theirs.add(Items.AMMO, 24)
	var ammo := theirs.stacks()[0]

	# Dropped on the medkit's cell: the stack there takes all of it, so it fits.
	assert_bool(LootRules.drop_fits(theirs, ammo, yours, Vector2i(1, 0))).is_true()
	assert_int(LootRules.drop(theirs, ammo, yours, Vector2i(1, 0))).is_equal(24)
	assert_int(yours.grid.stacks_of(&"pistol_ammo").size()).is_equal(1)
	assert_int(yours.count(Items.AMMO)).is_equal(36)
	# Quick move merges too.
	theirs.add(Items.AMMO, 5)
	assert_int(LootRules.quick_move(theirs, theirs.stacks()[0], yours)).is_equal(5)
	assert_int(yours.grid.stacks_of(&"pistol_ammo").size()).is_equal(1)
	assert_int(yours.count(Items.AMMO)).is_equal(41)


func test_quick_move_takes_the_first_free_spot_and_keeps_the_state() -> void:
	var theirs := Helpers.inventory(_them)
	var yours := Helpers.inventory(_you)
	yours.add(Items.MEDKIT, 1)
	theirs.add(Items.PISTOL, 1)
	var pistol := theirs.stacks()[0]
	theirs.weapon_state(pistol).magazine = 3

	assert_int(LootRules.quick_move(theirs, pistol, yours)).is_equal(1)

	var landed := yours.grid.stacks_of(&"pistol")[0]
	assert_vector(landed.cell).is_equal(Vector2i(1, 0))
	assert_int(int(landed.state[ItemStack.MAGAZINE])).is_equal(3)
	assert_int(yours.weapon_state(landed).magazine).is_equal(3)


func test_planting_and_no_room() -> void:
	var small: Node3D = auto_free(Helpers.holder(self, "Box", Vector2i(1, 1)))
	var box := Helpers.inventory(small)
	var yours := Helpers.inventory(_you)
	yours.add(Items.PISTOL, 1)
	yours.add(Items.MEDKIT, 2)

	# The pistol (2 x 1) cannot go into a 1 x 1 box; the medkits can be planted there.
	assert_int(LootRules.quick_move(yours, yours.stacks()[0], box)).is_equal(0)
	assert_int(LootRules.quick_move(yours, yours.grid.stacks_of(&"medkit")[0], box)).is_equal(2)
	assert_int(box.count(Items.MEDKIT)).is_equal(2)
	assert_int(yours.count(Items.MEDKIT)).is_equal(0)


func test_take_all_takes_what_fits_and_every_key() -> void:
	var tight: Node3D = auto_free(Helpers.holder(self, "Tight", Vector2i(2, 2)))
	var mine := Helpers.inventory(tight)
	var theirs := Helpers.inventory(_them)
	mine.add(Items.MEDKIT, 1)
	theirs.add(Items.PISTOL, 1)
	theirs.add(Items.MEDKIT, 2)
	theirs.add(Items.BATON, 1)
	Helpers.give_key(_them, "sec_card", "Security room", Keychain.CARD)
	Helpers.give_key(_them, "office_key", "Office bay", Keychain.KEY)

	var stayed := LootRules.take_all(theirs, mine, Helpers.keychain(_them), Helpers.keychain(tight))

	assert_array(stayed).contains_exactly(["Stun baton"])
	assert_str(LootRules.take_all_notice(stayed)).is_equal("No room for: Stun baton")
	assert_int(mine.count(Items.MEDKIT)).is_equal(3)
	assert_int(mine.count(Items.PISTOL)).is_equal(1)
	assert_int(theirs.stacks().size()).is_equal(1)
	assert_int(Helpers.keychain(_them).size()).is_equal(0)
	assert_int(Helpers.keychain(tight).size()).is_equal(2)
	assert_str(LootRules.take_all_notice([] as Array[String])).is_equal(LootRules.TOOK_ALL)


func test_a_key_moves_with_its_kind() -> void:
	Helpers.give_key(_them, "sec_card", "Security room", Keychain.CARD)
	Helpers.give_key(_you, "office_key", "Office bay", Keychain.KEY)
	Helpers.give_key(_them, "office_key", "Office bay", Keychain.KEY)

	var entry := LootRules.move_key(Helpers.keychain(_them), Helpers.keychain(_you), "sec_card")

	assert_str(LootRules.key_notice(entry)).is_equal("Keycard added to the keychain: Security room")
	var mine := Helpers.keychain(_you).keys()
	assert_int(mine.size()).is_equal(2)
	assert_str(str(mine[1]["kind"])).is_equal("card")
	assert_str(str(mine[1]["found"])).is_equal("Found on the guard")
	# A key already held stays where it is.
	assert_dict(LootRules.move_key(Helpers.keychain(_them), Helpers.keychain(_you), "office_key")).is_empty()
	assert_int(Helpers.keychain(_them).size()).is_equal(1)


func test_kinds_and_lines() -> void:
	assert_str(String(LootRules.kind_of({"id": "a"}))).is_equal("key")
	assert_str(String(LootRules.kind_of({"kind": &"card"}))).is_equal("card")
	assert_str(LootRules.key_notice({"name": "Office bay"})).is_equal("Key added to the keychain: Office bay")
	assert_str(LootRules.subject_line(_them)).is_equal("Locker")
	var guard: Node = auto_free(Helpers.downed(self))
	assert_str(LootRules.subject_line(guard)).is_equal("Guard · unconscious")
