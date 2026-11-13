extends GdUnitTestSuite
## Gallery room 5, the security wing (levels/gallery/security_wing/security_wing.tscn), on its own:
## the shell (entry hall on the hub wall, five 2.5 x 2.5 m closets, the camera corridor with two
## alcoves and the vault, every connection a shared wall: ADR 0043), the doorways clear for the
## player capsule (doors open) and blocked by the closed doors, each lock-row door's lock type and
## the item that opens it present (code datapad and lockpicks on the entry table, the keycard behind
## D1, the booth computer's login behind D2), the practice-lock wall holding only the practice locks and
## their signs (security_wing_practice_locks_test.gd checks the locks), signs, and no coplanar faces
## with different materials. Room-local coordinates: origin on the hub wall's outer face, +Z away
## from the hub (not turned: local axes are hub axes).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HardwareChecks := preload("res://tests/objects/door/door_hardware_checks.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/security_wing/security_wing.tscn")
const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.8
const CLOSETS: Array[String] = ["ClosetD1", "ClosetD2", "Booth", "ClosetD4", "ClosetD5"]
const LOCK_ROW: Array[String] = ["D1Keypad", "D2Mechanical", "D3Keycard", "D4Electronic", "D5Breakable"]
## The practice-lock wall: west wall (x -7.5), z 1.5..4.5, 0.5..2.5 m up, only the four practice
## locks and their signs on it.
const PRACTICE_WALL := AABB(Vector3(-7.5, 0.5, 1.5), Vector3(1.0, 2.0, 3.0))

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())
	add_child(_room)


func _shell(room_name: String) -> Room:
	return _room.get_node("Shell/" + room_name) as Room


func _door(door_name: String) -> Node3D:
	return _room.get_node("Doors/" + door_name) as Node3D


# Interior bounds of a kit Room in room-local x / z (Rect2 position x = x, y = z).
static func _interior(room: Room) -> Rect2:
	var half := Vector2(room.size.x, room.size.z) * 0.5
	return Rect2(Vector2(room.position.x, room.position.z) - half, half * 2.0)


func test_hall_on_the_hub_wall() -> void:
	var hall := _shell("Hall")
	# Interior x -7.5 .. 10.5, z 0 .. 6 (its north wall overlaps the hub's south wall), 4 m high.
	assert_vector(hall.size).is_equal(Vector3(18, 4, 6))
	assert_vector(hall.position).is_equal(Vector3(1.5, 0, 3))
	assert_float(hall.wall_thickness).is_equal(0.5)
	var from_hub := hall.openings[0]
	assert_int(from_hub.wall).is_equal(RoomOpening.Wall.NORTH)
	assert_float(hall.position.x + from_hub.offset).is_equal_approx(0.0, 0.0001)
	assert_vector(Vector2(from_hub.width, from_hub.height)).is_equal(Vector2(2, 3))


func test_closets_share_the_hall_wall_and_have_room_to_turn() -> void:
	var hall := _shell("Hall")
	var hall_south := hall.position.z + hall.size.z * 0.5 + hall.wall_thickness
	for index in CLOSETS.size():
		var closet := _shell(CLOSETS[index])
		var door := _door(LOCK_ROW[index])
		var inside := _interior(closet)
		var where := CLOSETS[index]
		assert_float(closet.wall_thickness).override_failure_message(where).is_equal(0.5)
		# At least 2.5 x 2.5 m inside, starting at the hall wall's outer face (walls overlap).
		assert_float(inside.size.x).override_failure_message(where).is_greater_equal(2.5)
		assert_float(inside.size.y).override_failure_message(where).is_greater_equal(2.5)
		assert_float(inside.position.y).override_failure_message(where).is_equal_approx(hall_south, 0.0001)
		# The same 1.2 x 2.2 m doorway in both walls, where the door stands.
		var opening := closet.openings[0]
		var hall_opening := hall.openings[index + 1]
		assert_int(opening.wall).override_failure_message(where).is_equal(RoomOpening.Wall.NORTH)
		assert_float(closet.position.x + opening.offset).override_failure_message(where).is_equal_approx(
			door.position.x, 0.0001
		)
		assert_float(hall.position.x + hall_opening.offset).override_failure_message(where).is_equal_approx(
			door.position.x, 0.0001
		)
		assert_vector(Vector2(opening.width, opening.height)).override_failure_message(where).is_equal(
			Vector2(1.2, 2.2)
		)
		# The door's wall boxes (ADR 0098: centred 0.77 m on its -X side, at most 0.06 m half-wide) are on
		# the closet's inside face, and its pocket (1.95 m on its +X side) ends before the next doorway.
		var box_edge := 0.6 + DoorLayout.BOX_COLUMN + 0.06
		assert_float(door.position.x - box_edge).override_failure_message(where).is_greater_equal(inside.position.x)
		if index + 1 < LOCK_ROW.size():
			assert_float(door.position.x + 1.95).is_less(_door(LOCK_ROW[index + 1]).position.x - 0.6)
	# Neighbouring closets share their side walls.
	for index in range(1, CLOSETS.size()):
		var west := _interior(_shell(CLOSETS[index - 1]))
		var east := _interior(_shell(CLOSETS[index]))
		assert_float(east.position.x - west.end.x).is_equal_approx(0.5, 0.0001)


