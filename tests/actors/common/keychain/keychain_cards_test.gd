extends GdUnitTestSuite
## Integration (ADR 0142): keycards on the keychain, on minimal entities (stimulus fixtures with an
## Inventory and a Keychain). A keycard pickup goes onto the keychain as an entry of kind `card` (no
## grid space, the pickup is gone) and opens a keycard reader with its id; a key of the same id does
## not, and a card does not open a keyhole. remove() returns the entry with its kind, so add() on
## another keychain keeps it a card; saves keep the kind, and entries saved before kinds load as keys.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const KEY: ItemData = preload("res://items/key/key.tres")
const ORIGIN := Vector3(-700, 0, 300)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func test_a_keycard_pickup_goes_on_the_keychain_as_a_card_and_opens_its_reader() -> void:
	var holder := _holder("Guard")
	var reader := _reader_box(&"vault").get_node("Reader") as KeycardLock
	var body := Items.spawn_pickup(_root, Items.KEYCARD, ORIGIN + Vector3(1, 0, 0), 1, {"key_id": "vault"})
	assert_bool(reader.use_locked(holder)).is_false()

	assert_bool(Inventory.of(holder).pick_up(ItemPickup.of(body))).is_true()

	var entries := Keychain.of(holder).keys()
	assert_array(entries).has_size(1)
	assert_str(str(entries[0]["id"])).is_equal("vault")
	assert_str(String(entries[0]["kind"])).is_equal(String(Keychain.CARD))
	assert_array(Inventory.of(holder).stacks()).is_empty()
	assert_bool(ItemPickup.of(body).count <= 0 or body.is_queued_for_deletion()).is_true()
	assert_bool(reader.grants_passage(holder)).is_true()
	assert_bool(reader.use_locked(holder)).is_true()
	assert_str(str(EventLog.find(&"lock.granted")[0].data["how"])).is_equal("keycard")


func test_a_key_does_not_swipe_and_a_card_does_not_turn_a_keyhole() -> void:
	var holder := _holder("Holder")
	var reader := _reader_box(&"vault").get_node("Reader") as KeycardLock
	Inventory.of(holder).add(KEY, 1, {ItemStack.KEY_ID: "vault"})

	assert_bool(reader.use_locked(holder)).is_false()
	assert_bool(Keychain.of(holder).has_key(&"vault")).is_true()
	assert_bool(Keychain.of(holder).has_key(&"vault", Keychain.CARD)).is_false()


func test_remove_returns_the_entry_and_add_keeps_its_kind() -> void:
	var body := _holder("Body")
	var looter := _holder("Looter")
	Inventory.of(body).add(Items.KEYCARD, 1, {ItemStack.KEY_ID: "vault", ItemStack.KEY_NAME: "Vault card"})

	var entry := Keychain.of(body).remove(&"vault")

	assert_str(str(entry["id"])).is_equal("vault")
	assert_str(str(entry["name"])).is_equal("Vault card")
	assert_str(String(entry["kind"])).is_equal(String(Keychain.CARD))
	assert_int(Keychain.of(body).size()).is_equal(0)
	assert_dict(Keychain.of(body).remove(&"vault")).is_empty()
	var added := Keychain.of(looter).add(
		StringName(str(entry["id"])), str(entry["name"]), str(entry["found"]), StringName(str(entry["kind"]))
	)
	assert_bool(added).is_true()
	assert_bool(Keychain.of(looter).has_key(&"vault", Keychain.CARD)).is_true()
	assert_array(EventLog.find(&"keychain.key_removed")).has_size(1)


func test_saves_keep_the_kind_and_old_entries_load_as_keys() -> void:
	var holder := _holder("Holder")
	Keychain.of(holder).add(&"vault", "Vault card", "", Keychain.CARD)
	var copy := Keychain.of(_holder("Copy"))

	copy.load_state(Keychain.of(holder).save_state())

	assert_bool(copy.has_key(&"vault", Keychain.CARD)).is_true()
	copy.load_state({"keys": [{"id": "gate", "name": "Gate padlock", "found": ""}]})
	assert_bool(copy.has_key(&"gate", Keychain.KEY)).is_true()


# A minimal entity with an Inventory and a Keychain.
func _holder(holder_name: String) -> Node3D:
	var entity := Node3D.new()
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	entity.add_child(inventory)
	var keychain := Keychain.new()
	keychain.name = "Keychain"
	entity.add_child(keychain)
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
