extends GdUnitTestSuite
## Gallery room 5 (security wing): the practice-lock wall (ADR 0107, lockpicking.md). Four acrylic
## practice locks (objects/locks/practice_lock/practice_lock.tscn) hang on the entry hall's west wall
## face (x -7.5) at 1.3 m, one per tier from low z to high z: Simple (3 pins), Standard (5), Secure
## (5), High-security (6), centres 0.75 m apart (z 1.9, 2.65, 3.4, 4.15). Each is flush on the wall,
## shows as many pins as its tier has, and has a small sign above it naming its tier and pin count;
## one header sign above them all says what practice locks do. The player stands 0.8 m out from the
## wall face (capsule centre at x -6.7) in front of each, clear of the table, the doorways and the
## door sweeps: the lock is under the crosshair standing (and crouched in front of Standard), LMB with
## a lockpick starts the minigame on it and E leaves it. The minigame's rules are not tested here.
## Room-local coordinates (origin on the hub wall's outer face, +Z away from the hub);
## fixture `fixtures/wing_player.tscn` puts the wing and a player at (600, 0, -300).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/security_wing/security_wing.tscn")
const FIXTURE := "res://tests/levels/gallery/security_wing/fixtures/wing_player.tscn"
## Node name, tier, pin count, tier name, centre z.
const LOCKS: Array[Array] = [
	["PracticeSimple", MechanicalLockData.Tier.SIMPLE, 3, "Simple", 1.9],
	["PracticeStandard", MechanicalLockData.Tier.STANDARD, 5, "Standard", 2.65],
	["PracticeSecure", MechanicalLockData.Tier.SECURE, 5, "Secure", 3.4],
	["PracticeHighSecurity", MechanicalLockData.Tier.HIGH_SECURITY, 6, "High-security", 4.15],
]
## The west wall's face and the lock band on it (z 1.5..4.5, 0.5..2.5 m up).
const WALL_X := -7.5
const BAND := AABB(Vector3(-7.5, 0.5, 1.5), Vector3(0.5, 2.0, 3.0))
const LOCK_HEIGHT := 1.3
## Stand spot: capsule centre 0.8 m from the wall face (0.45 m gap, surface to surface).
const STAND_X := -6.7
const CAPSULE_RADIUS := 0.35
## Standard is also tried crouched.
const CROUCHED := "PracticeStandard"


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_one_practice_lock_per_tier_flush_on_the_west_wall() -> void:
	var room := _room()
	await KitGeometry.settle(get_tree(), 5)
	var last_z := -INF
	for spec: Array in LOCKS:
		var where := String(spec[0])
		var body := room.get_node("PracticeLocks/" + where) as StaticBody3D
		var lock := body.get_node("MechanicalLock") as MechanicalLock
		assert_bool(lock.is_practice()).override_failure_message(where).is_true()
		assert_int(lock.data.practice_tier).override_failure_message(where).is_equal(int(spec[1]))
		assert_int(lock.pin_count()).override_failure_message(where).is_equal(int(spec[2]))
		assert_str(lock.tier_name()).override_failure_message(where).is_equal(String(spec[3]))
		assert_bool(lock.is_locked()).override_failure_message(where).is_true()
		# The prop shows its tier's pins.
		assert_int((body.get_node("Pins") as PracticeLockPins).shown_count()).override_failure_message(where).is_equal(
			int(spec[2])
		)
		# On the west wall face, facing into the hall, at its height, in order along z.
		assert_vector(body.position).override_failure_message(where).is_equal_approx(
			Vector3(WALL_X, LOCK_HEIGHT, float(spec[4])), Vector3.ONE * 0.001
		)
		assert_vector(body.basis.z).override_failure_message(where).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
		assert_float(body.position.z - last_z).override_failure_message(where).is_greater(0.6)
		last_z = body.position.z
		var box := room.global_transform.affine_inverse() * WallDeviceChecks.visual_box(body)
		assert_bool(BAND.encloses(box)).override_failure_message("%s %s" % [where, box]).is_true()
		# Nothing of it inside the wall, and its back flat on the wall face.
		assert_float(box.position.x).override_failure_message(where).is_equal_approx(WALL_X, 0.002)
		assert_array(_flush(body)).is_empty()


