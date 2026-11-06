extends GdUnitTestSuite
## Shooting range (gallery room 4): static layout checks on the room scene. Distances are the ones
## the stations rely on (hub-and-gallery.md): dummies 5 / 10 / 20 / 40 m from the firing line facing
## it, the melee pair's facing and awareness, the blast lane lines, barrel spacing and the medkits.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/shooting_range/shooting_range_room.tscn")
const BARREL: ExplosiveConfig = preload("res://objects/explosive_barrel/explosive_barrel_explosive.tres")
const HAZARD: Material = preload("res://assets/materials/graybox/hazard.tres")
## Room-local z of the firing line (the counter's lip, 4 m inside the hall entrance).
const FIRING_LINE_Z := -8.0
const LANES: Dictionary[String, Vector2] = {
	"Dummy5m": Vector2(1.75, 5.0),
	"Dummy10m": Vector2(4.25, 10.0),
	"Dummy20m": Vector2(6.75, 20.0),
	"Dummy40m": Vector2(9.25, 40.0),
}
const SIGNS: Dictionary[String, String] = {
	"FiringLine": "Firing line\n1 pistol · 2 baton · R reload",
	"Lane1": "5 m",
	"Lane2": "10 m",
	"Lane3": "20 m",
	"Lane4": "40 m",
	"MeleeUnaware": "Sneak behind · baton KO",
	"MeleeAware": "Aware · 3 hits",
	"BlastLane": "Blast lane\nStand on a line\nshoot the barrel",
	"Blast2m": "2 m",
	"Blast4m": "4 m",
	"Blast6m": "6 m",
	"FarWall": "Long shots",
	"Medkits": "Medkits · E heals 30",
}

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())


func test_shell_is_a_14_by_48_hall_behind_a_corridor() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var corridor := _room.get_node("Shell/Corridor") as Room

	assert_vector(hall.size).is_equal(Vector3(14, 5, 48))
	assert_str(hall.floor_surface).is_equal("concrete")
	assert_float(corridor.wall_thickness).is_equal(hall.wall_thickness)
	# Shared walls (ADR 0043): the corridor starts at the hub wall's outer face (origin) and the
	# hall's interior starts at the corridor's north wall outer face.
	assert_float(corridor.position.z + corridor.size.z * 0.5).is_equal(0.0)
	var corridor_north := corridor.position.z - corridor.size.z * 0.5 - corridor.wall_thickness
	assert_float(hall.position.z + hall.size.z * 0.5).is_equal_approx(corridor_north, 0.0001)
	# The hall's door lines up with the corridor (local x 0) although the hall is off-centre.
	var door := hall.openings[0]
	assert_int(door.wall).is_equal(RoomOpening.Wall.SOUTH)
	assert_float(hall.position.x + door.offset).is_equal_approx(0.0, 0.0001)
	assert_float(door.width).is_equal(corridor.size.x)


func test_firing_line_counter_and_stripe() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var counter := _room.get_node("FiringLine/Counter") as Ledge
	var stripe := _room.get_node("FiringLine/Stripe") as SurfaceFloor
	var west := hall.position.x - hall.size.x * 0.5
	var east := hall.position.x + hall.size.x * 0.5

	assert_float(counter.height).is_equal(1.0)
	assert_str(counter.surface).is_equal("wood")
	assert_float(counter.position.z).is_equal(FIRING_LINE_Z)
	# 4 m inside the entrance (the hall's south wall inner face).
	assert_float(hall.position.z + hall.size.z * 0.5 - counter.position.z).is_equal_approx(4.0, 0.0001)
	# Wall to wall but for a 1.2 m gap at the west end.
	assert_float(counter.position.x + counter.width * 0.5).is_equal_approx(east, 0.0001)
	assert_float(counter.position.x - counter.width * 0.5 - west).is_equal_approx(1.2, 0.0001)
	assert_object(stripe.material_override).is_same(HAZARD)
	assert_vector(stripe.size).is_equal_approx(Vector2(hall.size.x, 0.1), Vector2.ONE * 0.0001)
	assert_float(stripe.position.y).is_equal_approx(0.02, 0.0001)
	# Flush with the counter's lip, on the player's side.
	assert_float(stripe.position.z - 0.05).is_equal_approx(FIRING_LINE_Z, 0.0001)


