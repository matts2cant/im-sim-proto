extends GdUnitTestSuite
## Physics and fire room (gallery room 3): static layout checks on the room scene. Distances are
## the ones the stations rely on (objects-and-fire.md): fire reach, the metal crate break, the
## LOS wall, the barrel chain spacing and the parapet distance.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/physics_fire/physics_fire_room.tscn")
const SMALL_CRATE_FIRE: FlammableConfig = preload("res://objects/small_crate/small_crate_fire.tres")
const BRAZIER_FIRE: FlammableConfig = preload("res://objects/brazier/brazier_fire.tres")
const BARREL: ExplosiveConfig = preload("res://objects/explosive_barrel/explosive_barrel_explosive.tres")
const GLASS_BOTTLE := "res://objects/glass_bottle/glass_bottle.tscn"
const CARRY_LIMIT := 20.0
const ROW: Array[String] = ["FireCrate1", "FireCrate2", "FireCrate3", "FireCrate4", "FireCrate5"]
const SIGNS: Dictionary[String, String] = {
	"FireSpread": "Fire spread\nmetal stops it · walls block it",
	"Brazier": "Brazier\ncarry or throw things in",
	"BarrelChain": "Barrel chain",
	"Barricade": "Burn the barricade",
	"Throwables": "Throw things · listen",
	"TooHeavy": "Too heavy\n(Combat Strength, M6)",
}

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())


func test_shell_is_a_20_by_16_hall_behind_a_corridor() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var corridor := _room.get_node("Shell/Corridor") as Room

	assert_vector(hall.size).is_equal(Vector3(20, 5, 16))
	assert_str(hall.floor_surface).is_equal("concrete")
	assert_float(corridor.wall_thickness).is_equal(hall.wall_thickness)
	# Shared walls (ADR 0043): the corridor starts at the hub wall's outer face (origin) and the
	# hall's interior starts at the corridor's north wall outer face.
	assert_float(corridor.position.z + corridor.size.z * 0.5).is_equal(0.0)
	var corridor_north := corridor.position.z - corridor.size.z * 0.5 - corridor.wall_thickness
	assert_float(hall.position.z + hall.size.z * 0.5).is_equal_approx(corridor_north, 0.0001)


func test_fire_row_spacing_and_metal_break() -> void:
	var reach := SMALL_CRATE_FIRE.radius
	for i in range(1, ROW.size()):
		var gap := _distance(ROW[i - 1], ROW[i]) - 0.6
		assert_float(gap).override_failure_message(ROW[i]).is_equal_approx(0.3, 0.001)
		assert_float(_distance(ROW[i - 1], ROW[i])).is_less(reach)
	# 0.6 m gaps either side of the 0.8 m metal crate: wood after it is 2.6 m from the last burning
	# crate, beyond the 1.5 m reach (and >= 1.6 m as the brief asks).
	assert_float(_floor_distance("FireCrate5", "FireMetalCrate") - 0.7).is_equal_approx(0.6, 0.001)
	assert_float(_floor_distance("FireMetalCrate", "FireCrate6") - 0.7).is_equal_approx(0.6, 0.001)
	assert_float(_distance("FireCrate5", "FireCrate6")).is_equal_approx(2.6, 0.001)
	assert_float(_distance("FireCrate5", "FireCrate6")).is_greater_equal(reach + 0.1)
	assert_float(_distance("FireCrate6", "FireCrate7") - 0.6).is_equal_approx(0.3, 0.001)
	for name: String in ["FireCrate1", "FireCrate2", "FireCrate3", "FireCrate4"]:
		assert_float(_distance(name, "FireCrate6")).is_greater(reach)


