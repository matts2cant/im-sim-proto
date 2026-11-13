extends GdUnitTestSuite
## The warehouse's network gear after ADR 0130 step 3 (design/levels/mission-warehouse.md "Office
## bay (M13c)"): every device's cables fit its model's sockets and every device has a model; every
## router and switch stands in a linking bay or on a desk (none on a wall); every computer stands on
## a desk or in a bay but the security console (a standing console on its wall shelf). The
## one bay stands in the second office with 1 m of clear floor in front of it and holds RTR-01, the
## five security switches and MAIL-01 (a rack server: a computer); its glass door is locked, opens
## when picked or with its key, which lies on the security room desk. Walking at the bay and the
## lockpick's loudest noise reach no guard post or patrol point (straight line, the shortest a path
## can be); the office's meshes have no coplanar faces. The populated level is loaded once (no
## navmesh: warehouse_door_navigation_test checks the office's floor around the bay).

const Helpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const NOISE: MovementNoiseConfig = preload("res://actors/player/player_movement_noise.tres")
const MountChecks := preload("res://tests/levels/device_mount_checks.gd")
const SECURITY := "Population/Security/"
## The one computer on a wall shelf: a standing console between duct C's mouth and the window.
const CONSOLE := "SEC-CONSOLE"
## The second office on the upper floor (x, z) and its floor; the security room (ground floor).
const OFFICE := Rect2(13.25, 7.0, 6.5, 7.75)
const OFFICE_FLOOR := 4.5
const SECURITY_ROOM := Rect2(14.0, 0.25, 5.75, 4.75)
## The gear in the bay, by network name.
const BAY_GEAR: Array[String] = ["RTR-01", "SW-SECURITY", "SW-SEC-ROOM", "SW-VAULT", "SW-YARD", "SW-ROOF", "MAIL-01"]
## Clear floor in front of the bay (m, from its glass door) and the feet's distance from the door.
const CLEAR := 1.0
const FEET_OFF_DOOR := 0.4
## Margin kept beyond a noise's loudness (m of straight line to a guard spot).
const MARGIN := 1.0

var _level: Node3D


func before() -> void:
	_level = await Helpers.load_for_queries(self, true, false)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func test_every_device_fits_its_model_and_no_wall_gear_remains() -> void:
	var problems: PackedStringArray = []
	var devices := 0
	for node in _level.find_children("*", "Device", true, false):
		var device := node as Device
		devices += 1
		var error := ModelFace.cable_error(device)
		if not error.is_empty():
			problems.append(error)
		if not ModelFace.has_model(device.entity):
			problems.append("%s: no model" % _path(device.entity))
		# A rack unit stands in a linking bay; routers and switches are never on a wall.
		var entity := device.entity as Node3D
		if LinkingBay.rack_units_of(entity) > 0 and MountChecks.bay_of(entity) == null:
			problems.append("%s: a rack unit outside a bay" % _path(entity))
		var tags := ActorState.tags_of(entity)
		var gear := tags.has(&"object.router") or tags.has(&"object.network_switch")
		var computer := Computer.of(entity) != null and NetworkSource.display_name(device) != CONSOLE
		if (gear or computer) and MountChecks.mount(entity) == MountChecks.Mount.WALL:
			problems.append("%s: on a wall" % _path(entity))
	assert_int(devices).is_greater(40)
	assert_array(Array(problems)).is_empty()


func test_the_locked_bay_stands_in_the_second_office_with_the_network_gear() -> void:
	var bay := _bay()
	var at := bay.global_position
	assert_bool(OFFICE.has_point(Vector2(at.x, at.z))).override_failure_message("bay at %s" % at).is_true()
	assert_float(at.y).is_equal_approx(OFFICE_FLOOR, 0.01)
	var names: Array[String] = []
	for unit in bay.units():
		names.append(NetworkSource.display_name(Device.of(unit)))
	assert_array(names).contains_exactly_in_any_order(BAY_GEAR)
	# MAIL-01 is a rack server: a computer.
	for unit in bay.units():
		if NetworkSource.display_name(Device.of(unit)) == "MAIL-01":
			assert_object(Computer.of(unit)).is_not_null()
	# Nothing solid in the 1 m in front of its glass door (the door's width, 0.15 to 1.85 m up).
	var front := Transform3D(bay.global_basis, bay.global_transform * Vector3(0, 1.0, 0.36 + CLEAR * 0.5))
	var box := BoxShape3D.new()
	box.size = Vector3(LinkingBay.WIDTH, 1.7, CLEAR)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = front
	var hits := _level.get_world_3d().direct_space_state.intersect_shape(query)
	var blocking: Array[String] = []
	for hit in hits:
		blocking.append(_path(hit["collider"] as Node))
	assert_array(blocking).is_empty()


