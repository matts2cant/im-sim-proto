extends GdUnitTestSuite
## Shooting range inside the hub (behind doorway "4 Shooting Range"): the room sits on the doorway,
## the player walks in from the hub to the counter, and the navmesh covers the range floor (the
## booth, the blast lane through the counter gap, the lanes and the far wall).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
## Room-local points (origin on the hub wall's outer face, -Z away from the hub).
const NAV_POINTS: Array[Vector3] = [
	Vector3(0, 0, -2),
	Vector3(5, 0, -6.5),
	Vector3(-1.5, 0, -16),
	Vector3(4.25, 0, -30),
	Vector3(3.5, 0, -50),
	Vector3(10, 0, -45),
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


func test_room_sits_behind_doorway_four_and_player_walks_to_the_counter() -> void:
	await _load_hub()
	var doorway := _driver.runner.scene().get_node("Room/DoorwayShootingRange") as Node3D
	var hub_room := _driver.runner.scene().get_node("Room") as Room

	# Origin on the outer face of the hub's east wall, centred on the doorway; -Z points east.
	assert_float(_room.global_position.x).is_equal_approx(hub_room.size.x * 0.5 + hub_room.wall_thickness, 0.0001)
	assert_float(_room.global_position.z).is_equal_approx(doorway.global_position.z, 0.0001)
	assert_vector(-_room.global_basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	await _driver.place(Vector3(12, 0, 7.5), -PI / 2.0)

	await _driver.hold(&"move_forward", 150)

	# Through the corridor into the booth, stopped by the counter (lip at local z -8).
	var feet := _room.to_local(_driver.player.global_position)
	assert_float(feet.z).is_less(-5.0)
	assert_float(feet.z).is_greater(-8.0)


func test_navmesh_covers_the_range_floor() -> void:
	await _load_hub()
	var map := _nav.get_navigation_map()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position

	for local: Vector3 in NAV_POINTS:
		var target := _room.to_global(local)
		var path := NavigationServer3D.map_get_path(map, spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_room = _driver.runner.find_child("ShootingRangeRoom") as Node3D
	_nav = _driver.runner.find_child("Navigation") as LevelNavigation
	await _driver.settle()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _nav.get_navigation_map(), spawn)).is_true()
