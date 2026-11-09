extends RefCounted
## Test helper (not a suite): loads the guard fixture (tests/scenarios/fixtures/guard_post.tscn:
## floor, wall, closet behind a large crate, a 3-point route, one guard at the origin facing -Z,
## LevelNavigation) in a scene runner with synchronous navigation iterations, and builds tagged
## stand-in entities (a Node3D with Tags) to be the source of noises and hits.

const POST := "res://tests/scenarios/fixtures/guard_post.tscn"
const POST_WITH_PLAYER := "res://tests/scenarios/fixtures/guard_post_player.tscn"
const TIME_FACTOR := 9.0

var runner: GdUnitSceneRunner
var scene: Node
var guard: NavWalker
var awareness: GradedAwareness
var behaviour: AwarenessBehaviour

var _map_was_async: bool = true


## Loads `path` (POST or POST_WITH_PLAYER) with `runner_factory`'s scene runner. `patrol` false
## leaves the guard at its post.
func setup(p_runner: GdUnitSceneRunner, patrol: bool = false) -> void:
	runner = p_runner
	runner.set_time_factor(TIME_FACTOR)
	scene = runner.scene()
	guard = scene.find_child("Guard", true, false) as NavWalker
	awareness = GradedAwareness.of_node(guard)
	behaviour = guard.get_node("Behaviour") as AwarenessBehaviour
	if not patrol:
		behaviour.route = null
	var map := guard.get_world_3d().navigation_map
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(map)
	var region := scene.find_child("LevelNavigation", true, false) as LevelNavigation
	await use_sync_iterations(map, region)
	isolate_region(map, region)
	# Baked in _ready while the region was still asynchronous: bake again so the map gets it now.
	region.bake()
	await frames(6)
	EventLog.clear()


## Switches `map` and `region` to synchronous iterations (region changes reach path queries on the
## next physics frame instead of whenever a worker thread finishes) and makes sure the map still
## iterates. Godot 4.7.2 wedges a map for good when it is switched to synchronous iterations while
## an asynchronous iteration is still running on a worker thread: it never iterates again, path
## queries come back empty and noise falls back to straight lines. A fixture that switched right
## after loading hit this about half the time when it ran first in a fresh process (door_test
## alone, ADR 0084). Switching the map back to asynchronous lets the pending iteration land, after
## which the switch is safe. Costs two physics frames.
static func use_sync_iterations(map: RID, region: NavigationRegion3D) -> void:
	var tree := region.get_tree()
	NavigationServer3D.map_set_use_async_iterations(map, false)
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	for attempt in 3:
		var before := NavigationServer3D.map_get_iteration_id(map)
		# Any region change makes a synchronous map iterate on the next physics frame.
		region.enabled = not region.enabled
		region.enabled = not region.enabled
		for i in 2:
			await tree.physics_frame
		if NavigationServer3D.map_get_iteration_id(map) != before:
			return
		# Wedged: let the pending asynchronous iteration land, then switch again.
		NavigationServer3D.map_set_use_async_iterations(map, true)
		for i in 120:
			await tree.physics_frame
			if NavigationServer3D.map_get_iteration_id(map) != before:
				break
		NavigationServer3D.map_set_use_async_iterations(map, false)
	push_error("Navigation map stopped iterating after switching to synchronous iterations")


## Switches off every other navigation region in the tree on `map`: a previous suite's fixture
## freed late (auto_free) may still be there for a few frames, and its floor would join this one's
## navmesh and shortcut paths through walls.
static func isolate_region(map: RID, region: NavigationRegion3D) -> void:
	for node in region.get_tree().root.find_children("*", "NavigationRegion3D", true, false):
		var other := node as NavigationRegion3D
		if other != region and other.get_navigation_map() == map:
			other.enabled = false


## Lets fixtures of earlier suites that are freed late (auto_free, queue_free) leave the tree first.
static func let_old_scenes_go(tree: SceneTree) -> void:
	for i in 4:
		await tree.process_frame


func teardown() -> void:
	if guard != null and is_instance_valid(guard):
		NavigationServer3D.map_set_use_async_iterations(guard.get_world_3d().navigation_map, _map_was_async)


func frames(count: int) -> void:
	for i in count:
		await guard.get_tree().physics_frame


func seconds(value: float) -> void:
	await frames(roundi(value * 60.0))


## A Node3D at `position` with Tags `tags` under the scene (a stand-in noise maker or attacker).
func tagged(entity_name: String, position: Vector3, tags: Array[StringName]) -> Node3D:
	var node := Node3D.new()
	node.name = entity_name
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	tag_node.initial_tags = tags
	node.add_child(tag_node)
	scene.add_child(node)
	node.global_position = position
	return node


## EventLog entries of `kind` whose data `actor` is the guard.
static func guard_entries(kind: StringName) -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(func(entry: EventLogEntry) -> bool: return entry.data.get("actor") == "Guard")


## The `to` states of the guard's awareness changes, in order.
static func states() -> Array[String]:
	var result: Array[String] = []
	for entry in guard_entries(&"actor.awareness"):
		result.append(String(entry.data["to"]))
	return result
