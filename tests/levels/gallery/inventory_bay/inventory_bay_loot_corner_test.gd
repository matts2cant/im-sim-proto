extends GdUnitTestSuite
## Inventory bay (gallery room 7), the M14d looting corner (hub-and-gallery.md, ADR 0142): on the east
## wall between the fill-the-grid table and the 60 kg crate, a supply crate with mixed items, desk
## drawers (unlocked) holding the locker's key, and a locked locker. Each stands on the floor with its
## loot, its front faces the hall with 1.2 m clear; the key chain works: a user without the key
## cannot open the locker, the key taken from the drawers (LootRules.move_key, as the screen does)
## unlocks it with E.

const ROOM_SCENE: PackedScene = preload("res://levels/gallery/inventory_bay/inventory_bay_room.tscn")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const LootStandIn := preload("res://tests/items/inventory/fixtures/loot_screen_stand_in.gd")
const INVENTORY_CONFIG: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const CONTAINERS: Array[String] = ["SupplyCrate", "DeskDrawers", "Locker"]
## Hall interior: x -6..6 (room-local); the corner's fronts face -X.
const EAST_WALL := 6.0
const CLEAR_IN_FRONT := 1.2
## Far from other suites' fixtures.
const ORIGIN := Vector3(-260, 0, 520)

var _room: Node3D


func before_test() -> void:
	EventLog.clear()
	_room = auto_free(ROOM_SCENE.instantiate()) as Node3D
	_room.position = ORIGIN
	add_child(_room)


func test_each_container_holds_its_loot() -> void:
	await get_tree().process_frame
	var crate := _container("SupplyCrate")
	var drawers := _container("DeskDrawers")
	var locker := _container("Locker")

	var crate_items := Inventory.of(crate)
	assert_int(crate_items.grid.count_of(&"medkit")).is_equal(2)
	assert_int(crate_items.grid.count_of(&"pistol_ammo")).is_equal(20)
	assert_int(crate_items.grid.count_of(&"frag_grenade")).is_equal(1)
	assert_int(crate_items.grid.count_of(&"biocell")).is_equal(1)
	assert_int(Inventory.of(drawers).grid.count_of(&"medkit")).is_equal(1)
	assert_bool(Keychain.of(drawers).has_key(&"inventory_bay_locker", Keychain.KEY)).is_true()
	var locker_items := Inventory.of(locker)
	assert_int(locker_items.grid.count_of(&"gas_grenade")).is_equal(1)
	assert_int(locker_items.grid.count_of(&"emp_grenade")).is_equal(1)
	assert_int(locker_items.grid.count_of(&"rifle_rounds")).is_equal(30)
	assert_bool(Lockable.of(crate) == null or not Lockable.of(crate).locked).is_true()
	assert_bool(Lockable.of(drawers).locked).is_false()
	assert_bool(Lockable.of(locker).locked).is_true()


func test_containers_stand_on_the_floor_against_the_east_wall_with_room_in_front() -> void:
	await KitGeometry.settle(get_tree())
	var space := _room.get_world_3d().direct_space_state

	for name: String in CONTAINERS:
		var container := _container(name) as CollisionObject3D
		var box := _box(container)
		assert_float(container.position.y).override_failure_message(name).is_equal(0.0)
		# Its front faces the hall (-X); its back stays inside the wall's inner face.
		assert_float(container.global_basis.z.x).override_failure_message(name).is_equal_approx(-1.0, 0.001)
		assert_float(box.end.x - ORIGIN.x).override_failure_message(name).is_between(EAST_WALL - 0.1, EAST_WALL)
		# The floor right under its middle.
		var down := PhysicsRayQueryParameters3D.create(
			container.global_position + Vector3.UP * 0.1, container.global_position + Vector3.DOWN * 0.5
		)
		down.exclude = [container.get_rid()]
		var hit := space.intersect_ray(down)
		assert_bool(hit.is_empty()).override_failure_message(name).is_false()
		assert_float((hit["position"] as Vector3).y).override_failure_message(name).is_equal_approx(0.0, 0.02)
		# 1.2 m clear in front (above the floor, any body).
		var front := BoxShape3D.new()
		front.size = Vector3(CLEAR_IN_FRONT, 1.7, box.size.z)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = front
		query.transform = Transform3D(
			Basis(), Vector3(box.position.x - CLEAR_IN_FRONT * 0.5 - 0.02, 1.0, box.get_center().z)
		)
		var blocked := space.intersect_shape(query)
		assert_array(blocked).override_failure_message("%s: %s" % [name, blocked]).is_empty()


func test_containers_keep_apart_from_each_other_and_the_stations() -> void:
	var boxes: Array[AABB] = []
	for name: String in CONTAINERS:
		boxes.append(_box(_container(name) as CollisionObject3D))
	var fill_grid := (_room.get_node("FillGrid/Table") as Node3D).global_position.z - 2.7
	var heavy := (_room.get_node("AbilitiesDais/LargeCrate") as Node3D).global_position.z + 0.6

	# North to south along the wall: the fill-the-grid table's end, the crate, the drawers, the
	# locker, the 60 kg crate (gaps, surface to surface).
	assert_float(fill_grid - boxes[0].end.z).is_greater(0.1)
	assert_float(boxes[0].position.z - boxes[1].end.z).is_greater(0.1)
	assert_float(boxes[1].position.z - boxes[2].end.z).is_greater(0.1)
	assert_float(boxes[2].position.z - heavy).is_greater(0.3)


func test_the_drawers_key_opens_the_locker() -> void:
	await get_tree().process_frame
	var drawers := _container("DeskDrawers")
	var locker := _container("Locker")
	var user := _user()
	var lootable := Lootable.of(locker)

	assert_bool(lootable.use(user)).is_false()
	assert_bool(Lockable.of(locker).locked).is_true()
	assert_bool(Lootable.of(drawers).can_loot(user)).is_true()

	var moved := LootRules.move_key(Keychain.of(drawers), Keychain.of(user), "inventory_bay_locker")
	assert_bool(moved.is_empty()).is_false()
	assert_bool(lootable.use(user)).is_true()

	assert_bool(Lockable.of(locker).locked).is_false()
	assert_bool(lootable.can_loot(user)).is_true()


func _container(name: String) -> Node3D:
	return _room.get_node("LootCorner/" + name) as Node3D


# A minimal user beside the corner: an Inventory, a Keychain and a loot screen stand-in.
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
	return Fixtures.compose(entity, self, "Looter", ORIGIN + Vector3(4, 0, -16), [])


# World AABB of the container's box collision shape.
static func _box(body: CollisionObject3D) -> AABB:
	for child in body.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			var size := (shape.shape as BoxShape3D).size
			return shape.global_transform * AABB(-size * 0.5, size)
	return AABB()
