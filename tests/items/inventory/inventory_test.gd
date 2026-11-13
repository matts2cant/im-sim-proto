extends GdUnitTestSuite
## Integration (ADR 0139): the Inventory component on minimal non-player entities (stimulus fixtures
## with an Inventory child): found with Inventory.of(), its queries (stacks, count, key ids), add /
## take / remove, a key going onto the holder's Keychain, its own save (saveable unless the entity
## saves it), and a keycard reader opening for a carried keycard. The player's layer over it (belt,
## hand) is in player_inventory_test.gd.

const Items := preload("res://tests/items/item_test_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const KEY: ItemData = preload("res://items/key/key.tres")
const ORIGIN := Vector3(-640, 0, 220)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func test_any_entity_finds_its_inventory_and_counts_what_it_carries() -> void:
	var holder := _holder("Guard")
	var bare := Fixtures.entity(_root, "Bare", ORIGIN + Vector3(2, 0, 0), [])
	var inventory := Inventory.of(holder)

	assert_object(inventory).is_not_null()
	assert_object(Inventory.of(bare)).is_null()
	assert_object(Inventory.of(null)).is_null()
	assert_object(inventory.entity).is_same(holder)
	assert_int(inventory.add(Items.AMMO, 25)).is_equal(0)
	assert_int(inventory.add(Items.PISTOL, 1)).is_equal(0)

	assert_int(inventory.count(Items.AMMO)).is_equal(25)
	assert_int(inventory.count(Items.PISTOL)).is_equal(1)
	assert_int(inventory.count(Items.MEDKIT)).is_equal(0)
	assert_int(inventory.stacks().size()).is_equal(2)
	assert_bool(inventory.has(inventory.stacks()[0])).is_true()
	assert_bool(inventory.has(ItemStack.new(Items.AMMO, 1))).is_false()


func test_take_and_remove_change_the_count_and_report_what_moved() -> void:
	var inventory := Inventory.of(_holder("Guard"))
	inventory.add(Items.AMMO, 30)
	var removed: Array[ItemStack] = []
	inventory.stack_removed.connect(func(stack: ItemStack) -> void: removed.append(stack))

	assert_int(inventory.take(Items.AMMO, 12)).is_equal(12)
	assert_int(inventory.count(Items.AMMO)).is_equal(18)
	assert_int(inventory.take(Items.AMMO, 40)).is_equal(18)
	assert_int(inventory.count(Items.AMMO)).is_equal(0)
	assert_array(removed).has_size(1)
	inventory.add(Items.MEDKIT, 2)
	assert_int(inventory.remove(inventory.stacks()[0], 1)).is_equal(1)
	assert_int(inventory.count(Items.MEDKIT)).is_equal(1)


func test_keycards_give_their_key_ids_and_keys_go_on_the_keychain() -> void:
	var holder := _holder("Guard", true)
	var inventory := Inventory.of(holder)
	inventory.add(Items.KEYCARD, 1, {ItemStack.KEY_ID: "vault"})
	inventory.add(Items.MEDKIT, 1)

	assert_int(inventory.add(KEY, 1, {ItemStack.KEY_ID: "gate", ItemStack.KEY_NAME: "Gate padlock"})).is_equal(0)

	assert_array(inventory.key_ids()).contains_exactly(["vault"])
	assert_bool(Keychain.of(holder).has_key(&"gate")).is_true()
	assert_int(inventory.count(KEY)).is_equal(0)
	# Without a keychain a key does not fit anywhere.
	var other := Inventory.of(_holder("Other"))
	assert_int(other.add(KEY, 1, {ItemStack.KEY_ID: "gate"})).is_equal(1)


func test_a_keycard_carried_by_a_minimal_character_opens_its_reader() -> void:
	var box := _reader_box(&"vault")
	var reader := box.get_node("Reader") as KeycardLock
	var guard := _holder("Guard")
	var stranger := _holder("Stranger")
	Inventory.of(stranger).add(Items.KEYCARD, 1, {ItemStack.KEY_ID: "office"})

	assert_bool(reader.use_locked(guard)).is_false()
	Inventory.of(guard).add(Items.KEYCARD, 1, {ItemStack.KEY_ID: "vault"})

	assert_bool(reader.use_locked(stranger)).is_false()
	assert_bool(reader.grants_passage(guard)).is_true()
	assert_bool(reader.use_locked(guard)).is_true()
	assert_str(String(EventLog.find(&"lock.granted")[0].data["how"])).is_equal("keycard")


func test_saves_its_stacks_unless_the_entity_saves_it() -> void:
	var inventory := Inventory.of(_holder("Guard"))
	inventory.add(Items.PISTOL, 1, {ItemStack.MAGAZINE: 4})
	inventory.add(Items.AMMO, 7)
	inventory.weapon_state(inventory.stacks()[0]).magazine = 3
	var saved := inventory.save_state()
	var copy := Inventory.of(_holder("Copy"))

	copy.load_state(saved)

	assert_bool(inventory.is_in_group(LevelSnapshot.GROUP)).is_true()
	assert_int(copy.count(Items.AMMO)).is_equal(7)
	assert_int(copy.weapon_state(copy.stacks()[0]).magazine).is_equal(3)
	var owned := Inventory.new()
	owned.config = CONFIG
	owned.saved_by_entity = true
	Fixtures.entity(_root, "Owner", ORIGIN, []).add_child(owned)
	assert_bool(owned.is_in_group(LevelSnapshot.GROUP)).is_false()


# A minimal entity (Tags, Attributes, StimulusReceiver) with an Inventory and optionally a Keychain.
func _holder(holder_name: String, keychain: bool = false) -> Node3D:
	var entity := Node3D.new()
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = CONFIG
	entity.add_child(inventory)
	if keychain:
		var keys := Keychain.new()
		keys.name = "Keychain"
		entity.add_child(keys)
	return Fixtures.compose(entity, _root, holder_name, ORIGIN, [])


# A locked minimal entity with a keycard reader for `access_id`.
func _reader_box(access_id: StringName) -> Node3D:
	var box := Node3D.new()
	var lockable := Lockable.new()
	lockable.name = "Lockable"
	lockable.locked = true
	box.add_child(lockable)
	var reader := KeycardLock.new()
	reader.name = "Reader"
	reader.data = KeycardLockData.new()
	reader.data.access_id = access_id
	box.add_child(reader)
	return Fixtures.compose(box, _root, "Box", ORIGIN + Vector3(0, 0, -2), [])