func test_signs_name_each_tier_above_its_lock() -> void:
	var room := _room()
	await get_tree().process_frame
	var hall := _interior(room.get_node("Shell/Hall") as Room)
	var spans: Array[Vector2] = []
	var labels_top := 0.0
	for spec: Array in LOCKS:
		var where := String(spec[0])
		var body := room.get_node("PracticeLocks/" + where) as Node3D
		var lock := body.get_node("MechanicalLock") as MechanicalLock
		var sign := room.get_node("Labels/" + where) as Sign
		var text := sign.text.replace("\n", " ")
		assert_str(text).override_failure_message(where).contains(lock.tier_name())
		assert_str(text).override_failure_message(where).contains("%d pins" % lock.pin_count())
		var box := _local_box(room, sign)
		var lock_box := room.global_transform.affine_inverse() * WallDeviceChecks.visual_box(body)
		# On the wall face, facing the hall, centred over its lock and clear above it.
		assert_vector(sign.basis.z).override_failure_message(where).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
		assert_float(sign.position.x - WALL_X).override_failure_message(where).is_between(0.02, 0.08)
		assert_float(sign.position.z).override_failure_message(where).is_equal_approx(body.position.z, 0.01)
		assert_float(box.position.y - lock_box.end.y).override_failure_message(where).is_greater(0.03)
		spans.append(Vector2(box.position.z, box.end.z))
		labels_top = maxf(labels_top, box.end.y)
	# The labels do not touch each other.
	for index in range(1, spans.size()):
		assert_float(spans[index].x - spans[index - 1].y).override_failure_message(str(index)).is_greater(0.05)
	# The header: what practice locks do, above the labels, inside the wall and under the ceiling.
	var header := room.get_node("Labels/PracticeLocks") as Sign
	var header_text := header.text.replace("\n", " ").to_lower()
	for phrase: String in ["practice locks", "every assist", "re-lock", "new pins"]:
		assert_str(header_text).override_failure_message(phrase).contains(phrase)
	var header_box := _local_box(room, header)
	assert_vector(header.basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
	assert_float(header_box.position.y - labels_top).is_greater(0.05)
	assert_float(header_box.position.z).is_greater(hall.position.y + 0.3)
	assert_float(header_box.end.z).is_less(hall.end.y - 0.3)
	assert_float(header_box.end.y).is_less((room.get_node("Shell/Hall") as Room).size.y - 0.3)


func test_stand_spots_clear_of_the_table_doorways_and_door_sweeps() -> void:
	var room := _room()
	await KitGeometry.settle(get_tree(), 5)
	var table := room.get_node("Shell/Table") as Node3D
	# The table (1.6 x 0.7 m, its lip at z 0.71, its back at the north wall).
	var table_rect := Rect2(table.position.x - 0.8, table.position.z - 0.7, 1.6, 0.7)
	for spec: Array in LOCKS:
		var where := String(spec[0])
		var feet := Vector3(STAND_X, 0, float(spec[4]))
		var capsule := AABB(feet - Vector3(CAPSULE_RADIUS, 0, CAPSULE_RADIUS), Vector3(0.7, 1.8, 0.7))
		var footprint := Rect2(capsule.position.x, capsule.position.z, 0.7, 0.7)
		assert_bool(footprint.grow(0.1).intersects(table_rect)).override_failure_message(where).is_false()
		for door: Door in _doors(room):
			var to_door := door.entity.global_transform.affine_inverse() * room.global_transform
			var local: AABB = to_door * capsule.grow(0.1)
			var at := "%s / %s" % [where, door.entity.name]
			assert_bool(local.intersects(WallDeviceChecks.opening(door))).override_failure_message(at).is_false()
			(
				assert_bool(local.intersects(DoorLayout.sweep(door.settings, door.wall_thickness)))
				. override_failure_message(at)
				. is_false()
			)
		# Free standing room: no world geometry in the capsule (0.05 m above the floor up).
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = CAPSULE_RADIUS
		shape.height = 1.8
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, room.to_global(feet + Vector3.UP * 0.95))
		query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
		var hits := room.get_world_3d().direct_space_state.intersect_shape(query, 4)
		assert_array(hits).override_failure_message(where).is_empty()


