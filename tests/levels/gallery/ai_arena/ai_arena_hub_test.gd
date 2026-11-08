extends GdUnitTestSuite
## AI arena inside the hub (behind doorway "6 AI Arena" on the south wall): the room sits on the
## doorway, not turned, its hall and radio room stay clear of the other gallery rooms and leave the
## south wall east of hub x -1 to room 5; the player walks in from the hub; the hub's navmesh holds
## every guard and patrol point; the radio guard is beyond shout range of the others (navmesh path
## > 20 m: shouts carry 17 m) but within radio range (straight line <= 27 m: radios reach 30 m);
## every standing guard hears a siren (navmesh path < 30 m: sirens carry 34 m) and is within the
## radio base station's 40 m; the dark corner reads dark and the downed guard lies in the light.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const OTHER_ROOMS: Array[String] = [
	"MovementCourse", "PerceptionLab", "PhysicsFireRoom", "ShootingRangeRoom", "InventoryBayRoom"
]
const SHOUT_CLEARANCE := 20.0
const RADIO_REACH := 27.0
## Sirens are heeded up to 34 m of path (loudness 35, margin 1); posts and patrol points stay
## well inside.
const SIREN_REACH := 30.0
## The radio base station dispatches 40 m straight.
const DISPATCH_REACH := 36.0
const DARK_CORNER := Vector3(4.5, 0, 18.5)

var _hub: Node3D
var _arena: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_room_sits_behind_doorway_six_and_keeps_clear_of_its_neighbours() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())
	var arena := hub.get_node("AIArena") as Node3D
	var doorway_x := -7.5

	# Origin on the outer face of the hub's south wall (z 15.5), centred on the doorway, not turned.
	assert_vector(arena.position).is_equal(Vector3(doorway_x, 0, 15.5))
	assert_bool(arena.basis.is_equal_approx(Basis.IDENTITY)).is_true()
	var hall := _rect(hub, "AIArena/Shell/Hall")
	var radio := _rect(hub, "AIArena/Shell/RadioRoom")
	for other: String in OTHER_ROOMS:
		var other_hall := _rect(hub, other + "/Shell/Hall")
		assert_bool(hall.intersects(other_hall)).override_failure_message(other).is_false()
		assert_bool(radio.intersects(other_hall)).override_failure_message(other).is_false()
	# Hall outer faces hub x -20 .. -1, z 15 .. 36; radio room x -25.5 .. -19.5. South of the hub.
	assert_float(hall.position.y).is_equal_approx(15.0, 0.01)
	assert_float(hall.end.x).is_less_equal(-1.0)
	assert_float(radio.position.y).is_greater_equal(15.0 - 0.01)


func test_player_walks_in_from_the_hub() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	driver.player.reload_on_reset = false
	var arena := driver.runner.find_child("AIArena") as Node3D
	await driver.settle()
	# Hidden from the guards (Cloak's tag) so none of them steps into the walk.
	ActorState.set_tag(driver.player, ActorState.CLOAKED, true)
	await driver.place(Vector3(-7.5, 0, 12), PI)

	await driver.hold(&"move_forward", 120)

	var feet := arena.to_local(driver.player.global_position)
	assert_float(feet.z).is_greater(3.0)
	assert_float(absf(feet.x)).is_less(1.0)


func test_guards_and_patrol_points_are_on_the_navmesh() -> void:
	var map := await _load_hub()
	var spawn := (_hub.get_node("PlayerSpawn") as Node3D).global_position

	for guard: Node in _arena.get_node("Guards").get_children():
		var feet := (guard as Node3D).global_position
		var gap := NavigationServer3D.map_get_closest_point(map, feet).distance_to(feet)
		assert_float(gap).override_failure_message(guard.name).is_less(0.3)
	for route: Node in _arena.get_node("Routes").get_children():
		for marker: Node3D in (route as PatrolRoute).points():
			var path := NavigationServer3D.map_get_path(map, spawn, marker.global_position, true)
			assert_float(path[-1].distance_to(marker.global_position)).override_failure_message(marker.name).is_less(
				0.3
			)


func test_radio_guard_is_out_of_shout_range_but_in_radio_range() -> void:
	var map := await _load_hub()
	var radio := (_arena.get_node("Guards/GuardPistolRadio") as Node3D).global_position

	var spots := _alert_spots()
	assert_int(spots.size()).is_greater(10)
	for spot in spots:
		var path := NavigationServer3D.map_get_path(map, radio, spot, true)
		assert_float(path[-1].distance_to(spot)).override_failure_message(str(spot)).is_less(0.3)
		var walked := 0.0
		for index in range(1, path.size()):
			walked += path[index].distance_to(path[index - 1])
		var straight := Vector2(radio.x, radio.z).distance_to(Vector2(spot.x, spot.z))
		var where := str(_arena.to_local(spot))
		assert_float(walked).override_failure_message("path to " + where).is_greater(SHOUT_CLEARANCE)
		assert_float(straight).override_failure_message("straight to " + where).is_less_equal(RADIO_REACH)