func test_corridor_alcoves_and_vault_share_walls() -> void:
	var hall := _shell("Hall")
	var corridor := _shell("Corridor")
	var vault := _shell("Vault")
	var lane := _interior(corridor)
	# Corridor interior x 7.5 .. 10.5, z 6.5 .. 18: from the hall's south wall to the vault's.
	assert_float(lane.position.y).is_equal_approx(hall.position.z + hall.size.z * 0.5 + 0.5, 0.0001)
	assert_float(lane.position.x).is_equal_approx(_interior(_shell("ClosetD5")).end.x + 0.5, 0.0001)
	assert_float(lane.size.x).is_greater_equal(3.0)
	assert_float(lane.size.y).is_greater(10.0)
	assert_float(hall.position.x + hall.openings[6].offset).is_equal_approx(corridor.position.x, 0.0001)
	for alcove_name: String in ["Alcove1", "Alcove2"]:
		var alcove := _shell(alcove_name)
		var inside := _interior(alcove)
		# Its east wall is the corridor's west wall; the opening spans its whole width.
		assert_float(inside.end.x + 0.5).override_failure_message(alcove_name).is_equal_approx(lane.position.x, 0.0001)
		assert_float(alcove.openings[0].width).is_equal_approx(inside.size.y, 0.0001)
		assert_float(alcove.size.y).override_failure_message(alcove_name).is_greater_equal(2.0)
	var into_vault := corridor.openings[3]
	var from_corridor := vault.openings[0]
	assert_int(into_vault.wall).is_equal(RoomOpening.Wall.SOUTH)
	assert_float(_interior(vault).position.y).is_equal_approx(lane.end.y + 0.5, 0.0001)
	var door_x := _door("VaultDoor").position.x
	assert_float(corridor.position.x + into_vault.offset).is_equal_approx(door_x, 0.0001)
	assert_float(vault.position.x + from_corridor.offset).is_equal_approx(door_x, 0.0001)


func test_footprint_stays_inside_the_free_space() -> void:
	# Outer wall faces, room-local: x -8 .. 11 and z -0.5 .. 22.5 (hub x -0.5 .. 18.5, z 15 .. 38).
	for room: Node in _room.get_node("Shell").get_children():
		var kit_room := room as Room
		if kit_room == null:
			continue
		var outer := _interior(kit_room).grow(kit_room.wall_thickness)
		assert_float(outer.position.x).override_failure_message(room.name).is_greater_equal(-8.0 - 0.0001)
		assert_float(outer.end.x).override_failure_message(room.name).is_less_equal(11.0 + 0.0001)
		assert_float(outer.position.y).override_failure_message(room.name).is_greater_equal(-0.5 - 0.0001)
		assert_float(outer.end.y).override_failure_message(room.name).is_less_equal(22.5 + 0.0001)