func test_the_player_picks_each_practice_lock_from_in_front_of_it() -> void:
	var runner := scene_runner(FIXTURE)
	var driver := PlayerDriver.new(runner)
	var player := driver.player
	player.reload_on_reset = false
	var wing := runner.find_child("SecurityWing") as Node3D
	await driver.settle()
	player.inventory.give(Items.LOCKPICK, 1)
	player.inventory.hold(player.inventory.inventory.stacks_of(&"lockpick")[0])
	var screen := LockpickScreen.of(player)
	var reach := player.config.interact_reach
	for spec: Array in LOCKS:
		var where := String(spec[0])
		var body := wing.get_node("PracticeLocks/" + where) as StaticBody3D
		var feet := wing.to_global(Vector3(STAND_X, 0, float(spec[4])))
		# Aim at the middle of the acrylic's front.
		var aim := body.global_transform * Vector3(0, 0, 0.08)
		var postures: Array[bool] = [false]
		if where == CROUCHED:
			postures.append(true)
		for crouched in postures:
			var at := "%s crouched %s" % [where, crouched]
			EventLog.clear()
			# Crouch is held: keep it held while crouched.
			if crouched:
				runner.simulate_action_press(&"crouch")
			player.load_state(_aiming(player, feet, aim, crouched))
			await driver.frames(4)
			# Stands there on the floor, nothing pushed it, the lock within reach under the crosshair.
			assert_bool(player.crouched).override_failure_message(at).is_equal(crouched)
			assert_bool(player.is_on_floor()).override_failure_message(at).is_true()
			assert_float(player.global_position.distance_to(feet)).override_failure_message(at).is_less(0.02)
			assert_float(player.eye_transform().origin.distance_to(aim)).override_failure_message(at).is_less(
				reach - 0.8
			)
			assert_object(player.interactor.looked_at).override_failure_message(at).is_same(body)
			# LMB with the lockpick starts the minigame on this lock; E leaves it.
			await driver.hold(&"fire", 2)
			await driver.frames(1)
			assert_bool(screen.is_open()).override_failure_message(at).is_true()
			var started := EventLog.find(&"lock.pick_started")
			(
				assert_array(started.map(func(entry: EventLogEntry) -> String: return String(entry.data["entity"])))
				. is_equal([where])
			)
			await driver.hold(&"use", 2)
			await driver.frames(2)
			assert_bool(screen.is_open()).override_failure_message(at).is_false()
			var cancelled := EventLog.find(&"lock.pick_cancelled")
			(
				assert_array(cancelled.map(func(entry: EventLogEntry) -> String: return String(entry.data["reason"])))
				. is_equal(["left"])
			)
			assert_bool(Lockable.of(body).locked).override_failure_message(at).is_true()
			if crouched:
				runner.simulate_action_release(&"crouch")
	screen.close()


func _room() -> Node3D:
	var room := auto_free(ROOM_SCENE.instantiate()) as Node3D
	room.position = Vector3(-300, 0, -600)
	add_child(room)
	return room


func _doors(room: Node) -> Array[Door]:
	var result: Array[Door] = []
	for node in room.find_children("*", "Door", true, false):
		result.append(node as Door)
	return result


# A player state at `feet` looking at `target` (standing or crouched eyes).
static func _aiming(player: Player, feet: Vector3, target: Vector3, crouched: bool) -> Dictionary:
	var eye_height := player.config.crouched_eye_height if crouched else player.config.standing_eye_height
	var to := target - (feet + Vector3.UP * eye_height)
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	return {"position": feet, "yaw": yaw, "pitch": pitch, "crouched": crouched, "velocity": Vector3.ZERO}


# Rays from 2 cm in front of the plate's back, near its corners, straight back: each meets the wall
# within 4 mm of the back face (no corner floating or overhanging).
static func _flush(body: StaticBody3D) -> PackedStringArray:
	var found := PackedStringArray()
	var plate := body.get_node("Plate") as MeshInstance3D
	var size := plate.get_aabb().size
	var inset := Vector2(size.x * 0.5 - 0.01, size.y * 0.5 - 0.01)
	var space := body.get_world_3d().direct_space_state
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var from := body.global_transform * Vector3(corner.x * inset.x, corner.y * inset.y, 0.02)
		var to := body.global_transform * Vector3(corner.x * inset.x, corner.y * inset.y, -0.03)
		var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, [body.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			found.append("%s: nothing behind its corner %s" % [body.name, corner])
		elif absf(from.distance_to(hit["position"] as Vector3) - 0.02) > 0.004:
			found.append("%s: its corner %s is off the wall" % [body.name, corner])
	return found


# A sign's text box in room-local coordinates.
static func _local_box(room: Node3D, sign: Sign) -> AABB:
	return room.global_transform.affine_inverse() * sign.global_transform * sign.get_aabb()


# Interior bounds of a kit Room in room-local x / z (Rect2 position x = x, y = z).
static func _interior(room: Room) -> Rect2:
	var half := Vector2(room.size.x, room.size.z) * 0.5
	return Rect2(Vector2(room.position.x, room.position.z) - half, half * 2.0)
