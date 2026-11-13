extends GdUnitTestSuite
## Integration: noise PATH propagation along a navmesh baked at test time. Two rooms split by a
## wall at x = 0 (z -5..3) with a doorway at z 3..5; the source stands in the left room.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const TWO_ROOMS := "res://tests/core/stimulus/fixtures/two_rooms.tscn"
const SOURCE := Vector3(-3, 0, -3)
const BEHIND_WALL := Vector3(3, 0.5, -3)
const SAME_ROOM := Vector3(-3, 0.5, 1)

var _rooms: Node3D
var _paths: Array[PackedVector3Array] = []
var _map_was_async: bool = true


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_paths = []
	_rooms = auto_free(load(TWO_ROOMS).instantiate())
	add_child(_rooms)
	# Synchronous map iterations: region changes (this fixture, the previous test's freed one)
	# reach path queries on the next physics frame instead of whenever a worker thread finishes.
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())
	var region: NavigationRegion3D = _rooms.get_node("NavigationRegion")
	await GuardHelpers.use_sync_iterations(_map(), region)
	await Wait.frames(get_tree(), 2)


func after_test() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)
	if StimulusSystem.stimulus_processed.is_connected(_on_processed):
		StimulusSystem.stimulus_processed.disconnect(_on_processed)


func test_listener_behind_wall_hears_via_doorway_path_length() -> void:
	await _bake()
	var listener := _listener(BEHIND_WALL)

	var received := await _noise_received(listener, 20.0)

	var straight := SOURCE.distance_to(BEHIND_WALL)
	var expected := _expected_path_length(BEHIND_WALL)
	assert_str(received.data["propagation"]).is_equal("path")
	assert_float(received.data["distance"]).is_equal_approx(expected, 0.01)
	# The shortest way round the wall end (0, 3) is 2 x sqrt(3^2 + 6^2) = 13.4 m, vs 6 m straight.
	assert_float(received.data["distance"]).is_between(13.4, 16.0)
	assert_float(received.data["distance"]).is_greater(straight + 7.0)
	assert_float(received.data["perceived"]).is_equal_approx(20.0 - expected, 0.01)


func test_noise_shorter_than_path_is_not_heard_behind_wall() -> void:
	await _bake()
	var listener := _listener(BEHIND_WALL)

	# 10 m reaches 6 m straight, but not the ~14 m path round the wall.
	StimulusSystem.emit(Stimulus.make_noise(10.0, SOURCE))
	await Wait.frames(get_tree(), 2)

	assert_array(_received_by(listener)).is_empty()


func test_listener_in_same_room_hears_at_about_straight_distance() -> void:
	await _bake()
	var listener := _listener(SAME_ROOM)

	var received := await _noise_received(listener, 20.0)

	assert_float(received.data["distance"]).is_equal_approx(_expected_path_length(SAME_ROOM), 0.01)
	assert_float(received.data["distance"]).is_between(
		SOURCE.distance_to(SAME_ROOM), SOURCE.distance_to(SAME_ROOM) + 0.6
	)


func test_attenuator_in_doorway_adds_its_extra_metres_once() -> void:
	await _bake()
	var listener := _listener(BEHIND_WALL)
	var near := _listener(SAME_ROOM)
	var door: SoundAttenuator = _rooms.get_node("DoorAttenuator")
	door.enabled = true

	var received := await _noise_received(listener, 30.0)

	assert_float(received.data["distance"]).is_equal_approx(
		_expected_path_length(BEHIND_WALL) + door.extra_metres, 0.01
	)
	var unaffected := _received_by(near)
	assert_float(unaffected[0].data["distance"]).is_equal_approx(_expected_path_length(SAME_ROOM), 0.01)


func test_disabled_attenuator_adds_nothing() -> void:
	await _bake()
	var listener := _listener(BEHIND_WALL)

	var received := await _noise_received(listener, 30.0)

	assert_float(received.data["distance"]).is_equal_approx(_expected_path_length(BEHIND_WALL), 0.01)


func test_without_navmesh_falls_back_to_straight_line() -> void:
	# The region is never baked, so the map has no navigation polygons.
	await Wait.frames(get_tree(), 2)
	var listener := _listener(BEHIND_WALL)

	var received := await _noise_received(listener, 10.0)

	assert_str(received.data["propagation"]).is_equal("straight_fallback")
	assert_float(received.data["distance"]).is_equal_approx(SOURCE.distance_to(BEHIND_WALL), 0.0001)


func test_fallback_still_applies_attenuators_on_the_straight_line() -> void:
	await Wait.frames(get_tree(), 2)
	var door: SoundAttenuator = _rooms.get_node("DoorAttenuator")
	door.enabled = true
	var listener := _listener(Vector3(3, 0.5, 4))
	var source := Vector3(-3, 0.5, 4)

	StimulusSystem.emit(Stimulus.make_noise(20.0, source))
	await Wait.frames(get_tree(), 2)

	var received := _received_by(listener)
	assert_int(received.size()).is_equal(1)
	assert_float(received[0].data["distance"]).is_equal_approx(6.0 + door.extra_metres, 0.0001)


func test_processed_signal_carries_the_path_polyline() -> void:
	await _bake()
	_listener(BEHIND_WALL)
	StimulusSystem.stimulus_processed.connect(_on_processed)

	StimulusSystem.emit(Stimulus.make_noise(20.0, SOURCE))
	await Wait.frames(get_tree(), 2)

	assert_int(_paths.size()).is_equal(1)
	assert_int(_paths[0].size()).is_greater(3)
	assert_vector(_paths[0][0]).is_equal(SOURCE)
	assert_vector(_paths[0][_paths[0].size() - 1]).is_equal(BEHIND_WALL)


func _on_processed(_stimulus: Stimulus, paths: Array[PackedVector3Array]) -> void:
	_paths.append_array(paths)


func _listener(position: Vector3) -> Node3D:
	return Fixtures.entity(_rooms, "Listener%d" % _rooms.get_child_count(), position, [Fixtures.receptron(&"noise")])


func _noise_received(listener: Node3D, loudness: float) -> EventLogEntry:
	StimulusSystem.emit(Stimulus.make_noise(loudness, SOURCE))
	await Wait.frames(get_tree(), 2)
	var received := _received_by(listener)
	assert_int(received.size()).is_equal(1)
	return received[0] if not received.is_empty() else EventLogEntry.new(0, &"", "", "", {"distance": -1.0})


func _received_by(listener: Node3D) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == listener.name
	)


## Bakes the navmesh and waits until the map serves paths through the doorway.
func _bake() -> void:
	var region: NavigationRegion3D = _rooms.get_node("NavigationRegion")
	# The fixture's NavigationMesh is shared by every instance: bake a copy so it stays empty.
	region.navigation_mesh = region.navigation_mesh.duplicate() as NavigationMesh
	region.bake_navigation_mesh(false)
	await Wait.frames(get_tree(), 2)
	assert_int(NavigationServer3D.map_get_path(_map(), SOURCE, BEHIND_WALL, true).size()).is_greater(2)


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map


## Independent of StimulusSystem: origin -> navmesh path -> receiver, straight segments summed.
func _expected_path_length(to: Vector3) -> float:
	var nav := NavigationServer3D.map_get_path(_map(), SOURCE, to, true)
	var total := SOURCE.distance_to(nav[0]) + nav[nav.size() - 1].distance_to(to)
	for i in range(1, nav.size()):
		total += nav[i - 1].distance_to(nav[i])
	return total
