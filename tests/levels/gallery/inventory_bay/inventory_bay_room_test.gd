extends GdUnitTestSuite
## Inventory bay (gallery room 7): static layout checks on the room scene (hub-and-gallery.md): the
## shell, one pickup of every catalogue item on the item table with its "Name w x h" tag, the stack
## station counts, enough bulky items to overflow the 6 x 5 grid, the datapad's text, the drop zone,
## the abilities dais, the signs and no coplanar faces.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/inventory_bay/inventory_bay_room.tscn")
const INVENTORY: InventoryConfig = preload("res://items/inventory/inventory_config.tres")
const DATAPAD_TEXT := (
	"Press I to open your inventory. Drag items to move them, right-click to use, drop or assign"
	+ " to the belt. Door code for nothing yet: 0451."
)
const SIGNS: Dictionary[String, String] = {
	"ItemTable": "Item table\nevery item · E picks up",
	"Stacks": "Stacks split at their max",
	"FillGrid": "Fill the grid · 6 × 5\nuntil: No room in inventory",
	"Datapad": "Datapad\nE takes · use it to read",
	"DropZone": "Drop things here · listen",
	"Abilities": "Skills & augmentations station — M6",
}

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())


func test_shell_is_a_12_by_16_hall_behind_a_corridor() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var corridor := _room.get_node("Shell/Corridor") as Room

	assert_vector(hall.size).is_equal(Vector3(12, 5, 16))
	assert_vector(corridor.size).is_equal(Vector3(2, 3, 3.5))
	assert_float(corridor.wall_thickness).is_equal(hall.wall_thickness)
	# Shared walls (ADR 0043): the corridor starts at the hub wall's outer face (origin) and the
	# hall's interior starts at the corridor's north wall outer face.
	assert_float(corridor.position.z + corridor.size.z * 0.5).is_equal(0.0)
	var corridor_north := corridor.position.z - corridor.size.z * 0.5 - corridor.wall_thickness
	assert_float(hall.position.z + hall.size.z * 0.5).is_equal_approx(corridor_north, 0.0001)
	var door := hall.openings[0]
	assert_int(door.wall).is_equal(RoomOpening.Wall.SOUTH)
	assert_float(hall.position.x + door.offset).is_equal_approx(0.0, 0.0001)
	assert_float(door.width).is_equal(corridor.size.x)


func test_item_table_has_one_of_every_catalogue_item_with_its_tag() -> void:
	var table := _room.get_node("ItemTable/Table") as Ledge
	assert_float(table.height).is_equal(1.0)
	assert_str(table.surface).is_equal("wood")
	var found: Dictionary[StringName, RigidBody3D] = _pickups_under("ItemTable")

	for item: ItemData in ItemCatalog.default().items:
		var body: RigidBody3D = found.get(item.id)
		assert_object(body).override_failure_message("no %s on the table" % item.id).is_not_null()
		if body == null:
			continue
		# One stack (the ammo box holds its default 10 rounds).
		assert_int(ItemPickup.of(body).count).is_between(1, item.max_stack)
		_assert_on_top(table, body)
		var tag := _room.get_node_or_null("Labels/ItemTags/" + String(body.name)) as Sign
		assert_object(tag).override_failure_message(String(item.id)).is_not_null()
		var text := "%s\n%d×%d" % [item.display_name, item.footprint.x, item.footprint.y]
		assert_str(tag.text).is_equal(text)
		# Behind its item on the wall, a little above the table.
		assert_float(tag.position.z).is_equal_approx(body.position.z, 0.0001)
	assert_int(found.size()).is_equal(ItemCatalog.default().items.size())


func test_stack_station_counts_exceed_one_stack() -> void:
	var table := _room.get_node("Stacks/Table") as Ledge
	var expected: Dictionary[StringName, int] = {&"multitool": 12, &"medkit": 16, &"pistol_ammo": 150}
	var found := _pickups_under("Stacks")

	assert_array(found.keys()).contains_exactly_in_any_order(expected.keys())
	for id: StringName in expected:
		var pickup := ItemPickup.of(found[id])
		assert_int(pickup.count).is_equal(expected[id])
		# More than one stack's worth.
		assert_int(pickup.count).is_greater(pickup.item.max_stack)
		_assert_on_top(table, found[id])


