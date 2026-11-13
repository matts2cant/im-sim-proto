extends GdUnitTestSuite
## Integration (ADR 0142): Lootable on minimal entities and the container props. A character (it has
## BodyParts) is lootable only while down (unconscious or dead), anything else at any time; a locked
## Lockable keeps it shut until a lock lets the user in (its key on the user's Keychain through E, or
## a pick); the user needs an Inventory, and E (use()) opens the user's loot screen on the entity
## (a stand-in answering to Lootable.SCREEN) only when the user has that screen. The containers are
## prop scenes (crate, locker, desk drawers) composing Inventory, Keychain, ItemLoadout and Lootable.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const LootScreen := preload("res://tests/items/inventory/fixtures/loot_screen_stand_in.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const KEY: ItemData = preload("res://items/key/key.tres")
const CRATE: PackedScene = preload("res://objects/containers/supply_crate.tscn")
const LOCKER: PackedScene = preload("res://objects/containers/locker.tscn")
const DRAWERS: PackedScene = preload("res://objects/containers/desk_drawers.tscn")
const ORIGIN := Vector3(-660, 0, -240)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func test_a_downed_character_with_an_inventory_is_lootable_and_a_standing_one_is_not() -> void:
	var body := _character("Body", ORIGIN)
	_add_loot(body)
	var looter := _looter("Looter")

	assert_bool(Lootable.of(body).can_loot(looter)).is_false()
	ActorState.set_tag(body, ActorState.UNCONSCIOUS, true)
	assert_bool(Lootable.of(body).can_loot(looter)).is_true()
	ActorState.set_tag(body, ActorState.UNCONSCIOUS, false)
	ActorState.set_tag(body, ActorState.DEAD, true)
	assert_bool(Lootable.of(body).can_loot(looter)).is_true()
	# Not by itself, nor by a character without an Inventory.
	assert_bool(Lootable.of(body).can_loot(body)).is_false()
	var empty_handed := _character("EmptyHanded", ORIGIN + Vector3(3, 0, 0))
	assert_bool(Lootable.of(body).can_loot(empty_handed)).is_false()


func test_e_opens_the_loot_screen_on_the_entity_only_for_a_user_with_one() -> void:
	var crate := _container(CRATE, "Crate")
	var looter := _looter("Looter")
	var lootable := Lootable.of(crate)
	assert_bool(lootable.can_loot(looter)).is_true()
	assert_bool(lootable.available(looter)).is_false()
	assert_bool(lootable.use(looter)).is_false()

	var screen := LootScreen.add_to(looter) as LootScreen
	assert_bool(lootable.available(looter)).is_true()
	assert_bool(lootable.use(looter)).is_true()

	assert_object(screen.subject).is_same(crate)
	assert_object(screen.opened_by).is_same(looter)
	assert_bool(Screens.is_open(looter, Lootable.SCREEN, crate)).is_true()
	var opened := EventLog.find(&"loot.opened")
	assert_array(opened).has_size(1)
	assert_str(str(opened[0].data["entity"])).is_equal("Crate")


func test_a_locked_container_opens_only_with_its_key_on_the_keychain() -> void:
	var locker := _container(LOCKER, "Locker", &"locker_a")
	var looter := _looter("Looter")
	var screen := LootScreen.add_to(looter) as LootScreen
	var lootable := Lootable.of(locker)
	assert_bool(Lockable.of(locker).locked).is_true()

	assert_bool(lootable.can_loot(looter)).is_false()
	assert_bool(lootable.available(looter)).is_true()
	assert_str(lootable.prompt(looter)).is_equal("Locked: key or lockpick")
	assert_bool(lootable.use(looter)).is_false()
	assert_str(lootable.refusal(looter)).is_equal("Locked: needs a key or a lockpick")
	# A card with the same id is not its key.
	Keychain.of(looter).add(&"locker_a", "Locker card", "", Keychain.CARD)
	assert_bool(lootable.use(looter)).is_false()
	Keychain.of(looter).remove(&"locker_a")
	Inventory.of(looter).add(KEY, 1, {ItemStack.KEY_ID: "locker_a", ItemStack.KEY_NAME: "Locker key"})

	assert_bool(lootable.use(looter)).is_true()

	assert_bool(Lockable.of(locker).locked).is_false()
	assert_object(screen.subject).is_same(locker)
	assert_bool(lootable.can_loot(looter)).is_true()
	assert_str(str(EventLog.find(&"lock.unlocked")[0].data["how"])).is_equal("key")


func test_a_picked_container_is_lootable() -> void:
	var drawers := _container(DRAWERS, "Drawers")
	var looter := _looter("Looter")
	var lootable := Lootable.of(drawers)
	Lockable.of(drawers).lock(null, &"test")
	assert_bool(lootable.can_loot(looter)).is_false()

	var lock := Lock.locks_of(drawers)[0] as MechanicalLock
	assert_bool(lock.accepts_tool(&"lockpick")).is_true()
	assert_bool(lock.complete_pick(looter)).is_true()

	assert_bool(lootable.can_loot(looter)).is_true()


func test_every_container_composes_the_loot_components() -> void:
	for scene: PackedScene in [CRATE, LOCKER, DRAWERS]:
		var container := scene.instantiate()
		assert_object(Inventory.of(container)).is_not_null()
		assert_object(Keychain.of(container)).is_not_null()
		assert_object(ItemLoadout.of(container)).is_not_null()
		assert_object(Lootable.of(container)).is_not_null()
		assert_bool(container.has_meta(EntityNames.META)).is_true()
		assert_int((container as CollisionObject3D).collision_layer & PhysicsLayers.INTERACT_MASK).is_not_zero()
		container.free()


# A minimal character (BodyParts, Tags) at `feet`.
func _character(character_name: String, feet: Vector3) -> CharacterBody3D:
	var body := Characters.character(_root, character_name, feet, [])
	body.set_physics_process(false)
	return body


# Gives `entity` an Inventory and a Lootable.
func _add_loot(entity: Node) -> void:
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	entity.add_child(inventory)
	var lootable := Lootable.new()
	lootable.name = "Lootable"
	entity.add_child(lootable)


# A minimal character with an Inventory and a Keychain.
func _looter(looter_name: String) -> CharacterBody3D:
	var looter := _character(looter_name, ORIGIN + Vector3(0, 0, 2))
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	looter.add_child(inventory)
	var keychain := Keychain.new()
	keychain.name = "Keychain"
	looter.add_child(keychain)
	return looter


# A container prop under the root; `key_id`: the id of the key its lock takes (its own lock data).
func _container(scene: PackedScene, container_name: String, key_id: StringName = &"") -> Node3D:
	var container := scene.instantiate() as Node3D
	container.name = container_name
	container.position = ORIGIN + Vector3(0, 0, -2)
	if not String(key_id).is_empty():
		var lock := Lock.locks_of(container)[0] as MechanicalLock
		lock.data = lock.data.duplicate() as MechanicalLockData
		lock.data.key_id = key_id
	_root.add_child(container)
	return container
