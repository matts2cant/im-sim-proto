extends GdUnitTestSuite
## Perception lab inside the hub (behind doorway "2 Perception Lab" on the north wall): the room
## sits on the doorway with its hall between the movement course (west) and the physics and fire
## room (east), the player walks in from the hub, and the hub's navmesh covers the lanes, the
## breaker and the guard post.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
## Room-local points (origin on the hub wall's outer face, -Z away from the hub).
const NAV_POINTS: Array[Vector3] = [
	Vector3(0, 0, -2),
	Vector3(-4.3, 0, -2),
	Vector3(-2.5, 0.02, -8),
	Vector3(2.5, 0.02, -8),
	Vector3(7.5, 0.02, -8),
	Vector3(2.5, 0, -16),
]

var _driver: PlayerDriver
var _room: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_hall_fits_between_its_neighbours() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())
	var lab := _hall_rect(hub, "PerceptionLab")

	for other: String in ["MovementCourse", "PhysicsFireRoom", "ShootingRangeRoom", "InventoryBayRoom"]:
		assert_bool(lab.intersects(_hall_rect(hub, other))).override_failure_message(other).is_false()
	# Its south wall is the hub's north wall (hub z -15.5 .. -15); outer walls in hub x 1.5 .. 18.5.
	assert_float(lab.end.y).is_equal_approx(-15.0, 0.01)
	assert_float(lab.position.x).is_equal_approx(1.5, 0.01)
	assert_float(lab.end.x).is_equal_approx(18.5, 0.01)


func test_room_sits_behind_doorway_two_and_player_walks_in() -> void:
	await _load_hub()
	var doorway := _driver.runner.scene().get_node("Room/DoorwayPerception") as Node3D
	var hub_room := _driver.runner.scene().get_node("Room") as Room

	# Origin on the outer face of the hub's north wall, centred on the doorway; -Z points north.
	assert_float(_room.global_position.z).is_equal_approx(-(hub_room.size.z * 0.5 + hub_room.wall_thickness), 0.0001)
	assert_float(_room.global_position.x).is_equal_approx(doorway.global_position.x, 0.0001)
	assert_vector(-_room.global_basis.z).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.0001)
	await _driver.place(Vector3(7.5, 0, -11))

	await _driver.hold(&"move_forward", 180)

	var feet := _room.to_local(_driver.player.global_position)
	assert_float(feet.z).is_less(-6.0)
	assert_float(absf(feet.x)).is_less(1.0)


func test_navmesh_reaches_lanes_breaker_and_guard_post() -> void:
	await _load_hub()
	var nav := _driver.runner.find_child("Navigation") as LevelNavigation
	var map := nav.get_navigation_map()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, spawn)).is_true()

	for local: Vector3 in NAV_POINTS:
		var target := _room.to_global(local)
		var path := NavigationServer3D.map_get_path(map, spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)


## The hall of gallery room `name` in hub x / z (Rect2 position x = hub x, y = hub z), outer faces.
func _hall_rect(hub: Node3D, name: String) -> Rect2:
	var room := hub.get_node(name) as Node3D
	var hall := room.get_node("Shell/Hall") as Room
	var half := Vector3(hall.size.x * 0.5 + hall.wall_thickness, 0, hall.size.z * 0.5 + hall.wall_thickness)
	var to_hub := room.transform * hall.transform
	var low := to_hub * -half
	var high := to_hub * half
	var rect := Rect2(Vector2(low.x, low.z), Vector2.ZERO).expand(Vector2(high.x, high.z))
	return rect.grow(-0.001)


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_driver.player.reload_on_reset = false
	_room = _driver.runner.find_child("PerceptionLab") as Node3D
	await _driver.settle()
