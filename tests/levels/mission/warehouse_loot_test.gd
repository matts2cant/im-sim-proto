extends GdUnitTestSuite
## Warehouse loot (design/levels/mission-warehouse.md "Loot (M14d)", ADR 0142): guards carry one
## magazine of their weapon's ammo; the keycards and the office bay key moved from tables onto guards
## (no pickup names them any more); every key a lock names (doors, the office bay, containers) is
## carried by someone or lies somewhere, never only inside what it opens; each container
## (`Population/People/Containers`, tools/level_gen/warehouse_people.py) stands on the floor with
## its loot, its box overlapping nothing and 1.2 m clear in front; the M14c grenades moved into
## containers are there; G8's key opens his locker. Reachability on foot: warehouse_people_test
## (containers), warehouse_doors_test (the key graph). The populated level is loaded once (no
## navmesh).

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const LootStandIn := preload("res://tests/items/inventory/fixtures/loot_screen_stand_in.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const PEOPLE := "Population/People/"
## Keys and keycards on guards: guard -> [key id, kind].
const GUARD_KEYS: Dictionary[String, Array] = {
	"G6BreakRoom": [&"warehouse_security", Keychain.CARD],
	"G7VaultDoor": [&"warehouse_vault", Keychain.CARD],
	"G8OffDuty": [&"warehouse_locker", Keychain.KEY],
	"G10CatwalkWest": [&"warehouse_bay", Keychain.KEY],
}
## Container -> [item id -> count] (keys aside), locked.
const CONTAINERS: Dictionary[String, Array] = {
	"SupplyCrateDock": [{&"frag_grenade": 1, &"pistol_ammo": 10, &"rifle_rounds": 15}, false],
	"SupplyCrateStore": [{&"medkit": 1, &"pistol_ammo": 10, &"shotgun_shells": 6}, false],
	"SupplyCrateBackStrip": [{&"medkit": 1, &"pistol_ammo": 10}, false],
	"LockerOffDuty": [{&"gas_grenade": 1, &"medkit": 1, &"pistol_ammo": 10}, true],
	"LockerSpare": [{&"shotgun_shells": 6}, false],
	"DrawersManager": [{&"jamming_grenade": 1}, false],
	"DrawersOffice": [{&"medkit": 1, &"pistol_ammo": 6}, false],
}
const CLEAR_IN_FRONT := 1.2

var _level: Node3D


func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_every_guard_carries_one_magazine_of_its_weapon() -> void:
	var guards := _level.get_node(PEOPLE + "Guards").get_children()
	assert_int(guards.size()).is_equal(10)
	for guard in guards:
		var inventory := Inventory.of(guard)
		var holder := guard.get_node("Aim/WeaponHolder") as WeaponHolder
		var weapon := holder.weapons[0]
		if not weapon.uses_ammo():
			assert_array(inventory.stacks()).override_failure_message(guard.name).is_empty()
			continue
		var ammo := ItemCatalog.default().find(weapon.ammo_item)
		assert_int(inventory.count(ammo)).override_failure_message("%s: %s" % [guard.name, weapon.ammo_item]).is_equal(
			weapon.magazine_size
		)


func test_the_keycards_and_the_bay_key_moved_from_tables_onto_guards() -> void:
	for guard_name: String in GUARD_KEYS:
		var spec: Array = GUARD_KEYS[guard_name]
		var keychain := Keychain.of(_level.get_node(PEOPLE + "Guards/" + guard_name))
		(
			assert_bool(keychain.has_key(spec[0], spec[1]))
			. override_failure_message("%s lacks %s" % [guard_name, spec[0]])
			. is_true()
		)
		for node in _level.find_children("*", "ItemPickup", true, false):
			(
				assert_str(str((node as ItemPickup).state.get(ItemStack.KEY_ID, "")))
				. override_failure_message("%s still lies at %s" % [spec[0], node.get_parent().name])
				. is_not_equal(String(spec[0]))
			)


func test_every_key_a_lock_names_is_carried_or_lies_outside_what_it_opens() -> void:
	var missing: PackedStringArray = []
	var locks := 0
	for node in _level.find_children("*", "", true, false):
		var key_id := &""
		if node is KeycardLock:
			key_id = (node as KeycardLock).access_id()
		elif node is MechanicalLock:
			key_id = (node as MechanicalLock).data.key_id
		if key_id.is_empty():
			continue
		locks += 1
		var locked_thing := Entities.of_component(node)
		var holders := _key_holders(key_id)
		holders.erase(locked_thing)
		if holders.is_empty():
			missing.append("%s (%s)" % [key_id, locked_thing.name])
	# Security and vault doors' readers, the office bay, the second office, G8's locker.
	assert_int(locks).is_greater_equal(5)
	assert_array(Array(missing)).is_empty()


func test_containers_stand_on_the_floor_with_their_loot_and_room_in_front() -> void:
	var space := _level.get_world_3d().direct_space_state
	var containers := _level.get_node(PEOPLE + "Containers")
	assert_int(containers.get_child_count()).is_equal(CONTAINERS.size())
	for name: String in CONTAINERS:
		var container := containers.get_node(name) as StaticBody3D
		var spec: Array = CONTAINERS[name]
		var inventory := Inventory.of(container)
		var contents: Dictionary = spec[0]
		for id: StringName in contents:
			assert_int(inventory.grid.count_of(id)).override_failure_message("%s: %s" % [name, id]).is_equal(
				int(contents[id])
			)
		var lockable := Lockable.of(container)
		assert_bool(lockable != null and lockable.locked).override_failure_message(name).is_equal(spec[1])
		# The floor under its middle, within 2 cm.
		var down := PhysicsRayQueryParameters3D.create(
			container.global_position + Vector3.UP * 0.1, container.global_position + Vector3.DOWN * 0.3
		)
		down.exclude = [container.get_rid()]
		var hit := space.intersect_ray(down)
		assert_bool(hit.is_empty()).override_failure_message("%s floats" % name).is_false()
		assert_float((hit["position"] as Vector3).y).override_failure_message(name).is_equal_approx(
			container.global_position.y, 0.02
		)
		# Its box, shrunk 1 cm, overlaps nothing (walls, furniture, props).
		var size := _box_size(container)
		var box := BoxShape3D.new()
		box.size = size - Vector3.ONE * 0.02
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = box
		query.transform = Transform3D(container.global_basis, container.global_transform * Vector3(0, size.y * 0.5, 0))
		query.exclude = [container.get_rid()]
		assert_array(_names(space.intersect_shape(query))).override_failure_message(name).is_empty()
		# 1.2 m clear in front (its +Z), its width, 0.15 to 1.85 m up: a passage to stand and search.
		var front := BoxShape3D.new()
		front.size = Vector3(size.x, 1.7, CLEAR_IN_FRONT)
		query.shape = front
		query.transform = Transform3D(
			container.global_basis,
			container.global_transform * Vector3(0, 1.0, size.z * 0.5 + 0.03 + CLEAR_IN_FRONT * 0.5)
		)
		assert_array(_names(space.intersect_shape(query))).override_failure_message("%s front" % name).is_empty()


func test_the_moved_grenades_are_in_containers_and_meshes_do_not_z_fight() -> void:
	var containers := _level.get_node(PEOPLE + "Containers")
	assert_int(Inventory.of(containers.get_node("SupplyCrateDock")).grid.count_of(&"frag_grenade")).is_equal(1)
	assert_int(Inventory.of(containers.get_node("LockerOffDuty")).grid.count_of(&"gas_grenade")).is_equal(1)
	assert_int(Inventory.of(containers.get_node("DrawersManager")).grid.count_of(&"jamming_grenade")).is_equal(1)
	# The manager's drawers also hold the second office's key.
	assert_bool(Keychain.of(containers.get_node("DrawersManager")).has_key(&"warehouse_office_two")).is_true()
	var overlaps := KitGeometry.coplanar_mesh_overlaps(containers)
	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


func test_the_off_duty_guards_key_opens_his_locker() -> void:
	var locker := _level.get_node(PEOPLE + "Containers/LockerOffDuty")
	var guard := _level.get_node(PEOPLE + "Guards/G8OffDuty")
	var user := _user()
	var lootable := Lootable.of(locker)

	assert_bool(lootable.use(user)).is_false()
	assert_bool(Lockable.of(locker).locked).is_true()
	# Taken from the guard's keychain as the loot screen does.
	assert_bool(LootRules.move_key(Keychain.of(guard), Keychain.of(user), "warehouse_locker").is_empty()).is_false()
	assert_bool(lootable.use(user)).is_true()
	assert_bool(Lockable.of(locker).locked).is_false()

	# Back as it was for the other tests of the suite.
	LootRules.move_key(Keychain.of(user), Keychain.of(guard), "warehouse_locker")
	Lockable.of(locker).lock()
	user.free()


# Where a key or keycard is: entities carrying it on their keychain, and pickups naming it.
func _key_holders(key_id: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in _level.find_children("*", "", true, false):
		if node is Keychain and (node as Keychain).has_key(key_id):
			result.append(Entities.of_component(node))
		elif node is ItemPickup and str((node as ItemPickup).state.get(ItemStack.KEY_ID, "")) == String(key_id):
			result.append(node.get_parent())
	return result


# A container's box collision size.
static func _box_size(body: CollisionObject3D) -> Vector3:
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			return (shape.shape as BoxShape3D).size
	return Vector3.ZERO


static func _names(hits: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for hit in hits:
		names.append(String((hit["collider"] as Node).name))
	return names


# A user stand-in with an Inventory, a Keychain and a loot screen stand-in.
func _user() -> Node3D:
	var entity := Node3D.new()
	var inventory := Inventory.new()
	inventory.name = "Inventory"
	inventory.config = INVENTORY_CONFIG
	entity.add_child(inventory)
	var keychain := Keychain.new()
	keychain.name = "Keychain"
	entity.add_child(keychain)
	LootStandIn.add_to(entity)
	return Fixtures.compose(entity, self, "Looter", Vector3(15, 0, 13), [])
