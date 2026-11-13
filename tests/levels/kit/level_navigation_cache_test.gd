extends GdUnitTestSuite
## LevelNavigation keeps its bakes per source geometry: a level baked again with exactly the same
## geometry gets an equal navmesh (a new resource) without baking; other geometry bakes anew; only
## the last CACHE_SIZE bakes are kept. The regions are disabled: they never answer other suites'
## path queries.

const FLOOR_SCENE: PackedScene = preload("res://levels/kit/surface_floor.tscn")
## Far from the origin and from other suites' navigation fixtures.
const SPOT := Vector3(-260, 0, -660)


func before_test() -> void:
	LevelNavigation.clear_cache()


func after_test() -> void:
	LevelNavigation.clear_cache()


func test_the_same_geometry_reuses_the_bake() -> void:
	var first := _baked_level(Vector2(6, 6))
	var hits := LevelNavigation.cache_hits

	var second := _baked_level(Vector2(6, 6))

	assert_int(LevelNavigation.cache_hits).is_equal(hits + 1)
	assert_object(second.navigation_mesh).is_not_same(first.navigation_mesh)
	assert_int(second.navigation_mesh.get_polygon_count()).is_greater(0)
	assert_int(second.navigation_mesh.get_polygon_count()).is_equal(first.navigation_mesh.get_polygon_count())
	assert_array(Array(second.navigation_mesh.get_vertices())).is_equal(Array(first.navigation_mesh.get_vertices()))


func test_other_geometry_or_settings_bake_anew() -> void:
	var small := _baked_level(Vector2(6, 6))
	var hits := LevelNavigation.cache_hits

	var large := _baked_level(Vector2(9, 9))
	var narrow := _level(Vector2(6, 6))
	narrow.agent_radius = 0.2
	narrow.bake()

	assert_int(LevelNavigation.cache_hits).is_equal(hits)
	assert_array(Array(large.navigation_mesh.get_vertices())).is_not_equal(Array(small.navigation_mesh.get_vertices()))
	assert_array(Array(narrow.navigation_mesh.get_vertices())).is_not_equal(Array(small.navigation_mesh.get_vertices()))


func test_a_rebake_after_an_edit_matches_the_new_geometry() -> void:
	var nav := _baked_level(Vector2(6, 6))
	var before := nav.navigation_mesh.get_vertices()
	var ground := nav.get_parent().get_child(0) as SurfaceFloor

	ground.size = Vector2(9, 9)
	nav.bake()
	var grown := nav.navigation_mesh.get_vertices()
	ground.size = Vector2(6, 6)
	nav.bake()

	assert_array(Array(grown)).is_not_equal(Array(before))
	assert_array(Array(nav.navigation_mesh.get_vertices())).is_equal(Array(before))


func test_only_the_last_bakes_are_kept() -> void:
	_baked_level(Vector2(4, 4))
	for i in LevelNavigation.CACHE_SIZE:
		_baked_level(Vector2(5 + i, 5))
	var hits := LevelNavigation.cache_hits

	_baked_level(Vector2(4, 4))
	assert_int(LevelNavigation.cache_hits).is_equal(hits)
	_baked_level(Vector2(4 + LevelNavigation.CACHE_SIZE, 5))
	assert_int(LevelNavigation.cache_hits).is_equal(hits + 1)


func _baked_level(size: Vector2) -> LevelNavigation:
	var nav := _level(size)
	nav.bake()
	return nav


# A floor of `size` and a disabled LevelNavigation (no bake at load) under a level at SPOT.
func _level(size: Vector2) -> LevelNavigation:
	var level := auto_free(Node3D.new()) as Node3D
	level.position = SPOT
	var ground := FLOOR_SCENE.instantiate() as SurfaceFloor
	ground.size = size
	level.add_child(ground)
	var nav := LevelNavigation.new()
	nav.bake_on_ready = false
	nav.enabled = false
	level.add_child(nav)
	add_child(level)
	return nav
