extends GdUnitTestSuite
## Inventory bay inside the hub (behind doorway "7 Inventory & Abilities" on the west wall): the room
## sits on the doorway, its hall stays clear of the other gallery rooms and of the mission doorway's
## half of the west side, the player walks in from the hub, and the navmesh reaches every station.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const HUB_SCENE: PackedScene = preload("res://levels/hub/hub.tscn")
const ROOMS: Array[String] = [
	"MovementCourse",
	"PerceptionLab",
	"PhysicsFireRoom",
	"ShootingRangeRoom",
	"AIArena",
	"InventoryBayRoom",
	"SecurityWing"
]
## Room-local points (origin on the hub wall's outer face, -Z away from the hub).
const NAV_POINTS: Array[Vector3] = [
	Vector3(0, 0, -2),
	Vector3(0, 0, -6),
	Vector3(-4.4, 0, -10),
	Vector3(4.3, 0, -6.6),
	Vector3(4.2, 0, -12),
	Vector3(0, 0.02, -12),
	Vector3(3.5, 0, -17.6),
]

var _driver: PlayerDriver
var _room: Node3D
var _nav: LevelNavigation


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_hall_footprints_do_not_overlap_and_room_7_keeps_off_the_mission_half() -> void:
	var hub: Node3D = auto_free(HUB_SCENE.instantiate())
	var halls: Dictionary[String, Rect2] = {}
	for name: String in ROOMS:
		halls[name] = _hall_rect(hub, name)

	for a: String in ROOMS:
		for b: String in ROOMS:
			if a < b:
				assert_bool(halls[a].intersects(halls[b])).override_failure_message("%s / %s" % [a, b]).is_false()
	# Hub x, z: west of the hub's west wall, south of hub z 0.5 (the mission doorway at z -7.5 keeps
	# the northern half) and north of the hub's south wall line (z 15.5, room 6 beyond).
	var bay := halls["InventoryBayRoom"]
	assert_float(bay.end.x).is_less_equal(-15.5)
	assert_float(bay.position.y).is_greater_equal(0.5)
	assert_float(bay.end.y).is_less_equal(15.5)


func test_room_sits_behind_doorway_seven_and_player_walks_in() -> void:
	await _load_hub()
	var doorway := _driver.runner.scene().get_node("Room/DoorwayInventoryAbilities") as Node3D
	var hub_room := _driver.runner.scene().get_node("Room") as Room

	# Origin on the outer face of the hub's west wall, centred on the doorway; -Z points west.
	assert_float(_room.global_position.x).is_equal_approx(-(hub_room.size.x * 0.5 + hub_room.wall_thickness), 0.0001)
	assert_float(_room.global_position.z).is_equal_approx(doorway.global_position.z, 0.0001)
	assert_vector(-_room.global_basis.z).is_equal_approx(Vector3.LEFT, Vector3.ONE * 0.0001)
	await _driver.place(Vector3(-12, 0, 7.5), PI / 2.0)

	await _driver.hold(&"move_forward", 180)

	# Through the corridor into the hall (interior from local z -4).
	var feet := _room.to_local(_driver.player.global_position)
	assert_float(feet.z).is_less(-5.0)
	assert_float(absf(feet.x)).is_less(1.0)


func test_navmesh_reaches_every_station() -> void:
	await _load_hub()
	var map := _nav.get_navigation_map()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position

	for local: Vector3 in NAV_POINTS:
		var target := _room.to_global(local)
		var path := NavigationServer3D.map_get_path(map, spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)


## The hall interior of gallery room `name` in hub x / z (Rect2 position x = hub x, y = hub z),
## grown by its wall thickness.
func _hall_rect(hub: Node3D, name: String) -> Rect2:
	var room := hub.get_node(name) as Node3D
	var hall := room.get_node("Shell/Hall") as Room
	var half := Vector3(hall.size.x * 0.5 + hall.wall_thickness, 0, hall.size.z * 0.5 + hall.wall_thickness)
	var to_hub := room.transform * hall.transform
	var low := to_hub * -half
	var high := to_hub * half
	var rect := Rect2(Vector2(low.x, low.z), Vector2.ZERO).expand(Vector2(high.x, high.z))
	# Shared outer faces touch but must not overlap: shrink by a millimetre.
	return rect.grow(-0.001)


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_room = _driver.runner.find_child("InventoryBayRoom") as Node3D
	_nav = _driver.runner.find_child("Navigation") as LevelNavigation
	await _driver.settle()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _nav.get_navigation_map(), spawn)).is_true()
