extends GdUnitTestSuite
## Integration: the carried object is a see-through ghost (no collisions), turns upright to the
## nearest quarter turn of the view, and is only released at a free spot (ADR 0053).
## carry_room.tscn: floor top y 0, wall face z -5.8 (x -5 to 5, 3 m high). Capsule radius 0.35 m.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
const CARRY: CarryConfig = preload("res://actors/common/carry/carry.tres")
const WALL_FACE_Z := -5.8
const ALL_MASK := PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ACTORS | PhysicsLayers.OBJECTS

var _driver: PlayerDriver
var _player: Player


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_tilted_crate_turns_upright_and_keeps_its_yaw_to_the_view() -> void:
	await _load()
	# Yawed 20 degrees (snaps to 0 relative to the view) and tilted 30 degrees.
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.0, -1.0))
	crate.global_basis = Basis(Vector3.UP, deg_to_rad(20.0)) * Basis(Vector3.RIGHT, deg_to_rad(30.0))
	_player.carry.pick_up(crate)

	await _driver.frames(3)
	assert_float(crate.global_basis.y.dot(Vector3.UP)).is_less(0.995)
	await _driver.frames(15)  # 0.3 s after pick-up in total
	assert_float(crate.global_basis.y.dot(Vector3.UP)).is_greater(0.9999)
	assert_float(rad_to_deg(CarryRules.view_yaw(crate.global_basis))).is_equal_approx(0.0, 0.1)

	# The view turns 90 degrees left: the crate turns with it, at once.
	_player.look(Vector2(-PI * 0.5 / CONFIG.mouse_sensitivity, 0))
	await _driver.frames(2)
	assert_float(rad_to_deg(CarryRules.view_yaw(crate.global_basis))).is_equal_approx(90.0, 0.1)
	assert_float(crate.global_position.distance_to(_hold_point(0.3))).is_less(0.001)


func test_held_crate_has_no_collision() -> void:
	await _load()
	await _driver.place(Vector3(0, 0, -4.5))
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.25, -5.25))
	_player.carry.pick_up(crate)
	await _driver.frames(20)

	# Rays (weapon and interact masks included) pass through it.
	var space := _player.get_world_3d().direct_space_state
	var from := crate.global_position + Vector3(2, 0, 0)
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3(-4, 0, 0), 0xFFFFFFFF)
	assert_bool(space.intersect_ray(ray).is_empty()).is_true()
	assert_object(_player.interactor.target).is_same(crate)
	assert_int(_player.interactor.kind).is_equal(Interactor.Kind.PUT_DOWN)

	# Walking into the wall (0.95 m gap): the player stops at the wall, the crate goes into it.
	await _driver.hold(&"move_forward", 60)
	await _driver.frames(5)
	assert_float(_player.global_position.z).is_equal_approx(WALL_FACE_Z + CONFIG.capsule_radius, 0.05)
	assert_bool(_player.carry.is_carrying()).is_true()
	assert_float(crate.global_position.z).is_less(WALL_FACE_Z)
	assert_float(crate.global_position.distance_to(_hold_point(0.3))).is_less(0.001)


func test_no_room_against_a_wall_refuses_the_release() -> void:
	await _load()
	# 0.5 m gap (capsule surface to wall face): a 0.6 m crate cannot fit between them.
	await _driver.place(Vector3(0, 0, WALL_FACE_Z + CONFIG.capsule_radius + 0.5))
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(3, 1.25, -2))
	_player.carry.pick_up(crate)
	await _driver.frames(20)
	assert_str(_player.interactor.prompt).is_equal("No room to put down Small crate")
	EventLog.clear()

	await _driver.hold(&"use", 2)
	# E says why (ADR 0130).
	assert_str((_player.get_node("Hud") as Hud).message_label.text).is_equal("No room to put down")
	await _driver.hold(&"drop_throw", 2)
	await _driver.hold(&"fire", 2)

	assert_bool(_player.carry.is_carrying()).is_true()
	var refused := EventLog.find(&"player.release_refused")
	(
		assert_array(refused.map(func(entry: EventLogEntry) -> StringName: return entry.data["how"]))
		. is_equal([&"put_down", &"drop", &"throw"])
	)
	assert_str(refused[0].data["reason"]).is_equal("no_room")
	assert_array(EventLog.find(&"player.dropped")).is_empty()
	assert_array(EventLog.find(&"player.threw")).is_empty()
	assert_int(crate.collision_layer).is_equal(0)


func test_release_near_a_wall_lands_between_player_and_wall() -> void:
	await _load()
	# 0.65 m gap: the hold point (0.75 m ahead) puts the crate's front 0.05 m into the wall; the cast
	# stops it at the wall face, its back 0.05 m clear of the capsule.
	var feet_z := WALL_FACE_Z + CONFIG.capsule_radius + 0.65
	await _driver.place(Vector3(0, 0, feet_z))
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(3, 1.25, -2))
	_player.carry.pick_up(crate)
	await _driver.frames(20)
	assert_str(_player.interactor.prompt).is_equal("E: put down Small crate")

	await _driver.hold(&"use", 2)

	assert_bool(_player.carry.is_carrying()).is_false()
	assert_bool(_overlaps(crate)).is_false()
	await _driver.frames(90)
	# Resting on the floor between the two (it touches the floor, so no overlap query here).
	assert_float(crate.global_position.y).is_equal_approx(0.3, 0.05)
	assert_float(crate.global_position.z - 0.3).is_greater_equal(WALL_FACE_Z - 0.01)
	assert_float(crate.global_position.z + 0.3).is_less_equal(feet_z - CONFIG.capsule_radius + 0.01)
	assert_float(_player.global_position.z).is_equal_approx(feet_z, 0.01)