func test_doorways_clear_with_the_doors_open_and_blocked_when_closed() -> void:
	await KitGeometry.settle(get_tree(), 5)
	assert_bool(_blocked(Vector3(0, 0, 0), Vector3.BACK)).override_failure_message("hub door").is_false()
	assert_bool(_blocked(Vector3(9, 0, 6.25), Vector3.BACK)).override_failure_message("corridor mouth").is_false()
	for spot: Vector3 in [Vector3(7.25, 0, 10.3), Vector3(7.25, 0, 14.9)]:
		assert_bool(_blocked(spot, Vector3.LEFT, 0.9)).override_failure_message("alcove %s" % spot).is_false()
	# A solid stretch of the lock-row wall (between D1 and D2) and of the corridor's west wall.
	assert_bool(_blocked(Vector3(-4.9, 0, 6.25), Vector3.BACK)).override_failure_message("lock-row wall").is_true()
	assert_bool(_blocked(Vector3(7.25, 0, 12.6), Vector3.LEFT, 0.9)).override_failure_message("corridor wall").is_true()
	var doors: Array[String] = LOCK_ROW.duplicate()
	doors.append("VaultDoor")
	for door_name in doors:
		var feet := _door(door_name).position
		assert_bool(_blocked(feet, Vector3.BACK)).override_failure_message(door_name + " closed").is_true()
		Door.of(_door(door_name)).open()
	await KitGeometry.settle(get_tree(), 50)
	for door_name in doors:
		var feet := _door(door_name).position
		assert_bool(_blocked(feet, Vector3.BACK)).override_failure_message(door_name + " open").is_false()


func test_each_lock_row_door_has_its_lock() -> void:
	await KitGeometry.settle(get_tree(), 2)
	var expected: Dictionary[String, String] = {
		"D1Keypad": "Locked: keypad",
		"D2Mechanical": "Locked: lockpick",
		"D3Keycard": "Locked: keycard",
		"D4Electronic": "Locked: electronic",
		"D5Breakable": "Locked",
		"VaultDoor": "Locked: electronic",
	}
	for door_name: String in expected:
		var door := Door.of(_door(door_name))
		assert_bool(door.is_locked()).override_failure_message(door_name).is_true()
		assert_str(door.prompt(null)).override_failure_message(door_name).is_equal(expected[door_name])
		assert_float(door.wall_thickness).override_failure_message(door_name).is_equal(0.5)
	var keypad := _door("D1Keypad").get_node("KeypadLock") as KeypadLock
	assert_str(String(keypad.code_id())).is_equal("security_closet")
	assert_int((_door("D2Mechanical").get_node("MechanicalLock") as MechanicalLock).pin_count()).is_equal(3)
	var keycard := _door("D3Keycard").get_node("KeycardLock") as KeycardLock
	assert_str(String(keycard.access_id())).is_equal("security_booth")
	# D4 is fail-safe on breaker A's circuit; the vault door fail-secure on breaker B's.
	var d4 := _door("D4Electronic")
	assert_bool((d4.get_node("Tags") as Tags).has(ElectronicLock.FAIL_SAFE)).is_true()
	assert_str(String(Powered.of(d4.get_node("Hardware/Controller")).circuit)).is_equal(
		String(_breaker("BreakerA").circuit)
	)
	var vault := _door("VaultDoor")
	assert_bool((vault.get_node("Tags") as Tags).has(ElectronicLock.FAIL_SECURE)).is_true()
	assert_str(String(Powered.of(vault.get_node("Hardware/Controller")).circuit)).is_equal(
		String(_breaker("BreakerB").circuit)
	)
	assert_object(Breakable.of(_door("D5Breakable"))).is_not_null()


func test_door_hardware_sits_flush_beside_every_frame() -> void:
	# ADR 0098: the keypad, reader and status boxes flush on the closet and vault walls on both faces,
	# inside no wall and clear of the leaves' sweeps; D2's keyholes on both faces of its handle.
	await KitGeometry.settle(get_tree(), 5)
	var problems: PackedStringArray = []
	for entity: Node in _room.get_node("Doors").get_children():
		problems.append_array(HardwareChecks.problems(Door.of(entity)))
	assert_array(problems).is_empty()
	assert_int(_door("D2Mechanical").get_node("HandleMesh").get_child_count()).is_equal(2)
	for door_name: String in ["D1Keypad", "D3Keycard", "D4Electronic", "VaultDoor"]:
		(
			assert_int(Door.of(_door(door_name)).hardware.controls(true).size())
			. override_failure_message(door_name)
			. is_equal(1)
		)


