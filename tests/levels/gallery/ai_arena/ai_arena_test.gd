extends GdUnitTestSuite
## Gallery room 6, the AI arena (levels/gallery/ai_arena/ai_arena.tscn), on its own: shell and
## doorways (hub door, radio room door through the shared wall), both doorways clear for the
## player capsule, lamps present and out of range of the dark corner, the guards (named by
## loadout) with their routes and posts, the downed guard unconscious beside patrol route A with
## room to stand next to it, routes clear of the crates, the alarm devices cabled (controller,
## switch, two sirens, panic button, radio base station: ADR 0077), signs, and no coplanar faces
## with different materials. Room-local coordinates: origin on the hub wall's outer face, +Z away from the hub
## (the room is not turned in the hub: guards turn by their local yaw).

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const ROOM_SCENE: PackedScene = preload("res://levels/gallery/ai_arena/ai_arena.tscn")
## Dark corner floor area (x 3..6, z 17..20) sampled at body-point heights (feet, chest, head).
const DARK_CORNER: Array[Vector3] = [
	Vector3(3, 0, 17), Vector3(6, 0, 17), Vector3(3, 0, 20), Vector3(6, 0, 20), Vector3(4.5, 0, 18.5)
]
const BODY_HEIGHTS: Array[float] = [0.2, 1.0, 1.6]
const GUARDS: Array[String] = ["GuardPistolA", "GuardPistolB", "GuardBatonPost", "GuardBatonDowned", "GuardPistolRadio"]
## Player capsule (metrics.md): radius 0.35 m, standing height 1.8 m.
const CAPSULE_RADIUS := 0.35
const CAPSULE_HEIGHT := 1.8

var _room: Node3D


func before_test() -> void:
	_room = auto_free(ROOM_SCENE.instantiate())
	add_child(_room)


func _guard(guard_name: String) -> Node3D:
	return _room.get_node("Guards/" + guard_name) as Node3D


func _behaviour(guard_name: String) -> AwarenessBehaviour:
	return _guard(guard_name).get_node("Behaviour") as AwarenessBehaviour


func _route_points(route_name: String) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for marker: Node3D in (_room.get_node("Routes/" + route_name) as PatrolRoute).points():
		points.append(marker.position)
	return points


func _crates() -> Array[Node3D]:
	var crates: Array[Node3D] = []
	for child: Node in _room.get_node("Cover").get_children():
		crates.append(child as Node3D)
	return crates


# Horizontal distance from `point` to the segment a..b.
static func _to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var closest := Geometry2D.get_closest_point_to_segment(flat, Vector2(a.x, a.z), Vector2(b.x, b.z))
	return flat.distance_to(closest)


# Half the horizontal diagonal of a crate's box collision shape.
static func _crate_reach(crate: Node3D) -> float:
	for child: Node in crate.get_children():
		var shape := child as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D:
			var size := (shape.shape as BoxShape3D).size
			return Vector2(size.x, size.z).length() * 0.5
	return 0.0


func test_shell_doorways_and_radio_room() -> void:
	var hall := _room.get_node("Shell/Hall") as Room
	var radio := _room.get_node("Shell/RadioRoom") as Room

	# Hall interior x -12 .. 6, z 0 .. 20 (its north wall overlaps the hub's south wall), 4 m high.
	assert_vector(hall.size).is_equal(Vector3(18, 4, 20))
	assert_vector(hall.position).is_equal(Vector3(-3, 0, 10))
	assert_float(hall.wall_thickness).is_equal(0.5)
	var from_hub := hall.openings[0]
	assert_int(from_hub.wall).is_equal(RoomOpening.Wall.NORTH)
	assert_float(hall.position.x + from_hub.offset).is_equal_approx(0.0, 0.0001)
	assert_vector(Vector2(from_hub.width, from_hub.height)).is_equal(Vector2(2, 3))
	# Radio room interior x -17.5 .. -12.5: it starts at the hall's west wall's outer face, so the
	# two walls overlap exactly (ADR 0043), with the same 1.6 x 2.4 m door at z 18.6 in both.
	assert_float(radio.wall_thickness).is_equal(0.5)
	assert_float(radio.position.x + radio.size.x * 0.5).is_equal_approx(
		hall.position.x - hall.size.x * 0.5 - hall.wall_thickness, 0.0001
	)
	var to_radio := hall.openings[1]
	var to_hall := radio.openings[0]
	assert_int(to_radio.wall).is_equal(RoomOpening.Wall.WEST)
	assert_int(to_hall.wall).is_equal(RoomOpening.Wall.EAST)
	assert_float(hall.position.z + to_radio.offset).is_equal_approx(18.6, 0.0001)
	assert_float(radio.position.z + to_hall.offset).is_equal_approx(18.6, 0.0001)
	for door: RoomOpening in [to_radio, to_hall]:
		assert_vector(Vector2(door.width, door.height)).is_equal(Vector2(1.6, 2.4))


