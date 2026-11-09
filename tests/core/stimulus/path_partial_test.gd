extends GdUnitTestSuite
## Integration (ADR 0094): a PATH noise made on a navmesh island (a block top no path leaves) does
## not leak through a wall. Its navmesh path stops short, and a gap is bridged in a straight line
## only through open air; otherwise the way is searched from the listener back to the source; when
## both are blocked the noise is not heard.
## Fixture (local to the region at ORIGIN): ground (top 0, 20 x 12 m), a wall at x 0 (0.4 m thick,
## 3 m high) over z -6..6, or with a doorway at z 3..5; a 2.5 x 2.5 m block 1.6 m high west of it
## (x -2.85..-0.35, z -2.25..0.25: an island on its top). The source stands on the block.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const ORIGIN := Vector3(300, 0, -300)
const SOURCE := ORIGIN + Vector3(-1.6, 1.6, -1)
## Behind the wall, 3.2 m from the source horizontally (3.6 m straight).
const BEHIND_WALL := ORIGIN + Vector3(1.6, 0, -1)
## In the block's room, 3.4 m west of the source.
const SAME_ROOM := ORIGIN + Vector3(-5, 0, -1)
const LOUDNESS := 20.0

var _root: Node3D
var _region: NavigationRegion3D
var _map_was_async: bool = true


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	await GuardHelpers.let_old_scenes_go(get_tree())
	_root = auto_free(Node3D.new())
	add_child(_root)
	_region = NavigationRegion3D.new()
	_region.position = ORIGIN
	_root.add_child(_region)
	_box(Vector3(20, 1, 12), Vector3(0, -0.5, 0))
	_box(Vector3(2.5, 1.6, 2.5), Vector3(-1.6, 0.8, -1))
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())


func after_test() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)


func test_noise_on_an_island_is_not_heard_through_a_wall() -> void:
	_box(Vector3(0.4, 3, 12), Vector3(0, 1.5, 0))
	await _bake()
	var listener := _listener(BEHIND_WALL)

	StimulusSystem.emit(Stimulus.make_noise(LOUDNESS, SOURCE))
	await Fixtures.frames(get_tree(), 2)

	# Before ADR 0094 it was heard 3.7 m away, straight through the wall.
	assert_array(_received_by(listener)).is_empty()


func test_noise_on_an_island_is_heard_by_the_doorway_route() -> void:
	_box(Vector3(0.4, 3, 9), Vector3(0, 1.5, -1.5))
	_box(Vector3(0.4, 3, 1), Vector3(0, 1.5, 5.5))
	await _bake()
	var listener := _listener(BEHIND_WALL)

	StimulusSystem.emit(Stimulus.make_noise(LOUDNESS, SOURCE))
	await Fixtures.frames(get_tree(), 2)

	var received := _received_by(listener)
	assert_int(received.size()).is_equal(1)
	if received.is_empty():
		return
	# Round the wall's end at z 3: at least 4.2 m to the doorway and 4.5 m on to the block top.
	assert_str(received[0].data["propagation"]).is_equal("path")
	assert_float(received[0].data["distance"]).is_between(8.7, 16.0)


func test_noise_on_an_island_is_heard_across_open_air() -> void:
	_box(Vector3(0.4, 3, 12), Vector3(0, 1.5, 0))
	await _bake()
	var listener := _listener(SAME_ROOM)

	StimulusSystem.emit(Stimulus.make_noise(LOUDNESS, SOURCE))
	await Fixtures.frames(get_tree(), 2)

	var received := _received_by(listener)
	assert_int(received.size()).is_equal(1)
	if received.is_empty():
		return
	# Across the block top and down through the air (4.5 m measured), not round any wall.
	assert_float(received[0].data["distance"]).is_between(SOURCE.distance_to(SAME_ROOM), 5.5)


func test_noise_on_a_wall_face_is_heard_in_the_room() -> void:
	_box(Vector3(0.4, 3, 12), Vector3(0, 1.5, 0))
	await _bake()
	var listener := _listener(SAME_ROOM + Vector3(0, 0, -3))
	# A bullet's impact on the wall's west face, 1.5 m up: its gap to the floor ends on that face.
	var impact := ORIGIN + Vector3(-0.2, 1.5, -4)

	StimulusSystem.emit(Stimulus.make_noise(LOUDNESS, impact))
	await Fixtures.frames(get_tree(), 2)

	var received := _received_by(listener)
	assert_int(received.size()).is_equal(1)
	if received.is_empty():
		return
	assert_float(received[0].data["distance"]).is_less(impact.distance_to(SAME_ROOM + Vector3(0, 0, -3)) + 1.5)


func _box(size: Vector3, centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	_region.add_child(body)


func _listener(position: Vector3) -> Node3D:
	return Fixtures.entity(_root, "Listener", position, [Fixtures.receptron(&"noise")])


func _received_by(listener: Node3D) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == listener.name
	)


## Bakes the navmesh (a character-sized agent) and checks the block top is an island.
func _bake() -> void:
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = 0.35
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.3
	_region.navigation_mesh = mesh
	await GuardHelpers.use_sync_iterations(_map(), _region)
	GuardHelpers.isolate_region(_map(), _region)
	_region.bake_navigation_mesh(false)
	await Fixtures.frames(get_tree(), 3)
	var on_top := NavigationServer3D.map_get_closest_point(_map(), SOURCE)
	assert_float(on_top.y).override_failure_message("no island on the block: %s" % on_top).is_greater(1.4)


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map