func test_its_glass_door_opens_when_picked_or_with_its_key_found_on_the_security_desk() -> void:
	var glass := _bay().get_node("GlassDoor")
	var hinge := HingedDoor.of(glass)
	var lock := Lock.locks_of(glass)[0] as MechanicalLock
	var key_id := lock.data.key_id
	assert_str(String(key_id)).is_not_empty()
	assert_str(lock.locked_reason(null)).is_equal("key or lockpick")
	# Its key: one pickup naming it, on the security room desk (outside the office), found_text set.
	var keys: Array[ItemPickup] = []
	for node in _level.find_children("*", "ItemPickup", true, false):
		if str((node as ItemPickup).state.get("key_id", "")) == String(key_id):
			keys.append(node as ItemPickup)
	assert_int(keys.size()).is_equal(1)
	var key := keys[0].get_parent() as Node3D
	assert_bool(keys[0].item.keychain).is_true()
	assert_str(keys[0].found_text).is_not_empty()
	assert_bool(SECURITY_ROOM.has_point(Vector2(key.global_position.x, key.global_position.z))).is_true()
	var under := _ray(key.global_position + Vector3.UP * 0.05, key.global_position + Vector3.DOWN * 0.1)
	assert_bool(under.is_empty()).override_failure_message("nothing under the key").is_false()

	# Without the key: locked, E does nothing; picked, it swings open.
	var picker := _stand_in("Picker")
	assert_bool(hinge.is_locked()).is_true()
	assert_bool(hinge.use(picker)).is_false()
	assert_bool(lock.complete_pick(picker)).is_true()
	assert_bool(hinge.open).is_true()
	hinge.set_open(false)
	Lockable.of(glass).lock()
	# With the key on a keychain, E opens it.
	var holder := _stand_in("Holder")
	var keychain := Keychain.new()
	holder.add_child(keychain)
	keychain.add(key_id, "Office bay key")
	assert_bool(hinge.is_locked()).is_true()
	assert_bool(hinge.use(holder)).is_true()
	assert_bool(hinge.open).is_true()
	hinge.set_open(false)
	Lockable.of(glass).lock()
	picker.free()
	holder.free()


func test_walking_and_picking_at_the_bay_reach_no_guard_post() -> void:
	var feet := _bay_feet()
	var floor_hit := _ray(feet + Vector3.UP * 0.5, feet + Vector3.DOWN * 0.5)
	assert_bool(floor_hit.is_empty()).is_false()
	var surface := NOISE.surfaces.surface_of(floor_hit["collider"])
	var walk := MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.WALK, surface, NOISE)
	var lock := Lock.locks_of(_bay().get_node("GlassDoor"))[0] as MechanicalLock
	var tuning := lock.tuning if lock.tuning != null else MechanicalLock.DEFAULT_TUNING
	var loudest := 0.0
	for kind: StringName in [&"set", &"scrape", &"tick", &"overset", &"false_set", &"open", &"snap"]:
		loudest = maxf(loudest, tuning.loudness(kind))
	var heard: PackedStringArray = []
	for spot: Vector3 in _guard_spots():
		if spot.distance_to(feet) < walk + MARGIN:
			heard.append("walk (%.1f) heard at %s, %.1f m" % [walk, spot, spot.distance_to(feet)])
		if spot.distance_to(lock.noise_origin()) < loudest + MARGIN:
			heard.append("pick (%.1f) heard at %s, %.1f m" % [loudest, spot, spot.distance_to(lock.noise_origin())])
	assert_array(Array(heard)).is_empty()


func test_the_office_gear_has_no_coplanar_faces() -> void:
	# Each piece in its own frame: at world coordinates (x 19) float rounding turns the rack units' ears
	# and bodies, which only share an edge, into sliver overlaps.
	var found: PackedStringArray = []
	for path: String in ["OfficeBay", "OfficeSwitch", "OfficePc1", "OfficePc2", "OfficeWallJack"]:
		found.append_array(KitGeometry.coplanar_mesh_overlaps(_level.get_node(SECURITY + "Network/" + path)))
	assert_array(Array(found)).is_empty()


func _bay() -> LinkingBay:
	var bays := _level.find_children("*", "LinkingBay", true, false)
	assert_int(bays.size()).is_equal(1)
	return bays[0] as LinkingBay


# Feet on the floor in front of the bay's glass door, where a player picks its lock.
func _bay_feet() -> Vector3:
	var bay := _bay()
	var feet := bay.global_transform * Vector3(0, 0, LinkingBay.DEPTH * 0.5 + FEET_OFF_DOOR)
	return Vector3(feet.x, OFFICE_FLOOR, feet.z)


# Every guard (as placed) and every patrol point.
func _guard_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for guard: Node3D in _level.get_node("Population/People/Guards").get_children():
		spots.append(guard.global_position)
	for route: Node in _level.get_node("Population/People/Routes").get_children():
		for point: Node3D in route.get_children():
			spots.append(point.global_position)
	return spots


func _stand_in(stand_in_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = stand_in_name
	_level.add_child(node)
	node.global_position = _bay_feet()
	return node


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD)
	return _level.get_world_3d().direct_space_state.intersect_ray(query)


func _path(node: Node) -> String:
	return String(_level.get_path_to(node))
