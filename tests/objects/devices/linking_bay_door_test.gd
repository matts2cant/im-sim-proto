extends GdUnitTestSuite
## The locked linking bay (ADR 0130 step 2, objects/devices/linking_bay_locked.tscn): its glass door is
## an entity with a HingedDoor, a Lockable and a MechanicalLock. Closed, it stops the Interactor's ray
## before the rack switch inside; locked, E does nothing until the lock is picked, which swings it
## open; open, the ray reaches the switch; E closes it again. The open bay's body leaves its front
## open to the units. The units snap to their slots and get their own lights.

const LOCKED := preload("res://objects/devices/linking_bay_locked.tscn")
const OPEN := preload("res://objects/devices/models/linking_bay.tscn")
const SWITCH := preload("res://objects/network/switch_rack.tscn")
const ORIGIN := Vector3(680, 0, 680)
## The ray starts this far in front of the bay (m), at the switch's height.
const REACH := 1.2

var _root: Node3D
var _bay: LinkingBay
var _switch: Node3D
var _door: HingedDoor
var _user: Node3D


func before_test() -> void:
	EventLog.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_user = Node3D.new()
	_user.name = "Picker"
	_root.add_child(_user)


func test_the_closed_glass_door_blocks_the_ray_and_open_lets_it_reach_the_unit() -> void:
	await _build(LOCKED, Vector3.ZERO)

	assert_object(_ray_hit()).is_same(_bay.get_node("GlassDoor"))
	assert_bool(_door.is_locked()).is_true()
	# Locked: E does nothing and the door stays shut.
	assert_bool(_door.use(_user)).is_false()
	assert_bool(_door.open).is_false()
	# Picked: unlocked by the user, it swings open.
	var lock := _bay.get_node("GlassDoor/MechanicalLock") as MechanicalLock
	assert_bool(lock.complete_pick(_user)).is_true()
	assert_bool(_door.open).is_true()
	await _settle()
	assert_object(_ray_hit()).is_same(_switch)
	# E closes it; unlocked now, E opens it again.
	assert_bool(_door.use(_user)).is_true()
	await _settle()
	assert_object(_ray_hit()).is_same(_bay.get_node("GlassDoor"))
	assert_bool(_door.use(_user)).is_true()
	assert_bool(_door.open).is_true()


func test_the_door_look_swings_with_the_leaf() -> void:
	await _build(LOCKED, Vector3.ZERO)
	var glass := _bay.get_node("GlassDoor/Glass") as MeshInstance3D
	var closed := glass.global_transform * glass.get_aabb().get_center()

	_door.set_open(true)
	await _settle()

	var opened := glass.global_transform * glass.get_aabb().get_center()
	assert_float(opened.z - closed.z).override_failure_message("swings out of the front").is_greater(0.15)


func test_an_open_bay_lets_the_ray_reach_its_units_and_they_get_their_lights() -> void:
	await _build(OPEN, Vector3(0, 0, 3))

	assert_object(_ray_hit()).is_same(_switch)
	assert_float(_switch.position.z).is_equal_approx(LinkingBay.RAIL_Z, 1e-5)
	assert_int(StatusLight.of(_switch).indicators().size()).is_equal(1)


# The bay at `at` with a rack switch dropped near slot 10 (it snaps).
func _build(scene: PackedScene, at: Vector3) -> void:
	_bay = scene.instantiate() as LinkingBay
	_bay.position = ORIGIN + at
	_switch = SWITCH.instantiate() as Node3D
	_switch.position = Vector3(0.0, LinkingBay.slot_y(10, 1) + 0.01, 0.0)
	_bay.add_child(_switch)
	_root.add_child(_bay)
	_door = HingedDoor.of(_bay.get_node_or_null("GlassDoor"))
	for i in 3:
		await get_tree().physics_frame


func _settle() -> void:
	for i in 60:
		await get_tree().physics_frame
		if _door.is_settled():
			break
	await get_tree().physics_frame
	await get_tree().physics_frame


# What the Interactor's ray meets from REACH in front of the bay, aimed at the switch's front.
func _ray_hit() -> Node:
	var target := _switch.global_position + Vector3(0.1, 0.02, 0.0)
	var from := target + _bay.global_basis.z * REACH
	var query := PhysicsRayQueryParameters3D.create(from, target - _bay.global_basis.z * 0.05)
	query.collision_mask = PhysicsLayers.INTERACT_MASK
	var hit := _root.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") as Node
