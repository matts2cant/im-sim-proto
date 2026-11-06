extends GdUnitTestSuite
## LevelNavigation: runtime navmesh bake in the hub (covering the movement course) and on
## a small kit scene; low spaces (vents, crawl spaces) stay off the navmesh.

const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const HUB := "res://levels/hub/hub.tscn"
const FLOOR_SCENE: PackedScene = preload("res://levels/kit/surface_floor.tscn")
const VENT_SCENE: PackedScene = preload("res://levels/kit/vent_segment.tscn")

var _runner: GdUnitSceneRunner
var _nav: LevelNavigation
var _course: Node3D


func before_test() -> void:
	DebugPanel.set_open(false)


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_hub_bakes_a_navmesh_when_it_loads() -> void:
	await _load_hub()

	assert_object(_nav.navigation_mesh).is_not_null()
	assert_int(_nav.navigation_mesh.get_polygon_count()).is_greater(10)
	assert_float(_nav.navigation_mesh.agent_radius).is_equal_approx(0.35, 0.0001)
	assert_float(_nav.navigation_mesh.agent_height).is_equal_approx(1.8, 0.0001)
	# Walk-up steps of up to 0.3 m are on the navmesh (ADR 0058).
	assert_float(_nav.navigation_mesh.agent_max_climb).is_equal_approx(0.3, 0.0001)
	assert_float(_nav.navigation_mesh.agent_max_slope).is_equal_approx(45.0, 0.0001)


func test_path_from_player_spawn_to_movement_course_floor() -> void:
	await _load_hub()
	var spawn := (_runner.find_child("PlayerSpawn") as Node3D).global_position
	var target := _course.to_global(Vector3(-12, 0, -40))

	var path := NavigationServer3D.map_get_path(_nav.get_navigation_map(), spawn, target, true)

	assert_int(path.size()).is_greater(1)
	assert_float(path[0].distance_to(spawn)).is_less(0.3)
	assert_float(path[-1].distance_to(target)).is_less(0.3)
	# It leaves the hub through the movement doorway (wall centre z = -15.25, x -8.5 to -6.5).
	assert_bool(_crosses_doorway(path)).override_failure_message(str(path)).is_true()


func test_ramps_and_floor_overlays_are_connected() -> void:
	await _load_hub()
	var spawn := (_runner.find_child("PlayerSpawn") as Node3D).global_position
	var targets: Array[Vector3] = [
		Vector3(-6, 0.02, -12),  # Concrete strip (raised 2 cm).
		Vector3(-15, 2, -36),  # Gap runway, up the 30 degree ramp.
		Vector3(5.75, 5, -42),  # Drop tower top, up the long ramp.
	]
	for local: Vector3 in targets:
		var target := _course.to_global(local)

		var path := NavigationServer3D.map_get_path(_nav.get_navigation_map(), spawn, target, true)

		assert_int(path.size()).override_failure_message(str(local)).is_greater(1)
		assert_float(path[-1].distance_to(target)).override_failure_message(str(local)).is_less(0.3)


func test_vent_and_crawl_space_interiors_are_not_on_the_navmesh() -> void:
	await _load_hub()
	var map := _nav.get_navigation_map()
	var low_spaces: Array[Vector3] = [
		Vector3(-4, 1.5, -26.5),  # Vent mouth duct.
		Vector3(-4, 1.5, -29),  # Vent corner.
		Vector3(-10, 0.05, -29),  # Vent exit duct (floor level).
		Vector3(5.75, 0, -27),  # 1.2 m crawl space.
	]
	for local: Vector3 in low_spaces:
		var point := _course.to_global(local)

		var closest := NavigationServer3D.map_get_closest_point(map, point)

		assert_float(closest.distance_to(point)).override_failure_message("%s -> %s" % [local, closest]).is_greater(0.5)


func test_bake_matches_the_geometry_it_is_given() -> void:
	var level := auto_free(Node3D.new()) as Node3D
	var ground := FLOOR_SCENE.instantiate() as SurfaceFloor
	ground.size = Vector2(10, 10)
	level.add_child(ground)
	var vent := VENT_SCENE.instantiate() as VentSegment
	vent.length = 4.0
	vent.position = Vector3(0, 0, 2)
	level.add_child(vent)
	var nav := LevelNavigation.new()
	level.add_child(nav)
	add_child(level)  # Bakes in _ready.
	await KitGeometry.settle(get_tree())
	var map := nav.get_navigation_map()
	var before := _area(nav.navigation_mesh)

	assert_float(before).is_greater(50.0)
	var in_vent := Vector3(0.1, 0, 0.5)
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), map, Vector3(3, 0, 0.5))).is_true()
	var closest := NavigationServer3D.map_get_closest_point(map, in_vent)
	assert_float(closest.distance_to(in_vent)).override_failure_message(str(closest)).is_greater(0.5)

	ground.size = Vector2(20, 20)
	var start := Time.get_ticks_msec()
	nav.bake()
	var elapsed := Time.get_ticks_msec() - start

	assert_float(_area(nav.navigation_mesh)).is_greater(before * 3.0)
	assert_int(elapsed).is_less(2000)


func _load_hub() -> void:
	_runner = scene_runner(HUB)
	_nav = _runner.find_child("Navigation") as LevelNavigation
	_course = _runner.find_child("MovementCourse") as Node3D
	var spawn := (_runner.find_child("PlayerSpawn") as Node3D).global_position
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _nav.get_navigation_map(), spawn)).is_true()


func _crosses_doorway(path: PackedVector3Array) -> bool:
	for i in range(1, path.size()):
		if path[i - 1].z > -15.25 and path[i].z <= -15.25:
			var t := (-15.25 - path[i - 1].z) / (path[i].z - path[i - 1].z)
			var x := lerpf(path[i - 1].x, path[i].x, t)
			if x > -8.5 and x < -6.5:
				return true
	return false


# Top-down area of a navigation mesh's polygons.
static func _area(mesh: NavigationMesh) -> float:
	var vertices := mesh.get_vertices()
	var total := 0.0
	for i in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(i)
		for j in range(1, polygon.size() - 1):
			var a := vertices[polygon[0]]
			var b := vertices[polygon[j]]
			var c := vertices[polygon[j + 1]]
			total += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
	return total