func test_doorways_clear_for_the_player_capsule() -> void:
	await KitGeometry.settle(get_tree(), 5)
	# Rays through each doorway along a standing capsule's sides and centre, feet to head, find
	# nothing; the same rays through a solid stretch of wall hit it.
	assert_bool(_blocked(Vector3(0, 0, 0), Vector3.BACK)).override_failure_message("hub door").is_false()
	assert_bool(_blocked(Vector3(-12.25, 0, 18.6), Vector3.RIGHT)).override_failure_message("radio door").is_false()
	assert_bool(_blocked(Vector3(-12.25, 0, 14), Vector3.RIGHT)).override_failure_message("plain wall").is_true()


func test_lamps_light_the_room_and_stay_out_of_range_of_the_dark_corner() -> void:
	var lights: Array[OmniLight3D] = []
	for lamp: Node in _room.get_node("Lamps").get_children():
		assert_object(Powered.of(lamp)).override_failure_message(lamp.name).is_not_null()
		lights.append(lamp.get_node("Light") as OmniLight3D)
	assert_int(lights.size()).is_greater_equal(5)

	for light in lights:
		for spot in DARK_CORNER:
			for height in BODY_HEIGHTS:
				var distance := light.global_position.distance_to(spot + Vector3.UP * height)
				(
					assert_float(distance)
					. override_failure_message("%s to %s" % [light.get_parent().name, spot])
					. is_greater(light.omni_range + 0.5)
				)


func test_guards_are_named_by_loadout_with_routes_and_posts() -> void:
	for guard_name in GUARDS:
		assert_object(_guard(guard_name)).override_failure_message(guard_name).is_not_null()

	assert_object(_behaviour("GuardPistolA").route).is_same(_room.get_node("Routes/RouteA"))
	assert_object(_behaviour("GuardPistolB").route).is_same(_room.get_node("Routes/RouteB"))
	for post_guard: String in ["GuardBatonPost", "GuardBatonDowned", "GuardPistolRadio"]:
		assert_object(_behaviour(post_guard).route).override_failure_message(post_guard).is_null()
	assert_int(_route_points("RouteA").size()).is_equal(4)
	assert_int(_route_points("RouteB").size()).is_equal(2)
	# Posts face into the room (+Z): the radio post its room's door, the baton post towards the hall,
	# turned 30 degrees east so the downed guard stays out of its glances (next test).
	assert_vector(-_guard("GuardPistolRadio").global_basis.z).is_equal_approx(Vector3.BACK, Vector3.ONE * 0.0001)
	var baton_facing := Vector3(sin(deg_to_rad(30.0)), 0, cos(deg_to_rad(30.0)))
	assert_vector(-_guard("GuardBatonPost").global_basis.z).is_equal_approx(baton_facing, Vector3.ONE * 0.0001)


func test_baton_post_never_sees_the_downed_guard_while_glancing() -> void:
	# Patrol A finds the downed guard (the M7 opening). The baton post stands 4 m from the hub door: a
	# body shout from there sends the searchers to the doorway, in view of the hub's player spawn
	# (M8 playtest bug). Its glances (post yaw +- glance_angle) plus 10 degrees of margin keep the
	# body's centre (0.9 m along +Z from its feet) out of both view zones.
	var post := _guard("GuardBatonPost")
	var perception := PerceptionSensor.of(post).config
	var glance := (post.get_node("Awareness") as GradedAwareness).config.glance_angle
	var downed := _guard("GuardBatonDowned")
	var centre := downed.position + downed.global_basis.z * 0.9
	var distance := VisionRules.flat_distance(post.position, centre)
	# Sanity: it is within focus range, so only the angle keeps it unseen.
	assert_float(distance).is_less(perception.focus_range)
	var offset := -(glance + 10.0)
	while offset <= glance + 10.0:
		var yaw := post.global_rotation.y + deg_to_rad(offset)
		var facing := Vector3(-sin(yaw), 0, -cos(yaw))
		var angle := VisionRules.angle_off(facing, post.position, centre)
		var zone := VisionRules.zone_factor(angle, distance, perception)
		assert_float(zone).override_failure_message("glance %.0f deg: %.1f deg off" % [offset, angle]).is_zero()
		offset += 5.0


