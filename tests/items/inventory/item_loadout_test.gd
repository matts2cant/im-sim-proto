extends GdUnitTestSuite
## Integration (ADR 0142): ItemLoadout fills its entity's Inventory once from data, on minimal
## entities (stimulus fixtures): its StartingItems (a keycard onto the Keychain), and rounds of the
## ammo of each weapon of the entity's WeaponHolder fixed loadout. Filled once, deferred after the
## entity is ready; saved, so a loaded copy is not filled again and keeps the saved contents. The
## guard scene carries its pistol's ammo by default.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const PISTOL_DATA: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const AIM: AimConfig = preload("res://actors/guard/guard_aim.tres")
const PISTOL_GUARD: PackedScene = preload("res://actors/guard/guard_pistol.tscn")
const ORIGIN := Vector3(-720, 0, -320)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func test_fills_once_from_its_items_and_its_weapons_ammo() -> void:
	var entity := _entity("Guard", _items(), 12, true)
	await get_tree().process_frame

	var inventory := Inventory.of(entity)
	var loadout := ItemLoadout.of(entity)
	assert_bool(loadout.filled).is_true()
	assert_int(inventory.count(Items.MEDKIT)).is_equal(2)
	assert_int(inventory.count(Items.AMMO)).is_equal(12)
	assert_bool(Keychain.of(entity).has_key(&"vault", Keychain.CARD)).is_true()
	assert_bool(loadout.fill()).is_false()
	assert_int(inventory.count(Items.MEDKIT)).is_equal(2)


func test_saved_filled_so_a_loaded_copy_keeps_the_saved_contents() -> void:
	var entity := _entity("Guard", _items(), 0, false)
	await get_tree().process_frame
	var inventory := Inventory.of(entity)
	inventory.take(Items.MEDKIT, 1)
	var saved_inventory := inventory.save_state()
	var saved_loadout := ItemLoadout.of(entity).save_state()

	var copy := _entity("Copy", _items(), 0, false)
	ItemLoadout.of(copy).load_state(saved_loadout)
	Inventory.of(copy).load_state(saved_inventory)
	await get_tree().process_frame

	assert_bool(ItemLoadout.of(copy).is_in_group(LevelSnapshot.GROUP)).is_true()
	assert_int(Inventory.of(copy).count(Items.MEDKIT)).is_equal(1)


func test_the_pistol_guard_carries_its_pistols_ammo() -> void:
	var guard := PISTOL_GUARD.instantiate() as Node3D
	guard.position = ORIGIN + Vector3(0, 0, -4)
	guard.process_mode = Node.PROCESS_MODE_DISABLED
	_root.add_child(guard)
	await get_tree().process_frame

	var inventory := Inventory.of(guard)
	assert_int(inventory.count(Items.AMMO)).is_equal(ItemLoadout.of(guard).weapon_ammo)
	assert_int(inventory.count(Items.AMMO)).is_greater(0)
	assert_object(Lootable.of(guard)).is_not_null()
	assert_object(Keychain.of(guard)).is_not_null()


func _items() -> Array[StartingItem]:
	var medkits := StartingItem.new()
	medkits.item = Items.MEDKIT
	medkits.count = 2
	var card := StartingItem.new()
	card.item = Items.KEYCARD
	card.state = {ItemStack.KEY_ID: "vault"}
	return [medkits, card]


# A minimal entity with an Inventory, a Keychain, an ItemLoadout and (`armed`) a WeaponHolder with
# the pistol.
func _entity(entity_name: String, items: Array[StartingItem], ammo: int, armed: bool) -> Node3D:
	var entity := Node3D.new()
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	entity.add_child(inventory)
	var keychain := Keychain.new()
	keychain.name = "Keychain"
	entity.add_child(keychain)
	if armed:
		var holder := WeaponHolder.new()
		holder.name = "WeaponHolder"
		holder.weapons = [PISTOL_DATA] as Array[WeaponData]
		holder.aim_config = AIM
		entity.add_child(holder)
	var loadout := ItemLoadout.new()
	loadout.name = "ItemLoadout"
	loadout.items = items
	loadout.weapon_ammo = ammo
	loadout.holder_path = ^"../WeaponHolder" if armed else ^""
	entity.add_child(loadout)
	return Fixtures.compose(entity, _root, entity_name, ORIGIN, [])
