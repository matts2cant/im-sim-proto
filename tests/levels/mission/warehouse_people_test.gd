extends GdUnitTestSuite
## Warehouse population (design/levels/mission-warehouse.md "Guards", "Equipment to find"): the
## eight guards stand on the navmesh with their loadouts and access tags; the posts and the rifle
## guard's catwalk stand in light (>= 0.5, the player sees them and they see the player); patrol
## routes cross no doorway (the doors there are locked to guards or loud); every item to find is
## placed and reachable on foot from the player's start (a navmesh point within pick-up reach,
## through every door: the keys are found on the way, warehouse_doors_test), or lies where a listed
## climb leads. Guards reach their posts through the doors their access tags open. Positions and
## routes come from the layout markers (tools/level_gen/warehouse_people.py).

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
const PEOPLE := "Population/People"
const REACH := 0.35
const LIT := 0.5
## Pick-up reach from the eyes, and the eye height of a standing player.
const PICK_REACH := 2.0
const EYE := 1.65
## A path keeps this far (centre to centre, horizontal) from a doorway's centre line to miss it.
const DOORWAY_CLEAR := 1.0

## Guard -> [weapon item id, access tags, follows a route].
const GUARDS: Dictionary[String, Array] = {
	"G1GatePost": ["pistol", [], false],
	"G2YardPatrolWest": ["baton", [], true],
	"G3YardPatrolEast": ["pistol", [], true],
	"G4CatwalkRifle": ["assault_rifle", [], true],
	"G5SecurityOperator": ["pistol", [&"access.warehouse_security"], false],
	"G6BreakRoom": ["baton", [], false],
	"G7VaultDoor": ["pistol", [&"access.warehouse_vault"], false],
	"G8OffDuty": ["baton", [], false],
}
## Guards whose post stands in light, and the lit points of the rifle guard's catwalk route.
const LIT_POSTS: Array[String] = ["G1GatePost", "G5SecurityOperator", "G6BreakRoom", "G7VaultDoor", "G8OffDuty"]
const LIT_ROUTE_POINTS: Array[String] = ["CatwalkA", "CatwalkB", "CatwalkC"]
## Item id -> pickups placed.
const ITEMS: Dictionary[String, int] = {
	"silencer": 1,
	"sniper_rifle": 1,
	"sniper_rounds": 1,
	"shotgun": 1,
	"shotgun_shells": 1,
	"lockpick": 1,
	"biocell": 2,
	"pistol_ammo": 2,
	"rifle_rounds": 1,
	"medkit": 1,
	"prototype": 1,
}
## Pickups off the navmesh -> [a navmesh point the player walks from, the stand spot it walks to]:
## the 4.4 m rack deck is a step down off the bridge between two rack posts (the railing has a gap).
const WALK_INS: Dictionary[String, Array] = {
	"PistolAmmoRack": [Vector3(-13.0, 4.5, 6.0), Vector3(-13.0, 4.4, 8.4)],
}

var _level: Node3D
var _map: RID


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	StimulusSystem.clear()
	if _map.is_valid():
		NavigationServer3D.map_set_use_async_iterations(_map, true)


func test_guards_stand_on_the_navmesh_with_their_loadouts_and_access() -> void:
	await _load()
	var guards := _level.get_node(PEOPLE + "/Guards")
	assert_int(guards.get_child_count()).is_equal(GUARDS.size())
	var start := (_level.get_node("ReinforcementSpawn") as Node3D).global_position
	for guard_name: String in GUARDS:
		var spec: Array = GUARDS[guard_name]
		var guard := guards.get_node(guard_name) as NavWalker
		assert_object(guard).override_failure_message(guard_name).is_not_null()
		var layers := AccessLayers.agent_layers(ActorState.tags_of(guard).container)
		(
			assert_bool(_reaches(start, guard.global_position, layers))
			. override_failure_message("%s off the navmesh" % guard_name)
			. is_true()
		)
		var holder := guard.get_node("Aim/WeaponHolder") as WeaponHolder
		assert_int(holder.weapons.size()).is_equal(1)
		assert_str(String(holder.weapons[0].item_id)).override_failure_message(guard_name).is_equal(spec[0])
		var tags := ActorState.tags_of(guard)
		assert_bool(tags.has(&"actor.guard")).is_true()
		for access: StringName in spec[1]:
			assert_bool(tags.has(access)).override_failure_message("%s lacks %s" % [guard_name, access]).is_true()
		var route := (guard.get_node("Behaviour") as AwarenessBehaviour).route
		assert_bool(route != null).override_failure_message("%s route" % guard_name).is_equal(spec[2])
		if route != null:
			for point in route.points():
				(
					assert_bool(_reaches(start, point.global_position, layers))
					. override_failure_message("%s/%s" % [guard_name, point.name])
					. is_true()
				)


func test_posts_and_the_catwalk_stand_in_light() -> void:
	await _load()
	var dark: PackedStringArray = []
	for guard_name in LIT_POSTS:
		var feet := (_level.get_node(PEOPLE + "/Guards/" + guard_name) as Node3D).global_position
		var level := _measure(feet)
		if level < LIT:
			dark.append("%s: %.2f" % [guard_name, level])
	var route := _level.get_node(PEOPLE + "/Routes/G4CatwalkRifleRoute")
	for point_name in LIT_ROUTE_POINTS:
		var level := _measure((route.get_node(point_name) as Node3D).global_position)
		if level < LIT:
			dark.append("%s: %.2f" % [point_name, level])
	assert_array(dark).is_empty()