func test_lane_dummies_face_the_firing_line_at_their_distances() -> void:
	for name: String in LANES:
		var dummy := _room.get_node("Lanes/" + name) as TrainingDummy
		var lane: Vector2 = LANES[name]

		assert_vector(dummy.position).override_failure_message(name).is_equal_approx(
			Vector3(lane.x, 0, FIRING_LINE_Z - lane.y), Vector3.ONE * 0.0001
		)
		# A dummy faces its -Z (the visor side): +Z here, towards the firing line.
		assert_vector(-dummy.basis.z).override_failure_message(name).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)
		assert_bool((dummy.get_node("Awareness") as Awareness).aware).is_false()


func test_lanes_are_2_5_m_wide_between_1_2_m_dividers() -> void:
	var xs: Array[float] = []
	for i in 4:
		var divider := _room.get_node("Lanes/Divider%d" % (i + 1)) as Ledge
		assert_float(divider.height).is_equal(1.2)
		assert_str(divider.surface).is_equal("concrete")
		# 2 m past the counter (its lip, 0.6 m deep) and 6 m long.
		assert_float(divider.position.z).is_equal_approx(FIRING_LINE_Z - 2.0, 0.0001)
		assert_float(divider.depth).is_equal(6.0)
		xs.append(divider.position.x)
	for i in range(1, xs.size()):
		assert_float(xs[i] - xs[i - 1]).is_equal_approx(2.5, 0.0001)
	# Each lane dummy stands in the middle of its lane.
	var i := 0
	for name: String in LANES:
		var x := (_room.get_node("Lanes/" + name) as Node3D).position.x
		var right := xs[i + 1] if i + 1 < xs.size() else xs[i] + 2.5
		assert_float(x).override_failure_message(name).is_equal_approx((xs[i] + right) * 0.5, 0.0001)
		i += 1


