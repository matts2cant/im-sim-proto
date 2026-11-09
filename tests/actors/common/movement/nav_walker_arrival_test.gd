extends GdUnitTestSuite
## Integration (ADR 0094): NavWalker arrives only within arrive_distance horizontally and
## arrive_height vertically. A walker standing right under a target on a slab 3.3 m above walks the
## navmesh path up the ramp instead of counting as arrived where it stands; without a navmesh,
## standing right under the target is as close as it gets.
## Fixture (local to the region at ORIGIN): ground (top 0), a 4 x 4 m slab (top 3.3, underside 3.0)
## over the middle, a 30 degree ramp from the ground at x 7.7 up to the slab's east edge (x 2).

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const WALKER_CONFIG: NavWalkerConfig = preload("res://actors/guard/guard_walker.tres")
## Far from the origin and the other navigation fixtures (design/tech/testing.md).
const ORIGIN := Vector3(-300, 0, -300)
const SLAB_TOP := 3.3
## Run pace (m/s): the way round by the ramp is about 16 m.
const SPEED := 5.0

var _root: Node3D
var _region: NavigationRegion3D
var _map_was_async: bool = true


func before_test() -> void:
	await GuardHelpers.let_old_scenes_go(get_tree())
	_root = auto_free(Node3D.new())
	add_child(_root)
	_region = NavigationRegion3D.new()
	_region.position = ORIGIN
	_root.add_child(_region)
	_box(Vector3(30, 1, 30), Vector3(0, -0.5, 0), 0.0)
	_box(Vector3(4, 0.3, 4), Vector3(0, SLAB_TOP - 0.15, 0), 0.0)
	# Top surface from (2, 3.3) down to (7.72, 0): 6.6 m long at 30 degrees, centre 0.15 m below it.
	var up := Vector3(0.5, 0.866, 0)
	_box(Vector3(6.6, 0.3, 2), Vector3(4.86, 1.65, 0) - up * 0.15, -PI / 6.0)
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())


func after_test() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)


func test_walks_the_path_up_to_a_target_right_above_it() -> void:
	await _bake()
	var walker := _walker(true)
	await Fixtures.frames(get_tree(), 2)
	var target := ORIGIN + Vector3(0, SLAB_TOP, 0)

	walker.move_to(target, SPEED)
	await Fixtures.frames(get_tree(), 10)
	assert_bool(walker.is_arrived()).override_failure_message("arrived right under the target").is_false()
	for i in 600:
		if walker.is_arrived():
			break
		await get_tree().physics_frame

	assert_bool(walker.is_arrived()).is_true()
	assert_float(walker.global_position.y).is_greater(SLAB_TOP - 0.3)
	# The agent finishes its path within its path_desired_distance (1 m by default) of the last point.
	var gap := Vector2(walker.global_position.x - target.x, walker.global_position.z - target.z).length()
	assert_float(gap).is_less(1.0)


func test_without_a_navmesh_arrives_right_under_the_target() -> void:
	var walker := _walker(false)
	await Fixtures.frames(get_tree(), 2)
	var start := walker.global_position

	walker.move_to(ORIGIN + Vector3(0, SLAB_TOP, 0), SPEED)
	await Fixtures.frames(get_tree(), 10)

	assert_bool(walker.is_arrived()).is_true()
	assert_float(walker.global_position.distance_to(start)).is_less(0.05)


func _box(size: Vector3, centre: Vector3, roll: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	body.rotation.z = roll
	_region.add_child(body)


func _walker(with_agent: bool) -> NavWalker:
	var walker := NavWalker.new()
	walker.config = WALKER_CONFIG
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	walker.add_child(shape)
	if with_agent:
		walker.add_child(NavigationAgent3D.new())
	walker.position = ORIGIN + Vector3(0, 0.05, 0)
	_root.add_child(walker)
	return walker


func _bake() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.35
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.3
	mesh.agent_max_slope = 45.0
	_region.navigation_mesh = mesh
	await GuardHelpers.use_sync_iterations(_map(), _region)
	GuardHelpers.isolate_region(_map(), _region)
	_region.bake_navigation_mesh(false)
	await Fixtures.frames(get_tree(), 3)
	var path := NavigationServer3D.map_get_path(_map(), ORIGIN, ORIGIN + Vector3(0, SLAB_TOP, 0), true)
	assert_float(path[path.size() - 1].y if not path.is_empty() else 0.0).is_greater(SLAB_TOP - 0.3)


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map
