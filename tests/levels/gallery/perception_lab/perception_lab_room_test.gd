extends GdUnitTestSuite
## Gallery room 2, the perception lab (levels/gallery/perception_lab/perception_lab.tscn), on its
## own: shell and doorway, the three lane strips and their surfaces, lamp placement and circuits
## (each lane's lamps out of range of the other lanes' centres), the breaker on the west wall, the
## guard post marker, signs, and no coplanar faces with different materials. Room-local
## coordinates: origin on the hub wall's outer face, -Z away from the hub.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/perception_lab/perception_lab.tscn")
## Lane centres (x) at z -8; floor strips 4.8 x 8 m from z -4 to -12.
const LANES: Dictionary[String, float] = {"DarkFloor": -2.5, "DimFloor": 2.5, "LitFloor": 7.5}
const SURFACES: Dictionary[String, String] = {"DarkFloor": "carpet", "DimFloor": "wood", "LitFloor": "metal"}
const LANE_Z := -8.0
## Chest point of a standing body (feet + 1.0 m) on a lane centre.
const CHEST := 1.0

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())
	add_child(_room)


func _lamp(lamp_name: String) -> Node3D:
	return _room.get_node("Lamps/" + lamp_name) as Node3D


func _light(lamp_name: String) -> OmniLight3D:
	return _lamp(lamp_name).get_node("Light") as OmniLight3D


func test_hall_shell_and_doorway() -> void:
	var hall := _room.get_node("Shell/Hall") as Room

	assert_vector(hall.size).is_equal(Vector3(16, 4, 18))
	assert_float(hall.wall_thickness).is_equal(0.5)
	# Interior x -5.5 .. 10.5, z 0 .. -18: the south wall overlaps the hub's north wall.
	assert_vector(hall.position).is_equal(Vector3(2.5, 0, -9))
	assert_int(hall.openings.size()).is_equal(1)
	var door := hall.openings[0]
	assert_int(door.wall).is_equal(RoomOpening.Wall.SOUTH)
	# Centred on the room origin (the hub doorway), 2 x 3 m.
	assert_float(hall.position.x + door.offset).is_equal_approx(0.0, 0.0001)
	assert_float(door.width).is_equal(2.0)
	assert_float(door.height).is_equal(3.0)


func test_lane_strips_have_their_surfaces() -> void:
	for strip_name: String in LANES:
		var strip := _room.get_node("Lanes/" + strip_name) as SurfaceFloor

		assert_str(strip.surface).is_equal(SURFACES[strip_name])
		assert_float(strip.position.x).is_equal_approx(LANES[strip_name], 0.0001)
		assert_float(strip.position.z).is_equal_approx(LANE_Z, 0.0001)
		assert_float(strip.position.y).is_equal_approx(0.02, 0.0001)
		assert_vector(strip.size).is_equal(Vector2(4.8, 8))


func test_lamps_and_circuits() -> void:
	for lamp_name: String in ["LitLamp1", "LitLamp2", "DimLamp"]:
		assert_str(String(Powered.of(_lamp(lamp_name)).circuit)).is_equal("perception_lab")
	for lamp_name: String in ["ApronLamp", "BreakerLamp"]:
		assert_str(String(Powered.of(_lamp(lamp_name)).circuit)).is_equal("perception_lab_apron")
	assert_float(_lamp("LitLamp1").position.x).is_equal(7.5)
	assert_float(_lamp("LitLamp2").position.x).is_equal(7.5)
	assert_vector(_lamp("DimLamp").position).is_equal(Vector3(2.5, 4, -8))
	assert_float(_light("DimLamp").omni_range).is_less_equal(4.0)
	assert_float(_light("DimLamp").light_energy).is_less(_light("LitLamp1").light_energy)


func test_each_lamp_stays_out_of_range_of_the_other_lanes() -> void:
	# Lamp -> lane centres (chest height) it must not reach, with at least 0.4 m to spare.
	var away: Dictionary[String, Array] = {
		"LitLamp1": [-2.5, 2.5],
		"LitLamp2": [-2.5, 2.5],
		"DimLamp": [-2.5, 7.5],
		"ApronLamp": [-2.5, 2.5, 7.5],
		"BreakerLamp": [-2.5, 2.5, 7.5],
	}
	for lamp_name: String in away:
		var light := _light(lamp_name)
		for x: float in away[lamp_name]:
			var distance := light.global_position.distance_to(Vector3(x, CHEST, LANE_Z))
			assert_float(distance).override_failure_message("%s to lane %s" % [lamp_name, x]).is_greater(
				light.omni_range + 0.4
			)


func test_breaker_on_the_west_wall_near_the_doorway() -> void:
	var panel := _room.get_node("Breaker") as Node3D
	var breaker := Usable.of(panel) as CircuitBreaker

	assert_object(breaker).is_not_null()
	assert_str(String(breaker.circuit)).is_equal("perception_lab")
	assert_bool(breaker.closed).is_true()
	# Back on the west wall's inner face (x -5.5), facing into the room (+X), at hand height.
	assert_vector(panel.position).is_equal(Vector3(-5.5, 1.2, -2))
	assert_vector(panel.global_basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)


func test_guard_post_faces_the_lanes_from_4_to_12_m() -> void:
	var post := _room.get_node("GuardPost") as Marker3D

	assert_vector(post.position).is_equal(Vector3(2.5, 0, -16))
	# Facing +Z (its -Z axis), towards the lanes and the doorway.
	assert_vector(-post.global_basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)
	for x: float in LANES.values():
		var distance := Vector2(post.position.x, post.position.z).distance_to(Vector2(x, LANE_Z))
		assert_float(distance).is_between(4.0, 12.0)


func test_signs() -> void:
	var texts: Array[String] = []
	for sign: Node in _room.get_node("Labels").get_children():
		texts.append(String(sign.get("text")))

	assert_array(texts).contains(["2 Perception lab", "Dark · carpet", "Dim · wood", "Lit · metal"])
	assert_str((_room.get_node("Labels/Breaker") as Node).get("text")).contains("Breaker")
	assert_str((_room.get_node("Labels/Gauge") as Node).get("text")).contains("Light gauge")


func test_no_coplanar_faces_with_different_materials() -> void:
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(_room)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()
