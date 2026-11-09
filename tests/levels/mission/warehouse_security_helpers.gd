extends RefCounted
## Test helper (not a suite): loads the warehouse level (without its Mission, so no player spawns
## and no briefing pauses it) under a suite, optionally with synchronous navigation, and names the
## security population's parts (`levels/mission/population/security.tscn`, design/levels/
## mission-warehouse.md "Doors, locks and keys", "Security network"). Coordinates are warehouse
## (world) coordinates.

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
const SECURITY := "Population/Security"
const PEOPLE := "Population/People"

var level: Node3D
var map: RID
## Where the people population's guards stand and its patrol points lie (name -> world position),
## read before the guards are removed.
var guard_spots: Dictionary[String, Vector3] = {}


## Instances the level under `suite` (auto_free), lets CSG build its collision and, with
## `navigation`, bakes the navmesh on a synchronous map isolated from other suites' regions. Without
## `people` the people population's guards are removed first (their spots are kept in
## guard_spots), so they neither move, open doors nor raise alarms during security tests; its props
## (the weak wall's breach panel, furniture) stay.
func load_level(suite: GdUnitTestSuite, navigation: bool = false, people: bool = false) -> Node3D:
	await GuardHelpers.let_old_scenes_go(suite.get_tree())
	level = suite.auto_free(LEVEL.instantiate())
	level.get_node("Mission").free()
	guard_spots.clear()
	var guards := level.get_node_or_null(PEOPLE + "/Guards")
	var routes := level.get_node_or_null(PEOPLE + "/Routes")
	var spots: Array[Node] = guards.get_children() if guards != null else []
	if routes != null:
		for route in routes.get_children():
			spots.append_array(route.get_children())
	for node in spots:
		guard_spots[String(node.name)] = _level_position(node as Node3D)
	if not people and level.has_node(PEOPLE + "/Guards"):
		level.get_node(PEOPLE + "/Guards").free()
	suite.add_child(level)
	await KitGeometry.settle(suite.get_tree(), 5)
	if navigation:
		var region := level.get_node("Navigation") as LevelNavigation
		map = region.get_navigation_map()
		await GuardHelpers.use_sync_iterations(map, region)
		GuardHelpers.isolate_region(map, region)
		# A region switched to synchronous iterations after its bake can lose that update: bake again.
		region.bake()
		await KitGeometry.wait_for_navigation(suite.get_tree(), map, Vector3(0, 0, 0))
	EventLog.clear()
	return level


# A node's position in the level, from its local transforms (the level is not in the tree yet).
func _level_position(node: Node3D) -> Vector3:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != level and parent != null:
		if parent is Node3D:
			xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform.origin


func teardown() -> void:
	if map.is_valid():
		NavigationServer3D.map_set_use_async_iterations(map, true)


func door_entity(door_name: String) -> StaticBody3D:
	return level.get_node("%s/Doors/%s" % [SECURITY, door_name]) as StaticBody3D


func door(door_name: String) -> Door:
	return Door.of(door_entity(door_name))


func device_entity(device_name: String) -> Node3D:
	return level.get_node("%s/Devices/%s" % [SECURITY, device_name]) as Node3D


func device(device_name: String) -> Device:
	return Device.of(device_entity(device_name))


func console() -> Terminal:
	return Terminal.of(device_entity("SecurityConsole"))


## Every Door under the security population.
func doors() -> Array[Door]:
	var result: Array[Door] = []
	for entity: Node in level.get_node(SECURITY + "/Doors").get_children():
		result.append(Door.of(entity))
	return result


## A stand-in entity (Tags `tags`, a receiver with `receptrons`) at `position` under the level.
func stand_in(
	entity_name: String, position: Vector3, tags: Array[StringName] = [], receptrons: Array[Receptron] = []
) -> Node3D:
	var node := Node3D.new()
	node.name = entity_name
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	tag_node.initial_tags = tags
	node.add_child(tag_node)
	var receiver := StimulusReceiver.new()
	receiver.name = "StimulusReceiver"
	receiver.receptrons = receptrons
	node.add_child(receiver)
	node.position = position
	level.add_child(node)
	return node


func frames(count: int) -> void:
	for i in count:
		await level.get_tree().physics_frame


func seconds(value: float) -> void:
	await frames(roundi(value * 60.0))


## Waits up to `limit` seconds for an EventLog entry of `kind`; true when one came.
func wait_for(kind: StringName, limit: float) -> bool:
	for tick in roundi(limit * 60.0):
		if not EventLog.find(kind).is_empty():
			return true
		await frames(1)
	return not EventLog.find(kind).is_empty()
