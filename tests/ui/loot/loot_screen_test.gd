extends GdUnitTestSuite
## Integration (ADR 0142): the loot screen on subjects built in code (a downed character or a plain
## holder with an Inventory and a keychain), the user a plain holder too: it opens and pauses, Esc and
## E close it and give the input back once; drags both ways with the footprint check, double-click
## and Enter quick moves, ammo merging, Take all into a full inventory, keys and cards with their
## icons, and the player's Screens registering it.

const Helpers := preload("res://tests/ui/loot/loot_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const PLAYER := "res://actors/player/player.tscn"

var _user: Node3D
var _subject: Node
var _screen: LootScreen


func before_test() -> void:
	EventLog.clear()
	PauseScreens.reset(get_tree())
	_screen = null


func after_test() -> void:
	if is_instance_valid(_screen):
		_screen.close()
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_opens_pauses_and_closes_on_esc_and_e() -> void:
	await _open(Helpers.downed(self))
	var closings: Array[int] = [0]
	_screen.closed.connect(func() -> void: closings[0] += 1)

	assert_bool(_screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(OverlayFocus.is_held(_user)).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_str(_screen.who_label.text).is_equal("Guard · unconscious")
	assert_str(_screen.their_caption.text).is_equal("GUARD")
	assert_bool(Screens.is_open(_user, Lootable.SCREEN, _subject)).is_true()

	_screen._unhandled_input(Helpers.action(&"ui_cancel"))
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(OverlayFocus.is_held(_user)).is_false()
	assert_int(OverlayFocus.count()).is_equal(0)
	# Closed: Esc again gives nothing back twice.
	_screen._unhandled_input(Helpers.action(&"ui_cancel"))
	assert_int(closings[0]).is_equal(1)

	assert_bool(_screen.open_screen(_subject, _user, {})).is_true()
	assert_bool(get_tree().paused).is_true()
	_screen._unhandled_input(Helpers.action(&"use"))
	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(OverlayFocus.count()).is_equal(0)
	assert_int(closings[0]).is_equal(2)
	# Something without an Inventory is not looted.
	assert_bool(_screen.open_screen(auto_free(Node3D.new()), _user, {})).is_false()


func test_closes_when_the_subject_is_gone() -> void:
	var subject := Helpers.holder(self, "Crate", Vector2i(4, 2), "Crate")
	Helpers.inventory(subject).add(Items.MEDKIT, 1)
	await _open(subject)

	subject.free()
	await get_tree().process_frame

	assert_bool(_screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(OverlayFocus.count()).is_equal(0)


func test_drag_both_ways_with_the_footprint_check() -> void:
	var subject := Helpers.holder(self, "Locker", Vector2i(6, 5), "Locker")
	Helpers.inventory(subject).add(Items.PISTOL, 1)
	Helpers.inventory(subject).add(Items.MEDKIT, 1)
	await _open(subject)
	Helpers.inventory(_user).add(Items.BATON, 1)
	var theirs := _screen.their_grid
	var yours := _screen.your_grid

	# The pistol (2 x 1), grabbed by its right cell, dropped with that cell on (3, 1): lands at (2, 1).
	Helpers.drag(theirs, Vector2i(1, 0), yours, Vector2i(3, 1))
	var pistol := Helpers.inventory(_user).grid.stacks_of(&"pistol")[0]
	assert_vector(pistol.cell).is_equal(Vector2i(2, 1))
	# The medkit (1 x 1) over the baton: red, and the drop is refused.
	Helpers.press(theirs, Vector2i(2, 0))
	Helpers.move(theirs, yours, Vector2i(0, 1))
	assert_object(_screen.drag.target).is_same(yours)
	assert_bool(_screen.drag.fits).is_false()
	Helpers.release(theirs, yours, Vector2i(0, 1))
	assert_int(Helpers.inventory(subject).count(Items.MEDKIT)).is_equal(1)
	# Beside it: green, and it lands.
	Helpers.press(theirs, Vector2i(2, 0))
	Helpers.move(theirs, yours, Vector2i(1, 2))
	assert_bool(_screen.drag.fits).is_true()
	Helpers.release(theirs, yours, Vector2i(1, 2))
	assert_vector(Helpers.inventory(_user).grid.stacks_of(&"medkit")[0].cell).is_equal(Vector2i(1, 2))

	# Back: the pistol hanging off the right edge is refused, at (3, 4) it lands (planting).
	Helpers.drag(yours, Vector2i(2, 1), theirs, Vector2i(5, 4))
	assert_bool(Helpers.inventory(_user).has(pistol)).is_true()
	Helpers.drag(yours, Vector2i(2, 1), theirs, Vector2i(3, 4))
	assert_vector(Helpers.inventory(subject).grid.stacks_of(&"pistol")[0].cell).is_equal(Vector2i(3, 4))
	Helpers.drag(yours, Vector2i(1, 2), theirs, Vector2i(0, 4))
	assert_vector(Helpers.inventory(subject).grid.stacks_of(&"medkit")[0].cell).is_equal(Vector2i(0, 4))
	assert_object(_screen.drag.stack).is_null()


func test_double_click_and_enter_quick_move() -> void:
	var subject := Helpers.holder(self, "Locker", Vector2i(6, 5), "Locker")
	Helpers.inventory(subject).add(Items.MEDKIT, 1)
	await _open(subject)
	Helpers.inventory(_user).add(Items.PISTOL, 1)

	Helpers.press(_screen.their_grid, Vector2i(0, 0))
	Helpers.release(_screen.their_grid, _screen.their_grid, Vector2i(0, 0))
	Helpers.press(_screen.their_grid, Vector2i(0, 0), true)
	assert_vector(Helpers.inventory(_user).grid.stacks_of(&"medkit")[0].cell).is_equal(Vector2i(2, 0))
	assert_int(Helpers.inventory(subject).stacks().size()).is_equal(0)

	# Click the pistol on your side (selects it), then Enter: to the first free spot over there.
	Helpers.press(_screen.your_grid, Vector2i(0, 0))
	Helpers.release(_screen.your_grid, _screen.your_grid, Vector2i(0, 0))
	_screen._unhandled_input(Helpers.enter())
	assert_vector(Helpers.inventory(subject).grid.stacks_of(&"pistol")[0].cell).is_equal(Vector2i(0, 0))
	assert_int(Helpers.inventory(_user).count(Items.PISTOL)).is_equal(0)


func test_ammo_dropped_on_an_empty_cell_merges() -> void:
	var subject := Helpers.holder(self, "Locker", Vector2i(6, 5), "Locker")
	Helpers.inventory(subject).add(Items.AMMO, 24)
	await _open(subject)
	Helpers.inventory(_user).add(Items.AMMO, 12)

	Helpers.drag(_screen.their_grid, Vector2i(0, 0), _screen.your_grid, Vector2i(4, 3))

	var stacks := Helpers.inventory(_user).grid.stacks_of(&"pistol_ammo")
	assert_int(stacks.size()).is_equal(1)
	assert_int(stacks[0].count).is_equal(36)
	assert_vector(stacks[0].cell).is_equal(Vector2i(0, 0))


func test_take_all_into_a_full_inventory_says_what_stayed() -> void:
	var subject := Helpers.downed(self)
	Helpers.inventory(subject).add(Items.PISTOL, 1)
	Helpers.inventory(subject).add(Items.BATON, 1)
	Helpers.inventory(subject).add(Items.AMMO, 24)
	Helpers.give_key(subject, "sec_card", "Security room", Keychain.CARD)
	await _open(subject, Vector2i(2, 2))
	Helpers.inventory(_user).add(Items.MEDKIT, 1)
	Helpers.inventory(_user).add(Items.AMMO, 6)
	assert_bool(_screen.take_all_button.disabled).is_false()

	_screen.take_all_button.pressed.emit()

	assert_int(Helpers.inventory(_user).count(Items.PISTOL)).is_equal(1)
	assert_int(Helpers.inventory(_user).count(Items.AMMO)).is_equal(30)
	assert_int(Helpers.inventory(subject).count(Items.BATON)).is_equal(1)
	assert_int(Helpers.keychain(_user).size()).is_equal(1)
	assert_str(_screen.notice_label.text).is_equal("No room for: Stun baton")
	# Only the baton left: Take all stays on for it.
	assert_bool(_screen.take_all_button.disabled).is_false()


func test_a_key_or_card_moves_with_a_click_and_its_icon() -> void:
	var subject := Helpers.downed(self)
	Helpers.give_key(subject, "sec_card", "Security room", Keychain.CARD)
	Helpers.give_key(subject, "office_key", "Office bay", Keychain.KEY)
	await _open(subject)
	Helpers.give_key(_user, "warehouse", "Warehouse office", Keychain.KEY)
	_screen.refresh()
	var rows := _rows(_screen.their_keys)
	(
		assert_array(rows.map(func(row: LootKeyRow) -> StringName: return row.icon_node.kind))
		. contains_exactly([Keychain.CARD, Keychain.KEY])
	)

	rows[0].pressed.emit()

	assert_str(_screen.notice_label.text).is_equal("Keycard added to the keychain: Security room")
	assert_int(_rows(_screen.their_keys).size()).is_equal(1)
	var yours := _rows(_screen.your_keys)
	(
		assert_array(yours.map(func(row: LootKeyRow) -> String: return row.key_id()))
		. contains_exactly(["warehouse", "sec_card"])
	)
	assert_str(String(yours[1].icon_node.kind)).is_equal("card")
	assert_bool(yours[1].icon_node.colour() == TabStyle.CARD).is_true()
	# Yours stay yours.
	yours[0].pressed.emit()
	assert_int(Helpers.keychain(_user).size()).is_equal(2)
	assert_str(_screen.notice_label.text).is_equal(LootRules.KEEP_KEYS)


func test_the_inventory_tab_keychain_shows_both_icons() -> void:
	var holder := Helpers.holder(self, "Holder")
	auto_free(holder)
	Helpers.give_key(holder, "office_key", "Office bay", Keychain.KEY)
	Helpers.give_key(holder, "sec_card", "Security room", Keychain.CARD)
	var list: KeychainList = auto_free(KeychainList.new())
	add_child(list)

	list.bind(Helpers.keychain(holder))

	assert_array(list.kinds()).contains_exactly([Keychain.KEY, Keychain.CARD])
	assert_array(list.names()).contains_exactly(["Office bay", "Security room"])


func test_the_players_screens_make_it() -> void:
	var player: Node = auto_free(load(PLAYER).instantiate())
	var screens := Screens.of(player)
	assert_bool(Screens.has(player, Lootable.SCREEN)).is_true()
	assert_str(screens.scenes[Lootable.SCREEN].resource_path).is_equal("res://ui/loot/loot_screen.tscn")


func _rows(box: VBoxContainer) -> Array[LootKeyRow]:
	var rows: Array[LootKeyRow] = []
	for child in box.get_children():
		if child is LootKeyRow:
			rows.append(child as LootKeyRow)
	return rows


func _open(subject: Node, user_grid: Vector2i = Vector2i(6, 5)) -> void:
	_subject = auto_free(subject)
	_user = auto_free(Helpers.holder(self, "Looter", user_grid, "You"))
	_screen = Helpers.screen_for(_user)
	assert_bool(_screen.open_screen(_subject, _user, {})).is_true()
	# Let the containers lay the grids out.
	await get_tree().process_frame
	await get_tree().process_frame
