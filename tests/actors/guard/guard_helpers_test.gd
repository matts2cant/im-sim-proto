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
## How long the busy test keeps every worker thread busy (ms of real time): well past the old
## 120-frame cap, well under GuardHelpers.ASYNC_LANDING_MS.
const BUSY_MS := 250

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


func test_the_switch_recovers_when_worker_threads_are_busy() -> void:
	# Regression (M9h): a one-process full run next to other test runs failed this suite and
	# path_partial_test. The pending asynchronous iteration runs on a worker thread; with the
	# machine busy it landed after the recovery's 120-frame cap (about 30 ms of real time at the
	# runner's fixed fps) and the map stayed wedged. Two busy tasks per core reproduce it here
	# (the old cap failed 5 runs in 6).
	NavigationServer3D.map_set_use_async_iterations(_map(), true)
	var far := _square_region(FAR)
	for i in 10:
		await get_tree().physics_frame
	var near := _square_region(NEAR)
	var busy := WorkerThreadPool.add_group_task(_busy, OS.get_processor_count() * 2, -1, true)
	far.enabled = false
	far.enabled = true
	await get_tree().physics_frame

	await GuardHelpers.use_sync_iterations(_map(), near)
	WorkerThreadPool.wait_for_group_task_completion(busy)

	var path := NavigationServer3D.map_get_path(_map(), NEAR + Vector3(-3, 0, 0), NEAR + Vector3(3, 0, 0), true)
	assert_bool(path.is_empty()).is_false()
	assert_float(path[0].distance_to(NEAR)).is_less(5.0)


## Keeps a worker thread busy for BUSY_MS of real time.
func _busy(_index: int) -> void:
	var until := Time.get_ticks_msec() + BUSY_MS
	while Time.get_ticks_msec() < until:
		pass


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
