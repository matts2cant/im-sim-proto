extends GdUnitTestSuite
## The network lab and the security wing after ADR 0130 step 3, each room alone (loaded once): no
## device has more cables than its model has sockets; no wall-mounted router, switch or mail server is
## left (routers and switches are in the new look and stand in a linking bay or on a desk); every bay
## stands on the floor against a wall with 1 m clear in front and its cables reach the ceiling; every
## computer stands on a desk or in a bay; no two meshes of the bays and the desk gear z-fight
## (coplanar faces of different materials). Rules on components and tags.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const MountChecks := preload("res://tests/levels/device_mount_checks.gd")
const ROOMS: Array[String] = [
	"res://levels/gallery/network_lab/network_lab.tscn",
	"res://levels/gallery/security_wing/security_wing.tscn",
]
const ORIGINS: Array[Vector3] = [Vector3(-700, 0, -700), Vector3(700, 0, -700)]

var _rooms: Array[Node3D] = []


func before() -> void:
	_rooms.clear()
	for i in ROOMS.size():
		var room := auto_free((load(ROOMS[i]) as PackedScene).instantiate()) as Node3D
		room.position = ORIGINS[i]
		add_child(room)
		_rooms.append(room)
	await KitGeometry.settle(get_tree(), 5)


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()


func _devices(room: Node) -> Array[Device]:
	var found: Array[Device] = []
	for node in room.find_children("*", "Device", true, false):
		found.append(node as Device)
	return found


func _label(room: Node, node: Node) -> String:
	return "%s:%s" % [room.name, room.get_path_to(node)]


func test_no_device_has_more_cables_than_its_model_has_sockets() -> void:
	for room in _rooms:
		var devices := _devices(room)
		assert_int(devices.size()).is_greater(15)
		for device in devices:
			var error := ModelFace.cable_error(device)
			assert_str(error).override_failure_message("%s: %s" % [_label(room, device.entity), error]).is_empty()


func test_no_wall_router_switch_or_mail_server_remains() -> void:
	for room in _rooms:
		var gear := 0
		for device in _devices(room):
			var entity := device.entity as Node3D
			var where := _label(room, entity)
			# Routers and switches (access points stay on walls and ceilings).
			var tags := Tags.of(entity)
			if not (tags.has(&"object.router") or tags.has(&"object.network_switch")):
				continue
			gear += 1
			assert_bool(ModelFace.has_model(entity)).override_failure_message(where).is_true()
			assert_int(MountChecks.mount(entity)).override_failure_message(where).is_not_equal(MountChecks.Mount.WALL)
		assert_int(gear).override_failure_message(String(room.name)).is_greater(5)


func test_every_bay_stands_against_a_wall_with_room_in_front() -> void:
	var counts: Array[int] = []
	for room in _rooms:
		var bays := MountChecks.bays(room)
		counts.append(bays.size())
		for bay in bays:
			var problems := MountChecks.bay_problems(bay, room.global_position.y)
			assert_array(Array(problems)).override_failure_message("\n".join(problems)).is_empty()
			# Cables up to the ceiling: a ray from the bundle's top reaches the ceiling within 5 cm.
			var top := bay.global_transform * Vector3(0, LinkingBay.HEIGHT + bay.cable_height - 0.01, -0.2)
			var hit := KitGeometry.ray(bay.get_world_3d(), top, top + Vector3.UP * 0.06)
			assert_dict(hit).override_failure_message("%s: cables stop short of the ceiling" % bay.name).is_not_empty()
	# The lab: bays A (open), B (locked) and C (the annex, open); the wing: one open bay.
	assert_array(counts).is_equal([3, 1])
	var locked: Array[String] = []
	for room in _rooms:
		for bay in MountChecks.bays(room):
			if bay.glass_door:
				locked.append(String(bay.name))
	assert_array(locked).is_equal(["BayB"])


func test_every_computer_stands_on_a_desk_or_in_a_bay() -> void:
	for room in _rooms:
		var computers := 0
		for device in _devices(room):
			if Computer.of(device.entity) == null:
				continue
			computers += 1
			var mount := MountChecks.mount(device.entity as Node3D)
			assert_int(mount).override_failure_message(_label(room, device.entity)).is_not_equal(MountChecks.Mount.WALL)
		assert_int(computers).override_failure_message(String(room.name)).is_greater(0)


func test_no_coplanar_mesh_faces_in_the_bays_and_desk_gear() -> void:
	# The gear step 3 placed: each bay with its units, each device standing on a desk. (Run over the
	# whole rooms, the check also lists the guard's pose meshes over its model and a near-coplanar
	# facet pair on the access point's rim: neither is this step's.)
	var parts: Array[Node] = []
	for room in _rooms:
		parts.append_array(MountChecks.bays(room))
		for device in _devices(room):
			if device.entity is Node3D and MountChecks.mount(device.entity as Node3D) == MountChecks.Mount.DESK:
				parts.append(device.entity)
	assert_int(parts.size()).is_greater(8)
	for part in parts:
		var overlaps := KitGeometry.coplanar_mesh_overlaps(part)
		assert_array(Array(overlaps)).override_failure_message("%s\n%s" % [part.name, "\n".join(overlaps)]).is_empty()