func test_crate_behind_wall_is_in_reach_but_walled_off() -> void:
	var hidden := _pos("FireCrateBehindWall")
	var first := _pos("FireCrate1")
	var wall := _room.get_node("FireSpread/Wall") as Ledge

	assert_float(hidden.distance_to(first)).is_equal_approx(0.8, 0.001)
	# Without the wall it would catch: 2.0 x (1 - 0.8 / 1.5) = 0.93 per pulse.
	assert_float(hidden.distance_to(first)).is_less(SMALL_CRATE_FIRE.radius)
	assert_float(hidden.distance_to(_pos("FireCrate2"))).is_greater(SMALL_CRATE_FIRE.radius)
	assert_float(wall.height).is_equal(2.0)
	assert_str(wall.surface).is_equal("concrete")
	# The wall's 0.1 m slab stands between the two crates, clear of both (0.05 m each side).
	assert_float(wall.position.x).is_equal_approx((hidden.x + first.x) * 0.5, 0.001)
	assert_float(wall.width).is_equal_approx(0.1, 0.001)
	assert_float(wall.position.z).is_greater(first.z + 0.3)
	assert_float(wall.position.z - wall.depth).is_less(first.z - 0.3)


func test_brazier_corner_objects_sit_outside_its_reach() -> void:
	var brazier := _pos("Brazier")
	var count := 0
	for child: Node in _room.get_node("BrazierCorner").get_children():
		if child.name == &"Brazier":
			continue
		var offset := (child as Node3D).position - brazier
		offset.y = 0.0
		# Nearest face of a <= 0.6 m object stays outside the 1.2 m fire.
		assert_float(offset.length() - 0.3).override_failure_message(child.name).is_greater(BRAZIER_FIRE.radius)
		count += 1
	assert_int(count).is_equal(6)
	assert_int(_room.get_node("BrazierCorner").find_children("BrazierCrate*", "", false, false).size()).is_equal(3)
	assert_int(_room.get_node("BrazierCorner").find_children("BrazierBox*", "", false, false).size()).is_equal(3)


func test_barrel_alley_spacing() -> void:
	var barrel1 := _pos("Barrel1")
	var barrel2 := _pos("Barrel2")

	assert_float(barrel1.distance_to(barrel2)).is_equal_approx(2.0, 0.001)
	for i in 3:
		var crate := _pos("StackCrate%d" % (i + 1))
		assert_float(crate.y).is_equal_approx(0.3 + 0.6 * i, 0.001)
		assert_float(Vector2(crate.x - barrel1.x, crate.z - barrel1.z).length()).is_equal_approx(1.8, 0.001)
	# The stack is on the far side of barrel 1 (barrel 2's blast barely reaches it).
	var stack := _pos("StackCrate1")
	assert_float(stack.distance_to(barrel2)).is_greater(stack.distance_to(barrel1) + 1.9)
	var parapet := _room.get_node("BarrelAlley/Parapet") as Ledge
	assert_float(parapet.height).is_equal(1.2)
	var back_face := parapet.position.z - parapet.depth
	for barrel: Vector3 in [barrel1, barrel2]:
		assert_float(absf(barrel.z - back_face)).is_greater_equal(6.0)
	# Nothing else that should survive within the blast radius.
	for node: Node in _room.find_children("*", "RigidBody3D", true, false):
		var body := node as Node3D
		if body.get_parent().name == &"BarrelAlley":
			continue
		var nearest := minf(body.position.distance_to(barrel1), body.position.distance_to(barrel2))
		assert_float(nearest).override_failure_message(body.name).is_greater(BARREL.damage_radius + 1.0)


