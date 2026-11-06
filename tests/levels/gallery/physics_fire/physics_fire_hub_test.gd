extends GdUnitTestSuite
## Physics and fire room inside the hub (behind doorway "3 Physics & Fire"): the player walks in
## from the hub, the navmesh covers the corridor and hall, and the barricaded side room is reached
## only once the barricade has burnt away (station D).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const HUB := "res://levels/hub/hub.tscn"
const CONFIG: PlayerConfig = preload("res://actors/player/player_config.tres")
## Room-local points (origin on the hub wall's outer face, -Z away from the hub).
const HALL_CENTRE := Vector3(0, 0, -12)
const SIDE_ROOM_CENTRE := Vector3(-12, 0, -17)
const BEFORE_BARRICADE := Vector3(-8.5, 0, -17)
const AWAY_FROM_FIRE := Vector3(-5, 0, -10)

var _driver: PlayerDriver
var _room: Node3D
var _nav: LevelNavigation


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_room_sits_behind_doorway_three_and_player_walks_in() -> void:
	await _load_hub()
	var doorway := _driver.runner.scene().get_node("Room/DoorwayPhysicsFire") as Node3D
	var hub_room := _driver.runner.scene().get_node("Room") as Room

	# Origin on the outer face of the hub's east wall, centred on the doorway; -Z points east.
	assert_float(_room.global_position.x).is_equal_approx(hub_room.size.x * 0.5 + hub_room.wall_thickness, 0.0001)
	assert_float(_room.global_position.z).is_equal_approx(doorway.global_position.z, 0.0001)
	assert_vector(-_room.global_basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.0001)
	await _driver.place(Vector3(12, 0, -7.5), -PI / 2.0)

	await _driver.hold(&"move_forward", 150)

	assert_float(_room.to_local(_driver.player.global_position).z).is_less(-5.0)


func test_navmesh_covers_corridor_and_hall_but_not_the_barricaded_room() -> void:
	await _load_hub()
	var map := _nav.get_navigation_map()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position

	for local: Vector3 in [Vector3(0, 0, -2), HALL_CENTRE, Vector3(8, 0, -18)]:
		var target := _room.to_global(local)
		var path := NavigationServer3D.map_get_path(map, spawn, target, true)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)
	var side := _room.to_global(SIDE_ROOM_CENTRE)
	var blocked := NavigationServer3D.map_get_path(map, spawn, side, true)
	assert_float(blocked[-1].distance_to(side)).override_failure_message(str(blocked)).is_greater(1.5)


func test_burnt_barricade_opens_the_side_room() -> void:
	await _load_hub()
	var barricade := _room.get_node("BarricadeRoom/Barricade") as Node3D
	var probe := PlayerProbe.new(_driver.player, CONFIG)
	var before := _room.to_global(BEFORE_BARRICADE)
	var inside := _room.to_global(SIDE_ROOM_CENTRE)
	assert_bool(probe.sweep_clear(before, inside, CONFIG.standing_height)).is_false()
	await _driver.place(before, _yaw_towards(BEFORE_BARRICADE, SIDE_ROOM_CENTRE))
	await _driver.hold(&"move_forward", 60)
	assert_float(_room.to_local(_driver.player.global_position).x).is_greater(-10.0)

	await _driver.place(_room.to_global(AWAY_FROM_FIRE))
	StimulusSystem.emit(Stimulus.make_contact(&"fire", 100.0, barricade))
	# 30 s of fuel, then it breaks.
	await _driver.frames(31 * 60)

	assert_array(Objects.logged(&"object.burnt_out", "object", "Barricade")).has_size(1)
	assert_array(Objects.logged(&"object.broken", "object", "Barricade")).has_size(1)
	assert_bool(is_instance_valid(barricade)).is_false()
	# The crate inside stays out of the barricade's 1.8 m fire.
	assert_array(Objects.logged(&"object.ignited", "object", "SideRoomCrate")).is_empty()
	assert_bool(probe.sweep_clear(before, inside, CONFIG.standing_height)).is_true()
	await _driver.place(before, _yaw_towards(BEFORE_BARRICADE, SIDE_ROOM_CENTRE))
	await _driver.hold(&"move_forward", 60)
	assert_float(_room.to_local(_driver.player.global_position).x).is_less(-11.0)

	# A re-bake (M7 decides when guards need one) connects the side room.
	var map := _nav.get_navigation_map()
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	_nav.bake()
	for i in 120:
		if NavigationServer3D.map_get_iteration_id(map) > iteration:
			break
		await get_tree().physics_frame
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	var path := NavigationServer3D.map_get_path(map, spawn, inside, true)
	assert_float(path[-1].distance_to(inside)).override_failure_message(str(path)).is_less(0.3)


func _load_hub() -> void:
	_driver = PlayerDriver.new(scene_runner(HUB))
	_room = _driver.runner.find_child("PhysicsFireRoom") as Node3D
	_nav = _driver.runner.find_child("Navigation") as LevelNavigation
	await _driver.settle()
	var spawn := (_driver.runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _nav.get_navigation_map(), spawn)).is_true()


## Player yaw (0 = facing -Z) that looks from room-local `from` towards room-local `to`.
func _yaw_towards(from: Vector3, to: Vector3) -> float:
	var direction := _room.global_basis * (to - from)
	return atan2(-direction.x, -direction.z)
