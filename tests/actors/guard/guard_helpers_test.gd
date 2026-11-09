extends GdUnitTestSuite
## Integration: GuardHelpers.use_sync_iterations() (ADR 0084) leaves a map that iterates, also when
## it is switched while an asynchronous iteration runs, which wedges a Godot 4.7.2 map for good.
## Regression: barrel_chain_test failed in full runs on master (nobody heard the barrel): its map
## wedged after the previous suite, the new fixture's region never joined it and the noise path ran
## to the previous fixture's floor 200 m away and back. Regions here sit at x -200 and x 0 / z 800,
## away from other suites' fixtures.

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const NEAR := Vector3(-200, 0, 800)
const FAR := Vector3(0, 0, 800)

var _regions: Array[NavigationRegion3D] = []
var _map_was_async: bool = true


func before_test() -> void:
	_regions.clear()
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())


func after_test() -> void:
	for region in _regions:
		if is_instance_valid(region):
			region.free()
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)


func test_a_region_added_while_an_async_iteration_runs_reaches_path_queries() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), true)
	var far := _square_region(FAR)
	for i in 10:
		await get_tree().physics_frame
	var near := _square_region(NEAR)
	# Start an asynchronous iteration and switch while it runs, as a fixture right after loading.
	far.enabled = false
	far.enabled = true
	await get_tree().physics_frame

	await GuardHelpers.use_sync_iterations(_map(), near)

	var path := NavigationServer3D.map_get_path(_map(), NEAR + Vector3(-3, 0, 0), NEAR + Vector3(3, 0, 0), true)
	assert_bool(path.is_empty()).is_false()
	assert_float(path[0].distance_to(NEAR)).is_less(5.0)
	assert_float(path[path.size() - 1].distance_to(NEAR)).is_less(5.0)


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map


## A 20 m square navmesh region centred on `centre`.
func _square_region(centre: Vector3) -> NavigationRegion3D:
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array(
		[
			centre + Vector3(-10, 0, -10),
			centre + Vector3(10, 0, -10),
			centre + Vector3(10, 0, 10),
			centre + Vector3(-10, 0, 10)
		]
	)
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	add_child(region)
	_regions.append(region)
	return region