func test_side_room_is_only_reached_through_the_barricaded_doorway() -> void:
	var side := _room.get_node("Shell/SideRoom") as Room
	var hall := _room.get_node("Shell/Hall") as Room
	var barricade := _room.get_node("BarricadeRoom/Barricade") as Node3D

	assert_vector(side.size).is_equal(Vector3(3, 3, 3))
	assert_int(side.openings.size()).is_equal(1)
	var door := side.openings[0]
	assert_float(door.width).is_equal(1.2)
	assert_float(door.height).is_equal(2.2)
	assert_float(door.sill).is_equal(0.0)
	# Shared wall: the side room's interior starts at the hall's west wall outer face.
	var hall_west_outer := hall.position.x - hall.size.x * 0.5 - hall.wall_thickness
	assert_float(side.position.x + side.size.x * 0.5).is_equal_approx(hall_west_outer, 0.0001)
	var hall_door := hall.openings[1]
	assert_float(hall.position.z + hall_door.offset).is_equal_approx(side.position.z + door.offset, 0.0001)
	assert_float(hall_door.width).is_equal(door.width)
	# The barricade stands in the middle of the shared wall, across the doorway.
	assert_vector(barricade.position).is_equal_approx(
		Vector3(hall_west_outer + hall.wall_thickness * 0.5, 0, side.position.z), Vector3.ONE * 0.001
	)
	assert_vector(barricade.basis.x.abs()).is_equal_approx(Vector3(0, 0, 1), Vector3.ONE * 0.001)
	assert_bool(barricade.is_in_group(LevelNavigation.SOURCE_GROUP)).is_true()


func test_side_room_crate_holds_two_bottles_out_of_the_barricade_fire() -> void:
	var crate := _room.get_node("BarricadeRoom/SideRoomCrate") as Node3D
	var contents := (crate.get_node("Breakable") as Breakable).contents
	var barricade_fire := _room.get_node("BarricadeRoom/Barricade/Flammable") as Flammable

	assert_int(contents.size()).is_equal(2)
	for scene: PackedScene in contents:
		assert_str(scene.resource_path).is_equal(GLASS_BOTTLE)
	var fire_centre := barricade_fire.transform * Vector3.ZERO
	var from := (_room.get_node("BarricadeRoom/Barricade") as Node3D).transform * fire_centre
	assert_float(from.distance_to(crate.position)).is_greater(barricade_fire.config.radius)


func test_throwables_table_and_metal_floor() -> void:
	var table := _room.get_node("Throwables/Table") as Ledge
	var floor_patch := _room.get_node("Throwables/MetalFloor") as SurfaceFloor

	assert_float(table.height).is_equal(1.0)
	assert_str(table.surface).is_equal("wood")
	assert_str(floor_patch.surface).is_equal("metal")
	assert_vector(floor_patch.size).is_equal(Vector2(4, 4))
	assert_float(floor_patch.position.y).is_equal_approx(0.02, 0.0001)
	var half_heights := {"TableBottle": 0.15, "TableBox": 0.25, "TableCrate": 0.3}
	var counts := {"TableBottle": 0, "TableBox": 0, "TableCrate": 0}
	for child: Node in _room.get_node("Throwables").get_children():
		var body := child as PhysicsObject
		if body == null:
			continue
		var kind := String(child.name).rstrip("0123456789")
		counts[kind] += 1
		# Resting on the table top, within its footprint.
		var half: float = half_heights[kind]
		assert_float(body.position.y - half).override_failure_message(child.name).is_equal_approx(1.0, 0.002)
		assert_float(absf(body.position.x - table.position.x)).is_less(table.width * 0.5)
		assert_bool(body.position.z < table.position.z and body.position.z > table.position.z - table.depth).is_true()
	assert_dict(counts).is_equal({"TableBottle": 4, "TableBox": 2, "TableCrate": 2})


func test_too_heavy_objects_exceed_the_carry_limit() -> void:
	for name: String in ["HeavyLargeCrate", "HeavyMetalCrate"]:
		var body := _room.get_node("TooHeavy/" + name) as RigidBody3D
		assert_float(body.mass).override_failure_message(name).is_greater(CARRY_LIMIT)


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


func _pos(name: String) -> Vector3:
	return (_room.find_child(name, true, false) as Node3D).position


## Distance between two object centres (the fire falloff is measured centre to centre).
func _distance(a: String, b: String) -> float:
	return _pos(a).distance_to(_pos(b))


## Horizontal (floor plan) distance between two objects: their gap is this minus half sizes.
func _floor_distance(a: String, b: String) -> float:
	var offset := _pos(a) - _pos(b)
	return Vector2(offset.x, offset.z).length()