func test_every_standing_guard_hears_a_siren_and_the_base_station() -> void:
	var map := await _load_hub()
	var sirens: Array[Vector3] = []
	for siren_name: String in ["SirenEast", "SirenWest"]:
		sirens.append((_arena.get_node("Alarm/" + siren_name) as Node3D).global_position)
	var station := (_arena.get_node("Alarm/BaseStation") as Node3D).global_position
	# Where the standing guards are: posts, patrol points and leg middles (the downed one is out).
	var spots := _alert_spots()
	spots.append((_arena.get_node("Guards/GuardPistolRadio") as Node3D).global_position)
	for spot in spots:
		var nearest := INF
		for siren in sirens:
			var points := PackedVector3Array([siren])
			points.append_array(NavigationServer3D.map_get_path(map, siren, spot, true))
			points.append(spot)
			nearest = minf(nearest, StimulusPropagation.polyline_length(points))
		var where := str(_arena.to_local(spot))
		assert_float(nearest).override_failure_message("siren path to " + where).is_less(SIREN_REACH)
		assert_float(station.distance_to(spot)).override_failure_message("station to " + where).is_less(DISPATCH_REACH)


func test_dark_corner_is_dark_and_the_downed_guard_lies_in_the_light() -> void:
	await _load_hub()
	var downed := _arena.get_node("Guards/GuardBatonDowned") as Node3D
	var target := _stand_in(_arena.to_global(DARK_CORNER))

	assert_float(LightExposure.of(target).update_now()).is_less(0.1)
	assert_float(LightExposure.of(downed).update_now()).is_greater(0.5)
	# The posts and the radio guard stand in the light too, so the player can watch them.
	for guard_name: String in ["GuardBatonPost", "GuardPistolRadio"]:
		var guard := _arena.get_node("Guards/" + guard_name)
		assert_float(LightExposure.of(guard).update_now()).override_failure_message(guard_name).is_greater(0.5)


# Where the other guards are likely to be when they shout: patrol points and the middle of every
# leg, the posts (the downed guard's included) and the hall centre. Global positions.
func _alert_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = [_arena.to_global(Vector3(-3, 0, 10))]
	for route: Node in _arena.get_node("Routes").get_children():
		var points := (route as PatrolRoute).points()
		for index in points.size():
			var here := points[index].global_position
			spots.append(here)
			spots.append(here.lerp(points[(index + 1) % points.size()].global_position, 0.5))
	for guard_name: String in ["GuardBatonPost", "GuardBatonDowned"]:
		spots.append((_arena.get_node("Guards/" + guard_name) as Node3D).global_position)
	return spots


func _load_hub() -> RID:
	_hub = auto_free(HUB_SCENE.instantiate())
	_hub.get_node("Player").free()
	add_child(_hub)
	_arena = _hub.get_node("AIArena") as Node3D
	await KitGeometry.settle(get_tree(), 5)
	var map := (_hub.get_node("Navigation") as LevelNavigation).get_navigation_map()
	var probe := _arena.to_global(Vector3(0, 0, 3))
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, probe)).is_true()
	return map


# A static 1.8 m capsule with a real LightExposure (no tags: nobody looks at it).
func _stand_in(feet: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.add_child(LightExposure.new())
	_hub.add_child(body)
	body.global_position = feet
	return body


## Room `path` (a kit Room under the hub) in hub x / z (Rect2 position x = hub x, y = hub z), outer
## faces, shrunk by a millimetre so rooms sharing a wall face do not count as overlapping.
static func _rect(hub: Node3D, path: String) -> Rect2:
	var room := hub.get_node(path) as Room
	var half := Vector3(room.size.x * 0.5 + room.wall_thickness, 0, room.size.z * 0.5 + room.wall_thickness)
	var to_hub := Transform3D.IDENTITY
	var node: Node = room
	while node != hub:
		to_hub = (node as Node3D).transform * to_hub
		node = node.get_parent()
	var low := to_hub * -half
	var high := to_hub * half
	return Rect2(Vector2(low.x, low.z), Vector2.ZERO).expand(Vector2(high.x, high.z)).grow(-0.001)
