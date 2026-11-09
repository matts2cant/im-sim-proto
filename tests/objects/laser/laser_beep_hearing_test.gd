extends GdUnitTestSuite
## Integration (ADR 0096, with ADR 0094's noise reach): the shipped laser's trip beep (noise 8 at
## the emitter) on a baked navmesh. Fixture (local to the region at ORIGIN): ground 20 x 12 m (top
## 0), a wall at x 0 (0.4 m thick, 3 m high) over the whole ground's width (z -6..6), so the two
## sides share no navmesh path. The laser is on the wall's east face (x 0.2) beaming 3 m east along
## +X at z 0, at 0.4 m or 1.3 m; a box stand-in steps into the beam. A listener 4 m east of the wall
## in the same room hears the beep; one 2 m west of the wall, behind it, does not.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const LASER: PackedScene = preload("res://objects/laser/laser_array.tscn")
const ORIGIN := Vector3(-300, 0, -600)
## In the laser's room, 2 m from the beam's line (z 2) and 4 m from the wall.
const SAME_ROOM := Vector3(4, 0, 2)
const BEHIND_WALL := Vector3(-2, 0, 0)

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
	_box(Vector3(0.4, 3, 12), Vector3(0, 1.5, 0))
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(_map())


func after_test() -> void:
	NavigationServer3D.map_set_use_async_iterations(_map(), _map_was_async)
	StimulusSystem.clear()


func test_the_low_beams_beep_is_heard_in_its_room_only() -> void:
	await _trip_at(0.4)


func test_the_high_beams_beep_is_heard_in_its_room_only() -> void:
	await _trip_at(1.3)


func _trip_at(height: float) -> void:
	await _bake()
	var laser := LASER.instantiate() as Node3D
	laser.position = ORIGIN + Vector3(0.2, height, 0)
	laser.basis = Basis(Vector3.UP, PI * 0.5)
	(laser.get_node("Beam1") as LaserBeam).length = 3.0
	_root.add_child(laser)
	var near := Fixtures.entity(_root, "Near", ORIGIN + SAME_ROOM, [Fixtures.receptron(&"noise")])
	var behind := Fixtures.entity(_root, "Behind", ORIGIN + BEHIND_WALL, [Fixtures.receptron(&"noise")])
	await Fixtures.frames(get_tree(), 3)
	EventLog.clear()
	_intruder(ORIGIN + Vector3(1.5, 0, 0))
	await Fixtures.frames(get_tree(), 5)

	assert_array(EventLog.find(&"laser.tripped")).has_size(1)
	var heard := _received_by(near)
	assert_array(heard).has_size(1)
	assert_array(_received_by(behind)).is_empty()
	if heard.is_empty():
		return
	# Found over the baked navmesh, not the no-navmesh fallback.
	assert_str(String(heard[0].data["propagation"])).is_not_equal("straight_fallback")


# A 0.6 x 1.8 x 0.6 m stand-in tagged actor.player with its feet at `feet`.
func _intruder(feet: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.PLAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	shape.shape = box
	shape.position.y = 0.9
	body.add_child(shape)
	Fixtures.compose(body, _root, "Intruder", feet, [], [&"actor.player"])


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


func _received_by(listener: Node3D) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == listener.name and entry.data.get("type") == &"noise"
	)


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


func _map() -> RID:
	return get_tree().root.find_world_3d().navigation_map
