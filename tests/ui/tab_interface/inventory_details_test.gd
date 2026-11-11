extends GdUnitTestSuite
## Integration (ADR 0110): the Inventory tab's details panel (ItemDetails) for a weapon, a consumable
## and a tool, every value read from the item, weapon and skill data and the player's components:
## damage scales with the weapon class's skill, the magazine and carried ammo follow the inventory,
## a fitted silencer changes how far a shot is heard and fills the muzzle row. Plus the values with
## no holder (base data only).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const SILENCER: ItemData = preload("res://items/attachments/silencer/silencer.tres")

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_weapon_rows_come_from_the_weapon_data_and_the_player() -> void:
	await _load()
	_player.inventory.give(Items.PISTOL, 1, {"magazine": 8})
	_player.inventory.give(Items.AMMO, 30)
	var pistol := _player.inventory.inventory.stacks[0]
	var data := Items.PISTOL.weapon

	var rows := ItemDetails.rows(pistol, _player)
	assert_str(ItemDetails.value_of(rows, "Damage")).is_equal("%d ballistic" % roundi(data.damage[&"damage.ballistic"]))
	assert_str(ItemDetails.value_of(rows, "Magazine")).is_equal("8 / %d" % data.magazine_size)
	assert_str(ItemDetails.value_of(rows, "Ammo")).is_equal("Pistol ammo, 30 carried")
	assert_str(ItemDetails.value_of(rows, "Heard to")).is_equal("about %d m" % roundi(data.fire_noise))
	assert_str(ItemDetails.value_of(rows, "Muzzle")).is_equal("empty: silencer fits")
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Pistols (Untrained)")
	assert_bool(ItemDetails.uses_ammo(Items.PISTOL)).is_true()

	# The skill's damage multiplier and a fitted silencer change the rows.
	_player.skills.set_tier(&"pistols", 2)
	_player.inventory.give(SILENCER, 1)
	assert_bool(_player.inventory.attach(_player.inventory.inventory.stacks[-1], pistol)).is_true()
	_player.inventory.inventory.take(&"pistol_ammo", 10)
	rows = ItemDetails.rows(pistol, _player)
	var mult := Attributes.read(_player, &"pistol_damage_mult", 1.0)
	assert_float(mult).is_greater(1.0)
	var expected := ItemDetails.number(data.damage[&"damage.ballistic"] * mult)
	assert_str(ItemDetails.value_of(rows, "Damage")).is_equal("%s ballistic" % expected)
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Pistols (Advanced)")
	assert_str(ItemDetails.value_of(rows, "Muzzle")).is_equal(SILENCER.display_name)
	assert_str(ItemDetails.value_of(rows, "Ammo")).is_equal("Pistol ammo, 20 carried")
	var heard := roundf(_player.inventory.weapon_state(pistol).stat(&"fire_noise"))
	assert_float(heard).is_less(data.fire_noise)
	assert_str(ItemDetails.value_of(rows, "Heard to")).is_equal("about %s m" % ItemDetails.number(heard))


func test_melee_weapon_has_no_magazine_rows() -> void:
	await _load()
	_player.inventory.give(Items.BATON, 1)

	var rows := ItemDetails.rows(_player.inventory.inventory.stacks[0], _player)

	assert_str(ItemDetails.value_of(rows, "Damage")).is_equal("20 stun + 5 blunt")
	assert_str(ItemDetails.value_of(rows, "Magazine")).is_empty()
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Low-Tech (Untrained)")
	assert_bool(ItemDetails.uses_ammo(Items.BATON)).is_false()


func test_consumable_rows_scale_with_the_use_attribute() -> void:
	await _load()
	_player.inventory.give(Items.MEDKIT, 2)
	var medkit := _player.inventory.inventory.stacks[0]
	var base := Items.MEDKIT.use_stimuli[&"heal"]

	var rows := ItemDetails.rows(medkit, _player)
	assert_str(ItemDetails.value_of(rows, "Heal")).is_equal(ItemDetails.number(base))
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Medicine (Untrained)")
	assert_str(ItemDetails.value_of(rows, "Count")).is_equal("2 / %d" % Items.MEDKIT.max_stack)

	_player.skills.set_tier(&"medicine", 1)
	rows = ItemDetails.rows(medkit, _player)
	var scaled := base * Attributes.read(_player, Items.MEDKIT.use_scale_attribute, 1.0)
	assert_float(scaled).is_greater(base)
	assert_str(ItemDetails.value_of(rows, "Heal")).is_equal(ItemDetails.number(scaled))
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Medicine (Trained)")


func test_tool_rows_and_the_panel_shows_them() -> void:
	await _load()
	_player.inventory.give(Items.LOCKPICK, 3)
	var tabs := TabInterface.of(_player)
	tabs.open(0)
	var tab := tabs.current_page() as InventoryTab
	tab.select(_player.inventory.inventory.stacks[0])

	var rows := ItemDetails.rows(tab.selected_stack(), _player)
	assert_str(ItemDetails.value_of(rows, "Skill")).is_equal("Lockpicking (Untrained)")
	assert_str(ItemDetails.value_of(rows, "Count")).is_equal("3 / %d" % Items.LOCKPICK.max_stack)
	var grid := tab.detail_box.get_node("Details") as GridContainer
	assert_int(grid.get_child_count()).is_equal(rows.size() * 2)
	assert_str((grid.get_child(1) as Label).text).is_equal(rows[0][1])
	assert_str(tab.use_button.text).is_equal("Equip")
	# No ammo-type placeholder for a tool.
	assert_object(tab.detail_box.find_child("Future", false, false)).is_null()
	tabs.close()


func test_rows_without_a_holder_use_the_base_data() -> void:
	var stack := ItemStack.new(Items.KEYCARD, 1, {"key_id": "office"})
	assert_str(ItemDetails.value_of(ItemDetails.rows(stack, null), "Key")).is_equal("Office")

	var pistol := ItemStack.new(Items.PISTOL, 1, {"magazine": 4})
	var rows := ItemDetails.rows(pistol, null)
	assert_str(ItemDetails.value_of(rows, "Magazine")).is_equal("4 / %d" % Items.PISTOL.weapon.magazine_size)
	assert_str(ItemDetails.value_of(rows, "Ammo")).is_equal("Pistol ammo, 0 carried")
	assert_str(ItemDetails.value_of(rows, "Skill")).is_empty()
	assert_str(ItemDetails.number(27.5)).is_equal("27.5")
	assert_str(ItemDetails.number(30.0)).is_equal("30")


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