func test_what_opens_each_door_is_in_the_room() -> void:
	# D1's code on the datapad on the entry table.
	var code := _readable("ClosetCode")
	var keypad := _door("D1Keypad").get_node("KeypadLock") as KeypadLock
	assert_str(code.codes.get(keypad.code_id(), "")).is_equal(keypad.data.code)
	assert_bool(_inside(_room.get_node("Items/ClosetCode"), _hall_rect())).is_true()
	# Lockpicks for D2 on the same table.
	var picks := ItemPickup.of(_room.get_node("Items/Lockpick"))
	assert_str(String(picks.item.id)).is_equal("lockpick")
	assert_int(picks.count).is_greater_equal(1)
	assert_bool(_inside(_room.get_node("Items/Lockpick"), _hall_rect())).is_true()
	# D3's keycard behind D1.
	var card := ItemPickup.of(_room.get_node("Items/Keycard"))
	var reader := _door("D3Keycard").get_node("KeycardLock") as KeycardLock
	assert_str(String(card.stack_state().get("key_id", ""))).is_equal(String(reader.access_id()))
	assert_bool(_inside(_room.get_node("Items/Keycard"), _interior(_shell("ClosetD1")))).is_true()
	# The booth computer's login behind D2 (the computer itself is in the booth behind D3): one of its
	# accounts.
	var login := _readable("BoothLogin")
	var computer := Computer.of(_room.get_node("Devices/BoothComputer"))
	var known := LoginCredentials.parse(login.codes.get(computer.credentials_id, ""))
	var account := computer.account(known.user)
	assert_object(account).is_not_null()
	assert_str(known.password).is_equal(account.password)
	assert_bool(_inside(_room.get_node("Items/BoothLogin"), _interior(_shell("ClosetD2")))).is_true()
	assert_bool(_inside(_room.get_node("Devices/BoothComputer"), _interior(_shell("Booth")).grow(0.05))).is_true()
	assert_bool(_inside(_room.get_node("Devices/BreakerB"), _interior(_shell("Booth")).grow(0.05))).is_true()
	# Breaker A in the entry hall; the barrel within 2 m of D5 (its blast breaks the door).
	assert_bool(_inside(_room.get_node("Devices/BreakerA"), _hall_rect().grow(0.05))).is_true()
	var barrel := (_room.get_node("Props/Barrel") as Node3D).position
	assert_float(barrel.distance_to(_door("D5Breakable").position + Vector3.UP * 1.1)).is_less(1.8)
	# Rewards behind D4 and D5 and in the vault.
	assert_bool(_inside(_room.get_node("Items/BiocellsD4"), _interior(_shell("ClosetD4")))).is_true()
	assert_bool(_inside(_room.get_node("Items/MedkitD5"), _interior(_shell("ClosetD5")))).is_true()
	for item_name: String in ["VaultBiocells", "VaultMedkits", "VaultAmmo"]:
		assert_bool(_inside(_room.get_node("Items/" + item_name), _interior(_shell("Vault")))).is_true()


func test_datapads_have_unique_entries() -> void:
	var ids: Array[StringName] = []
	for item_name: String in ["ClosetCode", "BoothLogin"]:
		var readable := _readable(item_name)
		assert_str(String(readable.entry_id)).starts_with("gallery.security_wing.")
		assert_bool(ids.has(readable.entry_id)).is_false()
		ids.append(readable.entry_id)
	# The keypad code id is new (the inventory bay's "Storage access" keeps `storage_door`).
	assert_bool(_readable("ClosetCode").codes.has(&"storage_door")).is_false()


func test_practice_lock_wall_holds_only_the_practice_locks() -> void:
	var practice: Array[Node] = []
	for child: Node in _room.find_children("*", "Node3D", true, false):
		if child.get_parent() == _room.get_node("Shell") or child is Room or child is Sign:
			continue
		if _practice_lock_of(child) != null:
			if child == _practice_lock_of(child).entity:
				practice.append(child)
			continue
		var node := child as Node3D
		var local := _room.to_local(node.global_position)
		(
			assert_bool(PRACTICE_WALL.has_point(local))
			. override_failure_message("%s at %s" % [node.get_path(), local])
			. is_false()
		)
	assert_int(practice.size()).is_equal(4)
	for entity in practice:
		# 5 cm out of the wall face (its origin is on the face, the band's edge).
		var local := _room.to_local((entity as Node3D).global_transform * Vector3(0, 0, 0.05))
		assert_bool(PRACTICE_WALL.has_point(local)).override_failure_message(str(entity.name)).is_true()


func test_signs() -> void:
	var texts := ""
	for sign: Node in _room.get_node("Labels").get_children():
		texts += String(sign.get("text")) + "\n"
	for phrase: String in [
		"5 Security wing",
		"keypad",
		"lockpick",
		"keycard",
		"breaker A",
		"blast",
		"camera",
		"alcoves",
		"computer",
		"breaker B",
		"switch",
		"panic button",
		"fail-secure",
		"turret",
		"sirens",
		"laser",
		"jump over",
		"crouch under",
	]:
		assert_str(texts.to_lower()).override_failure_message(phrase).contains(phrase.to_lower())


