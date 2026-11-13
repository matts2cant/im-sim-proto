extends GdUnitTestSuite
## Shooting range M14c additions (ADR 0131) on the room scene alone, loaded once: the grenade lane
## (dummies at their gaps from the target, centre to centre, the throwing line 12 m out, nothing in
## the throw's path, the frag's reach clear of the rest of the range), the grenade table (every type,
## resting on the top, restocked by its button), the mine corridor (wide enough, its openings lined
## up with the hall and the EMP room, a plain unlocked door), the EMP and jamming room (a wireless
## camera on its access point, a turret aimed at guards only, a powered lamp, their distances, no
## other electronics in the range), wall devices clear of doors and signs, no coplanar meshes; in the
## tree, a jamming field by the camera jams it and an EMP under it switches it off alone.
## Room-local coordinates.

const Wait := preload("res://tests/helpers/wait.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const WallDeviceChecks := preload("res://tests/levels/wall_device_checks.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/shooting_range/shooting_range_room.tscn")
const FRAG: ExplosiveConfig = preload("res://objects/explosives/payloads/frag_explosive.tres")
const EMP: EmpConfig = preload("res://objects/explosives/emp/emp.tres")
const JAMMING_FIELD: PackedScene = preload("res://objects/explosives/jamming_field/jamming_field.tscn")
const JAMMING: Resource = preload("res://objects/explosives/jamming_field/jamming_field.tres")
const ORIGIN := Vector3(-480, 0, 300)
const GRENADES: Array[String] = ["frag_grenade", "gas_grenade", "emp_grenade", "jamming_grenade"]
## Dummy -> gap from the target (centre to centre, m).
const DUMMIES: Dictionary[String, float] = {"Dummy2m": 2.0, "Dummy4m": 4.0, "Dummy6m": 6.0}
## Half the dummy's span across the arms (1.07 m), and the player's capsule.
const ARM_HALF := 0.535
const CAPSULE := 0.7
## Half the grenade pickup's box height (0.105 m).
const PICKUP_HALF := 0.0525
## Corner device pairs -> horizontal distance (floor plan, origin to origin, m), as documented.
const CORNER_GAPS: Dictionary[String, float] = {
	"Camera-Turret": 6.94,
	"Camera-Ap": 9.91,
	"Camera-Lamp": 5.58,
	"Turret-Ap": 3.35,
	"Turret-Lamp": 3.81,
	"Ap-Lamp": 5.21,
}

var _room: Node3D


func before() -> void:
	_room = ROOM_SCENE.instantiate() as Node3D
	_room.position = ORIGIN
	add_child(_room)
	await KitGeometry.settle(get_tree(), 5)


func after() -> void:
	_room.free()


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func test_grenade_dummies_stand_at_their_gaps_from_the_target() -> void:
	var target := _pos("GrenadeLane/Target")
	var line := _pos("GrenadeLane/ThrowLine")
	for dummy_name: String in DUMMIES:
		var dummy := _room.get_node("GrenadeLane/" + dummy_name) as TrainingDummy
		var gap := Vector2(dummy.position.x - target.x, dummy.position.z - target.z).length()
		assert_float(gap).override_failure_message(dummy_name).is_equal_approx(DUMMIES[dummy_name], 0.05)
		# Facing the throwing line, its sign above it saying its gap.
		assert_vector(-dummy.basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)
		var sign := _room.get_node("Labels/Grenade%dm" % int(DUMMIES[dummy_name])) as Sign
		assert_str(sign.text).starts_with("%d m from the target" % int(DUMMIES[dummy_name]))
		assert_float(Vector2(sign.position.x - dummy.position.x, sign.position.z - dummy.position.z).length()).is_less(
			0.01
		)
		# Out of the throw's path (the line's axis, 1 m either side): a rolling grenade passes them.
		assert_float(absf(dummy.position.x - target.x) - ARM_HALF).override_failure_message(dummy_name).is_greater(1.0)
	# The target 12 m from the throwing line, centre to centre, straight ahead (-Z).
	assert_float(line.z - target.z).is_equal_approx(12.0, 0.0001)
	assert_float(line.x).is_equal_approx(target.x, 0.0001)
	assert_str((_room.get_node("Labels/GrenadeTarget") as Sign).text).contains("12 m")


func test_a_frag_on_the_target_reaches_none_of_the_other_stations() -> void:
	var target := _pos("GrenadeLane/Target")
	var reach := FRAG.damage_radius + 1.0
	var lane := _room.get_node("GrenadeLane")
	for node: Node in _room.find_children("*", "PhysicsBody3D", true, false):
		if lane.is_ancestor_of(node) or not (node is RigidBody3D or node is TrainingDummy):
			continue
		var at := (node as Node3D).global_position - _room.global_position
		assert_float(Vector2(at.x - target.x, at.z - target.z).length()).override_failure_message(node.name).is_greater(
			reach
		)
	# The table, the throwing line and the walking dummy's whole walk too.
	var table := _room.get_node("GrenadeLane/Table") as Ledge
	assert_float(target.z - (table.position.z - table.depth)).is_less(-reach)
	assert_float(target.z - _pos("GrenadeLane/ThrowLine").z).is_less(-reach)


func test_the_table_holds_every_grenade_type_and_restocks() -> void:
	var table := _room.get_node("GrenadeLane/Table") as Ledge
	var found: Array[String] = []
	for node: Node in _room.get_node("GrenadeLane").get_children():
		var pickup := ItemPickup.of(node)
		if pickup == null:
			continue
		var body := node as RigidBody3D
		found.append(String(pickup.item.id))
		assert_int(pickup.count).override_failure_message(node.name).is_greater_equal(3)
		# Resting on the table top (placed 5 mm above it, settled), inside its footprint.
		var above := body.position.y - PICKUP_HALF - table.height
		assert_float(above).override_failure_message(node.name).is_between(-0.002, 0.01)
		assert_float(absf(body.position.x - table.position.x) + 0.05).is_less(table.width * 0.5)
		assert_bool(body.position.z < table.position.z and body.position.z > table.position.z - table.depth).is_true()
	found.sort()
	var expected := GRENADES.duplicate()
	expected.sort()
	assert_array(found).is_equal(expected)

	# Two taken, one knocked off: the button puts all three back.
	ItemPickup.of(_room.get_node("GrenadeLane/Frag")).consume()
	ItemPickup.of(_room.get_node("GrenadeLane/Gas")).consume()
	var emp := _room.get_node("GrenadeLane/Emp") as RigidBody3D
	var emp_place := emp.position
	emp.position += Vector3(0.5, -0.9, 1.0)
	await Wait.frames(get_tree(), 2)
	Usable.of(_room.get_node("GrenadeLane/Restock")).use(null)
	for pickup_name: String in ["Frag", "Gas", "Emp", "Jamming"]:
		var pickup := ItemPickup.of(_room.get_node_or_null("GrenadeLane/" + pickup_name))
		assert_object(pickup).override_failure_message(pickup_name).is_not_null()
		assert_int(pickup.count).is_equal(5)
	# Back where the level placed it (it settled 5 mm since).
	assert_vector(emp.position).is_equal_approx(emp_place, Vector3.ONE * 0.01)
	assert_int(EventLog.find(&"range.restocked")[0].data["count"]).is_equal(3)


func test_mine_corridor_is_wide_enough_and_ends_in_a_door() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var corridor := _room.get_node("Shell/MineCorridor") as Room
	var emp_room := _room.get_node("Shell/EmpRoom") as Room
	# A capsule (0.7 m) with at least 0.45 m either side (passages >= 1.2 m, metrics.md).
	assert_float(corridor.size.z).is_greater_equal(CAPSULE + 0.9)
	assert_float(corridor.size.y).is_greater_equal(2.5)
	# Shared walls (ADR 0043): the corridor starts at the hall's east wall outer face, the EMP room at
	# the corridor's east wall outer face; same thickness.
	var hall_outer := hall.position.x + hall.size.x * 0.5 + hall.wall_thickness
	assert_float(corridor.position.x - corridor.size.x * 0.5).is_equal_approx(hall_outer, 0.0001)
	var corridor_outer := corridor.position.x + corridor.size.x * 0.5 + corridor.wall_thickness
	assert_float(emp_room.position.x - emp_room.size.x * 0.5).is_equal_approx(corridor_outer, 0.0001)
	for room: Room in [corridor, emp_room]:
		assert_float(room.wall_thickness).is_equal(hall.wall_thickness)
	# The hall's east opening and the corridor's west opening line up, as wide as the corridor.
	var hall_door := hall.openings[1]
	var corridor_door := corridor.openings[0]
	assert_int(hall_door.wall).is_equal(RoomOpening.Wall.EAST)
	assert_int(corridor_door.wall).is_equal(RoomOpening.Wall.WEST)
	assert_float(hall.position.z + hall_door.offset).is_equal_approx(corridor.position.z + corridor_door.offset, 0.0001)
	assert_float(hall_door.width).is_equal(corridor_door.width)
	assert_float(hall_door.height).is_equal(corridor_door.height)
	assert_float(corridor_door.width).is_equal_approx(corridor.size.z, 0.0001)
	# The far end: the corridor's east opening and the EMP room's west opening line up with a plain,
	# unlocked door in the shared wall.
	var east := corridor.openings[1]
	var emp_door := emp_room.openings[0]
	assert_int(east.wall).is_equal(RoomOpening.Wall.EAST)
	assert_int(emp_door.wall).is_equal(RoomOpening.Wall.WEST)
	assert_float(corridor.position.z + east.offset).is_equal_approx(emp_room.position.z + emp_door.offset, 0.0001)
	var door := _room.get_node("MineCorridor/Door") as Node3D
	assert_float(door.position.x).is_equal_approx(corridor_outer - corridor.wall_thickness * 0.5, 0.0001)
	assert_float(door.position.z).is_equal_approx(corridor.position.z + east.offset, 0.0001)
	assert_bool(Lockable.of(door).locked).is_false()
	assert_float(east.width).is_greater_equal(CAPSULE + 0.4)


func test_corner_devices_are_electronic_and_the_camera_is_wireless() -> void:
	var camera := Device.of(_room.get_node("EmpCorner/Camera"))
	var ap := Device.of(_room.get_node("EmpCorner/Ap"))
	var turret := Device.of(_room.get_node("EmpCorner/Turret"))
	# The camera links by radio to the access point (in range), nothing else does.
	assert_object(AccessPoint.of(ap.entity)).is_not_null()
	assert_object(camera.wireless_link()).is_same(ap)
	assert_bool(turret.wireless.is_empty() and turret.links.is_empty()).is_true()
	assert_int(NetworkState.state_of(camera, NetworkState.links_of(camera))).is_equal(StatusLight.State.UP)
	# Electronic: a Powered on each (the EMP cuts it), the lamp's light under it.
	for entity_name: String in ["Camera", "Ap", "Turret", "Lamp"]:
		(
			assert_object(Powered.of(_room.get_node("EmpCorner/" + entity_name)))
			. override_failure_message(entity_name)
			. is_not_null()
		)
	# The turret shoots guards only, never the player testing the room.
	var behaviour := _room.get_node("EmpCorner/Turret/TurretBehaviour") as Turret
	var hostile: Array = behaviour.config.presets[behaviour.config.default_preset]
	assert_bool(hostile.has(&"actor.player")).is_false()
	assert_bool(hostile.has(&"actor.guard")).is_true()


func test_corner_devices_keep_their_stated_distances() -> void:
	var corner := _room.get_node("EmpCorner")
	for pair: String in CORNER_GAPS:
		var names := pair.split("-")
		var a := _pos("EmpCorner/" + names[0])
		var b := _pos("EmpCorner/" + names[1])
		var gap := Vector2(a.x - b.x, a.z - b.z).length()
		assert_float(gap).override_failure_message(pair).is_equal_approx(CORNER_GAPS[pair], 0.01)
	# An EMP (6 m) under the camera spares the turret and the other way round.
	assert_float(CORNER_GAPS["Camera-Turret"]).is_greater(float(EMP.get("radius")) + 0.5)
	# No other electronics in the range: every Device or Powered entity is one of the corner's.
	for node: Node in _room.find_children("*", "", true, false):
		if node is Device or node is Powered:
			assert_bool(corner.is_ancestor_of(node)).override_failure_message(str(_room.get_path_to(node))).is_true()
	# The grenade lane (target, line, table) beyond a jamming field's reach (10 m) of every corner device.
	var jam := float(JAMMING.get("radius"))
	for station: String in ["GrenadeLane/Target", "GrenadeLane/ThrowLine", "GrenadeLane/Table"]:
		for device: Node in corner.get_children():
			var gap := _pos(station).distance_to((device as Node3D).position)
			assert_float(gap).override_failure_message("%s - %s" % [station, device.name]).is_greater(jam + 5.0)


func test_wall_devices_keep_clear_of_doors_and_signs() -> void:
	var problems := WallDeviceChecks.problems(_room)

	assert_array(Array(problems)).override_failure_message("\n".join(problems)).is_empty()


func test_no_coplanar_meshes_in_the_new_parts() -> void:
	# Each new part on its own (the training dummy's shadow proxy overlaps its model on purpose: the
	# dummy is the lanes' existing prop, not a new part).
	for path: String in ["GrenadeLane", "MineCorridor", "EmpCorner"]:
		for part: Node in _room.get_node(path).get_children():
			if part is TrainingDummy:
				continue
			var overlaps := KitGeometry.coplanar_mesh_overlaps(part)
			assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


# Last in the suite: the EMP's outage lasts 20 s.
func test_a_jammer_jams_the_camera_and_an_emp_at_its_foot_catches_it_alone() -> void:
	var camera := Device.of(_room.get_node("EmpCorner/Camera"))
	var field := ExplosivePayload.spawn_in_level(JAMMING_FIELD, _room, _room.to_global(Vector3(36.5, 0.1, -10)))
	await Wait.frames(get_tree(), 2)
	assert_int(NetworkState.state_of(camera, NetworkState.links_of(camera))).is_equal(StatusLight.State.JAMMED)
	field.free()
	await Wait.frames(get_tree(), 2)
	assert_int(NetworkState.state_of(camera, NetworkState.links_of(camera))).is_equal(StatusLight.State.UP)

	# On the floor under the camera: the turret, the lamp and the access point are beyond 6 m.
	StimulusSystem.emit(EmpPulse.make(EMP, _room.to_global(Vector3(37.0, 0.1, -10))))
	await Wait.frames(get_tree(), 3)

	assert_bool(Powered.of(camera.entity).is_on()).is_false()
	for entity_name: String in ["Lamp", "Turret", "Ap"]:
		var powered := Powered.of(_room.get_node("EmpCorner/" + entity_name))
		assert_bool(powered.is_on()).override_failure_message(entity_name).is_true()


func _pos(path: String) -> Vector3:
	return (_room.get_node(path) as Node3D).position