func test_release_never_overlaps_and_starts_from_the_free_spot() -> void:
	await _load()
	await _driver.place(Vector3(0, 0, WALL_FACE_Z + CONFIG.capsule_radius + 0.65))
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(3, 1.25, -2))
	_player.carry.pick_up(crate)
	await _driver.frames(20)
	var spot: Dictionary = _player.carry.release_spot()

	assert_bool(_player.carry.throw()).is_true()

	# Thrown from the free spot (not the hold point inside the wall), at the usual speed.
	assert_vector(crate.global_position).is_equal_approx(spot["transform"].origin, Vector3.ONE * 0.0001)
	assert_float(crate.global_position.z).is_greater(_hold_point(0.3).z)
	assert_bool(_overlaps(crate)).is_false()
	assert_float(crate.linear_velocity.length()).is_equal_approx(CarryRules.throw_speed(crate.mass, CARRY), 0.0001)


func test_put_down_onto_a_crate_stacks_it() -> void:
	await _load()
	# Crate A: centre 0.9 m ahead (0.25 m gap to the capsule). Look at the middle of its top.
	var below := _spawn(Objects.SMALL_CRATE, Vector3(0, 0.3, -0.9))
	await _driver.frames(30)
	_player.load_state(Objects.aiming_state(_player, Vector3.ZERO, Vector3(0, 0.6, -0.9)))
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(3, 1.25, -2))
	_player.carry.pick_up(crate)
	await _driver.frames(20)

	await _driver.hold(&"use", 2)
	await _driver.frames(120)

	# Out at chest height to 0.75 m, then lowered onto A's top (0.15 m off its centre): it stays.
	assert_bool(_player.carry.is_carrying()).is_false()
	assert_float(crate.global_position.y).is_equal_approx(0.9, 0.05)
	assert_float(absf(crate.global_position.z - below.global_position.z)).is_less(0.25)
	assert_float(crate.global_basis.y.dot(Vector3.UP)).is_greater(0.99)
	assert_float(below.global_position.y).is_equal_approx(0.3, 0.02)


func test_transparency_and_collision_layers_are_restored_exactly() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.25, -1.5))
	var mesh := crate.get_node("Mesh") as MeshInstance3D
	var csg := CSGBox3D.new()
	crate.add_child(csg)
	csg.transparency = 0.2
	crate.collision_layer = PhysicsLayers.OBJECTS | PhysicsLayers.TRIGGERS
	crate.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	_player.carry.pick_up(crate)
	await _driver.frames(5)

	assert_float(mesh.transparency).is_equal_approx(CARRY.held_transparency, 0.0001)
	assert_float(csg.transparency).is_equal_approx(CARRY.held_transparency, 0.0001)
	assert_int(crate.collision_layer).is_equal(0)
	assert_int(crate.collision_mask).is_equal(0)

	_player.carry.put_down()

	assert_float(mesh.transparency).is_equal(0.0)
	assert_float(csg.transparency).is_equal_approx(0.2, 0.0001)
	assert_int(crate.collision_layer).is_equal(PhysicsLayers.OBJECTS | PhysicsLayers.TRIGGERS)
	assert_int(crate.collision_mask).is_equal(PhysicsLayers.WORLD | PhysicsLayers.OBJECTS)
	assert_bool(crate.freeze).is_false()


func test_burning_crate_fire_stays_opaque_and_still_hurts() -> void:
	await _load()
	var crate := _spawn(Objects.SMALL_CRATE, Vector3(0, 1.25, -0.75))
	Flammable.of(crate).ignite(null)
	await _driver.frames(2)
	_player.carry.pick_up(crate)
	await _driver.frames(70)

	for node in crate.find_children("*", "GeometryInstance3D", true, false):
		var fade := 0.0 if Carrier._in_fire_fx(node, crate) else CARRY.held_transparency
		assert_float((node as GeometryInstance3D).transparency).is_equal_approx(fade, 0.0001)
	assert_float(_player.body.health(&"torso")).is_less(100.0)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	await _driver.settle()


func _spawn(path: String, position: Vector3) -> RigidBody3D:
	return Objects.spawn(_driver.runner.scene(), path, position) as RigidBody3D


func _hold_point(half_extent: float) -> Vector3:
	return CarryRules.hold_point(_player.eye_transform(), half_extent, CARRY)


# True when the body's shape at its current transform overlaps the world, player, actors or objects.
func _overlaps(body: RigidBody3D) -> bool:
	var shape := body.get_node("Collision") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = body.global_transform * shape.transform
	query.collision_mask = ALL_MASK
	query.exclude = [body.get_rid()]
	return not _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