func test_downed_guard_lies_unconscious_beside_route_a_with_room_to_stand() -> void:
	var downed := _guard("GuardBatonDowned")
	var tags := Tags.of(downed)

	assert_bool(tags.has(ActorState.UNCONSCIOUS)).is_true()
	assert_bool(tags.has(&"actor.guard")).is_true()
	assert_bool(tags.has(&"equipment.radio")).is_true()
	# Beside the A3 -> A0 leg (x -6.5), 1.1 m off it: within 1.5 m, not on the walking line.
	var route := _route_points("RouteA")
	var distance := _to_segment(downed.position, route[3], route[0])
	assert_float(distance).is_between(0.6, 1.4)
	# It lies along +Z from its feet (DownedPose tips it onto its +Z): body centre 0.9 m further.
	var centre := downed.position + downed.global_basis.z * 0.9
	assert_float(_to_segment(centre, route[3], route[0])).is_between(0.6, 1.4)
	# No crate within 1.5 m (gap, surface to surface) of the lying body.
	for crate in _crates():
		var gap := _to_segment(crate.position, downed.position, downed.position + downed.global_basis.z * 1.8)
		gap -= _crate_reach(crate) + CAPSULE_RADIUS
		assert_float(gap).override_failure_message(crate.name).is_greater(1.5)


func test_routes_and_posts_keep_clear_of_the_crates() -> void:
	# Legs as consecutive pairs (start, end) of route points, each route looped.
	var legs := PackedVector3Array()
	for route_name: String in ["RouteA", "RouteB"]:
		var points := _route_points(route_name)
		for index in points.size():
			legs.append(points[index])
			legs.append(points[(index + 1) % points.size()])
	for crate in _crates():
		var reach := _crate_reach(crate) + CAPSULE_RADIUS
		for leg in range(0, legs.size(), 2):
			var gap := _to_segment(crate.position, legs[leg], legs[leg + 1]) - reach
			assert_float(gap).override_failure_message("%s to %s" % [crate.name, legs[leg]]).is_greater(1.0)
		for guard_name in GUARDS:
			var to_guard := Vector2(crate.position.x, crate.position.z).distance_to(
				Vector2(_guard(guard_name).position.x, _guard(guard_name).position.z)
			)
			assert_float(to_guard - reach).override_failure_message("%s to %s" % [crate.name, guard_name]).is_greater(
				1.0
			)


func test_alarm_devices_are_cabled_through_the_switch() -> void:
	# Two frames: on the first the downed guard drops its baton (ADR 0088), whose ImpactNoise adds
	# its audio player deferred; ending the test before that flushes reports it as an orphan.
	await KitGeometry.settle(get_tree(), 2)
	var controller := Device.of(_room.get_node("Alarm/Controller"))
	var switch_entity := _room.get_node("Alarm/Switch")
	for siren_name: String in ["SirenEast", "SirenWest"]:
		(
			assert_bool(controller.reaches(_room.get_node("Alarm/" + siren_name)))
			. override_failure_message(siren_name)
			. is_true()
		)
	assert_array(controller.reached(Siren.RING)).has_size(2)
	assert_array(controller.reached(RadioBaseStation.BROADCAST)).has_size(1)
	assert_array(Device.of(_room.get_node("Alarm/PanicButton")).reached(Device.INCIDENT)).contains_exactly([controller])
	# The switch carries the sirens: down, they are cut off; the panic button and base station are
	# cabled straight to the controller.
	Powered.of(switch_entity).on = false
	assert_array(controller.reached(Siren.RING)).is_empty()
	assert_array(controller.reached(RadioBaseStation.BROADCAST)).has_size(1)
	assert_str(String(Powered.of(switch_entity).circuit)).is_equal("ai_arena_network")


func test_signs() -> void:
	var texts := ""
	for sign: Node in _room.get_node("Labels").get_children():
		texts += String(sign.get("text")) + "\n"

	for phrase: String in [
		"6 AI arena", "behind", "dark corner", "wakes it", "E on the body", "Q drops", "17 m", "30 m", "alarm", "34 m"
	]:
		assert_str(texts.to_lower()).override_failure_message(phrase).contains(phrase.to_lower())


func test_no_coplanar_faces_with_different_materials() -> void:
	await KitGeometry.settle(get_tree())

	var overlaps := KitGeometry.coplanar_material_overlaps(_room)

	assert_array(Array(overlaps)).override_failure_message("\n".join(overlaps)).is_empty()


# True when any horizontal ray along `across` through room-local `feet` (1 m either side) hits world
# geometry: rays at the capsule's centre and sides (+-0.35 m), from 0.1 m to just above its 1.8 m.
func _blocked(feet: Vector3, across: Vector3) -> bool:
	var side := across.cross(Vector3.UP).normalized()
	for offset: float in [-CAPSULE_RADIUS, 0.0, CAPSULE_RADIUS]:
		for height: float in [0.1, CAPSULE_HEIGHT * 0.5, CAPSULE_HEIGHT + 0.05]:
			var point := feet + side * offset + Vector3.UP * height
			var hit := KitGeometry.ray(
				_room.get_world_3d(), _room.to_global(point - across), _room.to_global(point + across)
			)
			if not hit.is_empty():
				return true
	return false