func test_fill_the_grid_overflows_a_6_by_5_inventory() -> void:
	var table := _room.get_node("FillGrid/Table") as Ledge
	var cells := 0
	var ids: Dictionary[StringName, int] = {}
	for child: Node in _room.get_node("FillGrid").get_children():
		var pickup := ItemPickup.of(child)
		if pickup == null:
			continue
		_assert_on_top(table, child as RigidBody3D)
		ids[pickup.item.id] = ids.get(pickup.item.id, 0) + 1
		var stacks := ceili(float(pickup.count) / pickup.item.max_stack)
		cells += pickup.item.footprint.x * pickup.item.footprint.y * stacks

	assert_dict(ids).is_equal({&"pistol": 6, &"baton": 6, &"pistol_ammo": 2})
	assert_int(cells).is_greater(INVENTORY.grid_size.x * INVENTORY.grid_size.y)


func test_datapad_pedestal_holds_the_inventory_bay_datapad() -> void:
	var pedestal := _room.get_node("DatapadPedestal/Pedestal") as Ledge
	var datapad := _room.get_node("DatapadPedestal/Datapad") as RigidBody3D
	var state := ItemPickup.of(datapad).stack_state()

	assert_str(String(ItemPickup.of(datapad).item.id)).is_equal("datapad")
	assert_str(state["title"]).is_equal("Inventory bay")
	assert_str(state["text"]).is_equal(DATAPAD_TEXT)
	_assert_on_top(pedestal, datapad)


func test_drop_zone_and_abilities_dais() -> void:
	var zone := _room.get_node("DropZone/Floor") as SurfaceFloor
	var dais := _room.get_node("AbilitiesDais/Dais") as Ledge
	var hall := _room.get_node("Shell/Hall") as Room

	assert_vector(zone.size).is_equal(Vector2(4, 4))
	assert_str(zone.surface).is_equal("metal")
	assert_float(zone.position.y).is_equal_approx(0.02, 0.0001)
	# A low platform (jumped onto), against the back wall.
	assert_float(dais.height).is_less(1.0)
	assert_str(dais.band).is_equal("jump up")
	var back := hall.position.z - hall.size.z * 0.5
	assert_float(dais.position.z - dais.depth).is_equal_approx(back, 0.0001)


func test_every_station_has_its_sign() -> void:
	for name: String in SIGNS:
		var sign := _room.get_node_or_null("Labels/" + name) as Sign
		assert_object(sign).override_failure_message(name).is_not_null()
		assert_str(sign.text).is_equal(SIGNS[name])


func test_no_coplanar_faces_with_different_materials() -> void:
	var room: Node3D = ROOM_SCENE.instantiate()
	add_child(room)
	auto_free(room)
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(room)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


## Item pickups directly under the station node `path`, by item id (one each).
func _pickups_under(path: String) -> Dictionary[StringName, RigidBody3D]:
	var found: Dictionary[StringName, RigidBody3D] = {}
	for child: Node in _room.get_node(path).get_children():
		var pickup := ItemPickup.of(child)
		if pickup != null:
			found[pickup.item.id] = child as RigidBody3D
	return found


## `body` (a sibling of `ledge`) rests on the ledge's top, its origin inside the top's footprint.
func _assert_on_top(ledge: Ledge, body: RigidBody3D) -> void:
	var local := ledge.transform.affine_inverse() * body.transform.origin
	var shape := (body.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
	var name := String(body.name)
	assert_float(local.y - shape.size.y * 0.5).override_failure_message(name).is_equal_approx(ledge.height, 0.001)
	assert_float(absf(local.x)).override_failure_message(name).is_less(ledge.width * 0.5 - 0.1)
	assert_bool(local.z < -0.1 and local.z > -ledge.depth + 0.1).override_failure_message(name).is_true()
