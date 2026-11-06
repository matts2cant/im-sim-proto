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
	NavigationServer3D.map_set_use_async_iterations(map, false)
	var region := scene.find_child("LevelNavigation", true, false) as NavigationRegion3D
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	await frames(6)
	EventLog.clear()


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