func test_booth_wall_devices_are_named_by_small_signs_above_them() -> void:
	# The alarm controller and the radio base station share the booth's east wall (ADR 0083).
	await get_tree().process_frame
	var booth := _interior(_shell("Booth"))
	var spans: Array[Vector2] = []
	for pair: Array in [
		["BoothController", "Controller", "alarm controller"], ["BoothBaseStation", "BaseStation", "radio base station"]
	]:
		var sign := _room.get_node("Labels/" + String(pair[0])) as Sign
		var device := _room.get_node("Devices/" + String(pair[1])) as Node3D
		assert_str(sign.text.replace("\n", " ").to_lower()).is_equal(String(pair[2]))
		assert_int(sign.size).is_equal(Sign.Size.SMALL)
		# On the same wall, facing into the booth like the device, right above it.
		assert_float(sign.position.x).is_equal_approx(device.position.x, 0.05)
		assert_float(sign.position.z).is_equal_approx(device.position.z, 0.01)
		assert_vector(sign.basis.z).is_equal_approx(device.basis.z, Vector3.ONE * 0.01)
		var top := 0.0
		for mesh: Node in device.find_children("*", "MeshInstance3D", true, false):
			var box := (mesh as MeshInstance3D).get_aabb()
			top = maxf(top, (mesh as Node3D).position.y + box.end.y)
		var text_box := sign.get_aabb()
		assert_float(text_box.size.x).is_greater(0.3)
		assert_float(sign.position.y + text_box.position.y).is_greater(device.position.y + top + 0.05)
		assert_float(sign.position.y + text_box.end.y).is_less(_shell("Booth").size.y)
		# Text width runs along the wall (the sign's x axis is world z).
		spans.append(Vector2(sign.position.z + text_box.position.x, sign.position.z + text_box.end.x))
	# Inside the booth wall and apart from each other.
	for span in spans:
		assert_float(span.x).is_greater(booth.position.y)
		assert_float(span.y).is_less(booth.end.y)
	assert_float(spans[1].x - spans[0].y).is_greater(0.1)


func test_wall_devices_keep_clear_of_doorways_door_sweeps_and_signs() -> void:
	# The text of signs is laid out on the first frame.
	await get_tree().process_frame
	assert_array(WallDeviceChecks.problems(_room)).is_empty()


func test_no_coplanar_faces_with_different_materials() -> void:
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(_room)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


# The practice MechanicalLock on `node`'s entity or on one of its ancestors, or null.
func _practice_lock_of(node: Node) -> MechanicalLock:
	while node != null and node != _room:
		for lock in Lock.locks_of(node):
			if lock is MechanicalLock and (lock as MechanicalLock).is_practice():
				return lock as MechanicalLock
		node = node.get_parent()
	return null


func _readable(item_name: String) -> Readable:
	return _room.get_node("Items/" + item_name + "/Readable") as Readable


func _breaker(breaker_name: String) -> CircuitBreaker:
	return _room.get_node("Devices/" + breaker_name + "/CircuitBreaker") as CircuitBreaker


func _hall_rect() -> Rect2:
	return _interior(_shell("Hall"))


func _inside(node: Node, area: Rect2) -> bool:
	var local := _room.to_local((node as Node3D).global_position)
	return area.has_point(Vector2(local.x, local.z))


# True when any horizontal ray along `across` through room-local `feet` (`reach` either side) hits
# world geometry: rays at the capsule's centre and sides (+-0.35 m), from 0.1 m to just above 1.8 m.
func _blocked(feet: Vector3, across: Vector3, reach: float = 1.0) -> bool:
	var side := across.cross(Vector3.UP).normalized()
	for offset: float in [-CAPSULE_RADIUS, 0.0, CAPSULE_RADIUS]:
		for height: float in [0.1, CAPSULE_HEIGHT * 0.5, CAPSULE_HEIGHT + 0.05]:
			var point := feet + side * offset + Vector3.UP * height
			var hit := KitGeometry.ray(
				_room.get_world_3d(), _room.to_global(point - across * reach), _room.to_global(point + across * reach)
			)
			if not hit.is_empty():
				return true
	return false