func test_patrol_routes_cross_no_doorway() -> void:
	await _load()
	var crossed: PackedStringArray = []
	var doorways := _level.get_node("LayoutMarkers/Doorways").get_children()
	for route: Node in _level.get_node(PEOPLE + "/Routes").get_children():
		var points := (route as PatrolRoute).points()
		for i in points.size():
			var from := points[i].global_position
			var to := points[(i + 1) % points.size()].global_position
			var path := NavigationServer3D.map_get_path(_map, from, to, true)
			for doorway: Node3D in doorways:
				if _path_near(path, doorway.global_position):
					crossed.append(
						(
							"%s %s->%s: %s"
							% [route.name, points[i].name, points[(i + 1) % points.size()].name, doorway.name]
						)
					)
	assert_array(crossed).is_empty()


func test_every_item_is_placed_and_reachable() -> void:
	await _load()
	var start := (_level.get_node("PlayerSpawn") as Node3D).global_position
	var counts := {}
	var unreachable: PackedStringArray = []
	for node: Node in _level.get_node(PEOPLE + "/Items").get_children():
		var pickup := ItemPickup.of(node)
		assert_object(pickup).override_failure_message(node.name).is_not_null()
		var id := String(pickup.item.id)
		counts[id] = int(counts.get(id, 0)) + 1
		var at := (node as Node3D).global_position
		if WALK_INS.has(String(node.name)):
			var walk: Array = WALK_INS[String(node.name)]
			if (
				not _reaches(start, walk[0], AccessLayers.ALL)
				or not _walk_clear(walk[0], walk[1])
				or not _within_reach(walk[1], at)
			):
				unreachable.append("%s at %s (walked to from %s)" % [node.name, at, walk[0]])
		elif not _stand_spot_reaches(start, at):
			unreachable.append("%s at %s" % [node.name, at])
	for id: String in ITEMS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s pickups" % id).is_equal(ITEMS[id])
	assert_array(unreachable).is_empty()


# True when a navmesh point reachable from `start` has the item at `at` within pick-up reach: the
# point under the item or one of the points around it (furniture keeps the navmesh away).
func _stand_spot_reaches(start: Vector3, at: Vector3) -> bool:
	var probes: Array[Vector3] = [at]
	for i in 12:
		var angle := TAU * i / 12.0
		for distance: float in [0.7, 1.1]:
			probes.append(at + Vector3(cos(angle), 0.0, sin(angle)) * distance + Vector3.DOWN * 0.6)
	for probe in probes:
		var stand := NavigationServer3D.map_get_closest_point(_map, probe)
		if _within_reach(stand, at) and _reaches(start, stand, AccessLayers.ALL):
			return true
	return false


func _within_reach(stand: Vector3, at: Vector3) -> bool:
	return (stand + Vector3.UP * EYE).distance_to(at) <= PICK_REACH - 0.2


# A standing capsule walks from `from` to `to` (feet; lifted over steps) without hitting anything.
func _walk_clear(from: Vector3, to: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.4
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = PhysicsLayers.WORLD
	params.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * 1.05)
	params.motion = to - from
	var space := _level.get_world_3d().direct_space_state
	if not space.intersect_shape(params, 1).is_empty():
		return false
	var fractions := space.cast_motion(params)
	return fractions.is_empty() or fractions[0] >= 1.0


# `layers`: the navigation layers of who walks (AccessLayers: WALK, a guard's access, ALL for the
# player with the keys).
func _reaches(from: Vector3, to: Vector3, layers: int = AccessLayers.WALK) -> bool:
	var path := NavigationServer3D.map_get_path(_map, from, to, true, layers)
	return not path.is_empty() and path[-1].distance_to(to) < REACH


# True when a navmesh path passes within DOORWAY_CLEAR (horizontal) of a doorway at the same level.
func _path_near(path: PackedVector3Array, doorway: Vector3) -> bool:
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		if absf(a.y - doorway.y) > 1.0 and absf(b.y - doorway.y) > 1.0:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(doorway, a, b)
		if Vector2(closest.x - doorway.x, closest.z - doorway.z).length() < DOORWAY_CLEAR:
			return true
	return false


# Light level of a standing stand-in body at `feet`.
func _measure(feet: Vector3) -> float:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.ACTORS
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.add_child(Tags.new())
	var exposure := LightExposure.new()
	body.add_child(exposure)
	_level.add_child(body)
	body.global_position = feet
	var level := exposure.update_now()
	body.free()
	return level


func _load() -> void:
	await GuardHelpers.let_old_scenes_go(get_tree())
	_level = auto_free(LEVEL.instantiate())
	_level.get_node("Mission").free()
	add_child(_level)
	await KitGeometry.settle(get_tree(), 3)
	var region := _level.get_node("Navigation") as LevelNavigation
	_map = region.get_navigation_map()
	await GuardHelpers.use_sync_iterations(_map, region)
	GuardHelpers.isolate_region(_map, region)
	region.bake()
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _map, Vector3(0, 0, 0))).is_true()
