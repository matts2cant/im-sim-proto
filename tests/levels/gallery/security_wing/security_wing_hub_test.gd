extends GdUnitTestSuite
## Security wing inside the hub (behind doorway "5 Security" on the south wall): the room sits on the
## doorway, not turned, and every one of its kit rooms stays clear of the other gallery rooms (room 6
## to the west, the shooting range to the east) inside hub x -0.5 .. 18.5, z 15 .. 38; the player
## walks in from the hub; the hub's navmesh covers the wing (hall, closets, corridor, alcoves, vault,
## laser hall) and holds the guard and its post; the guard is within 30 m of navmesh path of a siren
## (sirens carry 34 m).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const SIREN_REACH := 30.0
## Room-local floor points the navmesh must cover: hall, each closet, corridor, both alcoves, vault,
## laser hall.
const NAV_POINTS: Array[Vector3] = [
	Vector3(0, 0, 3),
	Vector3(-6.25, 0, 7.4),
	Vector3(-3.25, 0, 7.4),
	Vector3(-0.25, 0, 7.4),
	Vector3(2.75, 0, 7.4),
	Vector3(5.75, 0, 7.4),
	Vector3(9, 0, 12.6),
	Vector3(6.4, 0, 10.3),
	Vector3(6.4, 0, 14.9),
	Vector3(8, 0, 20),
	Vector3(-6, 0, 13),
]

var _hub: Node3D
var _wing: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StimulusSystem.clear()


func test_room_sits_behind_doorway_five_and_keeps_clear_of_its_neighbours() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())
	var wing := hub.get_node("SecurityWing") as Node3D
	var doorway := hub.get_node("Room/DoorwaySecurity") as Node3D

	# Origin on the outer face of the hub's south wall (z 15.5), centred on the doorway, not turned.
	assert_float(wing.position.x).is_equal_approx(doorway.position.x, 0.0001)
	assert_vector(wing.position).is_equal(Vector3(7.5, 0, 15.5))
	assert_bool(wing.basis.is_equal_approx(Basis.IDENTITY)).is_true()
	var mine: Array[Room] = []
	var others: Array[Room] = []
	for node: Node in hub.find_children("*", "Room", true, false):
		if node.get_parent() == hub:
			continue
		if wing.is_ancestor_of(node):
			mine.append(node as Room)
		else:
			others.append(node as Room)
	assert_int(mine.size()).is_equal(11)
	for room in mine:
		var rect := _rect(hub, room)
		for other in others:
			var where := "%s / %s" % [room.name, hub.get_path_to(other)]
			assert_bool(rect.intersects(_rect(hub, other))).override_failure_message(where).is_false()
		# Hub x -0.5 .. 18.5 (0.5 m of void to room 6 at x -1 and the range at x 19), z 15 .. 38.
		assert_float(rect.position.x).override_failure_message(room.name).is_greater_equal(-0.5 - 0.01)
		assert_float(rect.end.x).override_failure_message(room.name).is_less_equal(18.5 + 0.01)
		assert_float(rect.position.y).override_failure_message(room.name).is_greater_equal(15.0 - 0.01)
		assert_float(rect.end.y).override_failure_message(room.name).is_less_equal(38.0 + 0.01)


func test_player_walks_in_from_the_hub() -> void:
	var driver := PlayerDriver.new(scene_runner(HUB))
	driver.player.reload_on_reset = false
	var wing := driver.runner.find_child("SecurityWing") as Node3D
	await driver.settle()
	ActorState.set_tag(driver.player, ActorState.CLOAKED, true)
	await driver.place(Vector3(7.5, 0, 12), PI)

	await driver.hold(&"move_forward", 120)

	var feet := wing.to_local(driver.player.global_position)
	assert_float(feet.z).is_greater(3.0)
	assert_float(absf(feet.x)).is_less(1.0)


func test_navmesh_covers_the_wing_and_holds_the_guard() -> void:
	var map := await _load_hub()
	for local in NAV_POINTS:
		var point := _wing.to_global(local)
		var gap := NavigationServer3D.map_get_closest_point(map, point).distance_to(point)
		assert_float(gap).override_failure_message(str(local)).is_less(0.3)
	var guard := _wing.get_node("Guards/GuardBatonVault") as Node3D
	var feet := guard.global_position
	assert_float(NavigationServer3D.map_get_closest_point(map, feet).distance_to(feet)).is_less(0.3)
	# Reachable on foot from the hub spawn (through the hall and the open corridor mouth).
	var spawn := (_hub.get_node("PlayerSpawn") as Node3D).global_position
	var path := NavigationServer3D.map_get_path(map, spawn, feet, true)
	assert_float(path[-1].distance_to(feet)).is_less(0.3)


func test_guard_hears_a_siren() -> void:
	var map := await _load_hub()
	var guard := (_wing.get_node("Guards/GuardBatonVault") as Node3D).global_position
	var nearest := INF
	for siren_name: String in ["SirenHall", "SirenCorridor"]:
		var siren := (_wing.get_node("Devices/" + siren_name) as Node3D).global_position
		var points := PackedVector3Array([siren])
		points.append_array(NavigationServer3D.map_get_path(map, siren, guard, true))
		points.append(guard)
		var walked := StimulusPropagation.polyline_length(points)
		assert_float(walked).override_failure_message(siren_name).is_less(SIREN_REACH)
		nearest = minf(nearest, walked)
	assert_float(nearest).is_less(10.0)


func _load_hub() -> RID:
	_hub = auto_free(HUB_SCENE.instantiate())
	_hub.get_node("Player").free()
	add_child(_hub)
	_wing = _hub.get_node("SecurityWing") as Node3D
	await KitGeometry.settle(get_tree(), 5)
	var map := (_hub.get_node("Navigation") as LevelNavigation).get_navigation_map()
	var probe := _wing.to_global(Vector3(0, 0, 3))
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, probe)).is_true()
	return map


## `room` in hub x / z (Rect2 position x = hub x, y = hub z), outer faces, shrunk by a millimetre so
## rooms sharing a wall face do not count as overlapping.
static func _rect(hub: Node3D, room: Room) -> Rect2:
	var half := Vector3(room.size.x * 0.5 + room.wall_thickness, 0, room.size.z * 0.5 + room.wall_thickness)
	var to_hub := Transform3D.IDENTITY
	var node: Node = room
	while node != hub:
		to_hub = (node as Node3D).transform * to_hub
		node = node.get_parent()
	var low := to_hub * -half
	var high := to_hub * half
	return Rect2(Vector2(low.x, low.z), Vector2.ZERO).expand(Vector2(high.x, high.z)).grow(-0.001)