func test_melee_pair_facing_and_awareness() -> void:
	var unaware := _room.get_node("Melee/UnawareDummy") as TrainingDummy
	var aware := _room.get_node("Melee/AwareDummy") as TrainingDummy
	var counter := _room.get_node("FiringLine/Counter") as Ledge

	assert_float(unaware.position.distance_to(aware.position)).is_equal_approx(3.0, 0.0001)
	# Both on the player's side of the counter.
	for dummy: TrainingDummy in [unaware, aware]:
		assert_float(dummy.position.z).is_greater(counter.position.z + 1.0)
	# The unaware one turns its back on the walkway (faces the east wall); the aware one faces it.
	assert_vector(-unaware.basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	assert_vector(-aware.basis.z).is_equal_approx(Vector3.LEFT, Vector3.ONE * 0.0001)
	assert_bool((unaware.get_node("Awareness") as Awareness).is_aware()).is_false()
	assert_bool((aware.get_node("Awareness") as Awareness).is_aware()).is_true()


func test_blast_lane_lines_and_crates() -> void:
	var barrel := _pos("BlastLane/Barrel")
	var dividers := _room.get_node("Lanes/Divider1") as Ledge

	# Beside the lanes (west of the first divider) and past the dividers' far end.
	assert_float(barrel.x).is_less(dividers.position.x - 1.0)
	assert_float(barrel.z).is_less(dividers.position.z - dividers.depth)
	for metres: int in [2, 4, 6]:
		var stripe := _room.get_node("BlastLane/Stripe%dm" % metres) as SurfaceFloor
		assert_object(stripe.material_override).is_same(HAZARD)
		assert_float(stripe.size.y).is_equal_approx(0.1, 0.0001)
		assert_float(stripe.position.x).is_equal_approx(barrel.x, 0.0001)
		# Centre to centre, towards the firing line.
		assert_float(stripe.position.z - barrel.z).is_equal_approx(metres, 0.0001)
	for name: String in ["Crate1", "Crate2"]:
		var crate := _pos("BlastLane/" + name)
		var gap := Vector2(crate.x - barrel.x, crate.z - barrel.z).length() - 0.3 - 0.3
		assert_float(gap).override_failure_message(name).is_equal_approx(1.5, 0.01)
		# Behind the barrel, away from the lines.
		assert_float(crate.z).is_less(barrel.z)
	# Nothing else in the room within the blast radius (+1 m) of the blast lane barrel.
	_assert_alone(barrel, ["Barrel", "Crate1", "Crate2"])


func test_far_wall_barrels_and_metal_crate() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var far_wall := hall.position.z - hall.size.z * 0.5
	var barrels: Array[Vector3] = [_pos("FarWall/Barrel1"), _pos("FarWall/Barrel2"), _pos("FarWall/Barrel3")]
	var crate := _pos("FarWall/MetalCrate")

	assert_float(FIRING_LINE_Z - far_wall).is_equal_approx(44.0, 0.0001)
	for i in barrels.size():
		assert_float(barrels[i].z - 0.3 - far_wall).is_equal_approx(0.1, 0.0001)
		if i > 0:
			# 3 m gaps (0.6 m barrels): no chain (2 m chains) and a near miss stays under 25 damage.
			assert_float(barrels[i].distance_to(barrels[i - 1]) - 0.6).is_equal_approx(3.0, 0.0001)
	var falloff := StimulusPropagation.falloff(BARREL.damage_intensity, BARREL.damage_radius, 3.6)
	assert_float(falloff).is_less(25.0)
	assert_float(crate.x).is_equal_approx((barrels[1].x + barrels[2].x) * 0.5, 0.0001)
	assert_float(crate.z).is_equal_approx(barrels[1].z, 0.0001)
	# The 40 m dummy survives a far-wall barrel going off.
	for barrel: Vector3 in barrels:
		assert_float(barrel.distance_to(_pos("Lanes/Dummy40m"))).is_greater(BARREL.damage_radius + 1.0)


func test_three_medkits_on_the_table_near_the_entrance() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var table := _room.get_node("Medkits/Table") as Ledge
	var entrance := hall.position.z + hall.size.z * 0.5

	assert_float(table.height).is_equal(1.0)
	assert_float(entrance - table.position.z).is_less(0.5)
	var count := 0
	for child: Node in _room.get_node("Medkits").get_children():
		if not child.name.begins_with("Medkit"):
			continue
		var kit := child as RigidBody3D
		# M5 inventory pickups: E takes one, using it from the belt heals.
		assert_str(String(ItemPickup.of(kit).item.id)).is_equal("medkit")
		# Resting on the table top (0.09 m case), within its footprint.
		assert_float(kit.position.y - 0.045).is_equal_approx(table.height, 0.001)
		assert_float(absf(kit.position.x - table.position.x) + 0.12).is_less(table.width * 0.5)
		assert_bool(kit.position.z < table.position.z and kit.position.z > table.position.z - table.depth).is_true()
		count += 1
	assert_int(count).is_equal(3)


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


func _pos(path: String) -> Vector3:
	return (_room.get_node(path) as Node3D).position


## Every physics object and dummy other than `except` is beyond the blast radius + 1 m of `origin`.
func _assert_alone(origin: Vector3, except: Array[String]) -> void:
	for node: Node in _room.find_children("*", "PhysicsBody3D", true, false):
		if except.has(String(node.name)) or not (node is RigidBody3D or node is TrainingDummy):
			continue
		var distance := (node as Node3D).position.distance_to(origin)
		assert_float(distance).override_failure_message(node.name).is_greater(BARREL.damage_radius + 1.0)
