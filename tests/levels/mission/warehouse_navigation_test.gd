extends GdUnitTestSuite
## Warehouse navmesh (LevelNavigation, ADR 0041): every guard post and patrol point of the layout
## markers is on the navmesh and connected to the reinforcements' arrival on the road, and so are
## the places guards must be able to search (catwalks, offices, basement, tunnel, ditch, roof, water
## tower). Player-only spots (container tops, rack tops, the office block roof, duct interiors, the
## skylight landings) are off it.

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const LEVEL: PackedScene = preload("res://levels/mission/warehouse.tscn")
const WarehouseHelpers := preload("res://tests/levels/mission/warehouse_helpers.gd")
const REACH := 0.35

## Places guards must reach (warehouse coordinates).
const GUARD_SPOTS: Dictionary[String, Vector3] = {
	"west catwalk": Vector3(-19.25, 4.5, 0),
	"bridge": Vector3(-1, 4.5, 6),
	"east catwalk": Vector3(19.25, 4.5, -4),
	"upper corridor": Vector3(14, 4.5, 6),
	"manager office": Vector3(10, 4.5, 2),
	"upper office": Vector3(16, 4.5, 11),
	"security room": Vector3(17, 0.02, 3),
	"locker room": Vector3(16, 0.02, 11),
	"boiler room": Vector3(12.5, -4, -7),
	"basement store": Vector3(15, -4, 8),
	"tunnel": Vector3(27, -3.2, -5),
	"ditch": Vector3(39, -2.4, 0),
	"annex roof": Vector3(-24, 4.75, 3),
	"main roof": Vector3(-8, 9.5, 12),
	"annex": Vector3(-23, 0, 7),
	"booth": Vector3(-11, 0, -22),
	"back strip": Vector3(-5, 0, 20),
	"riverside": Vector3(0, 0, 29),
	"water tower deck": Vector3(43, 20, -18),
}
## Spots only the player reaches (climbs, drops, crawls).
const PLAYER_ONLY: Dictionary[String, Vector3] = {
	"yard perch container": Vector3(-27, 5.0, -14),
	"inside container": Vector3(-29, 2.5, -23.6),
	"rack top": Vector3(-5, 6.6, 0),
	"skylight landing": Vector3(-5, 8.1, 3.2),
	"office block roof": Vector3(16, 7.35, 10),
	"duct A": Vector3(14, 7.5, -3),
	"drain chamber step": Vector3(31.6, -1.2, -7.6),
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


func test_guard_posts_and_patrol_points_connect_to_the_road() -> void:
	await _load()
	var start := (_level.get_node("ReinforcementSpawn") as Node3D).global_position
	var missing: PackedStringArray = []
	for group: String in ["Guards", "PatrolPoints"]:
		for marker: Node3D in _level.get_node("LayoutMarkers/" + group).get_children():
			if not _reaches(start, marker.global_position):
				missing.append("%s/%s" % [group, marker.name])
	assert_array(missing).is_empty()


func test_guards_can_search_every_area() -> void:
	await _load()
	var start := (_level.get_node("ReinforcementSpawn") as Node3D).global_position
	var missing: PackedStringArray = []
	for spot: String in GUARD_SPOTS:
		if not _reaches(start, GUARD_SPOTS[spot]):
			missing.append(spot)
	assert_array(missing).is_empty()


func test_climbing_spots_stay_off_the_navmesh() -> void:
	await _load()
	var start := (_level.get_node("ReinforcementSpawn") as Node3D).global_position
	var reached: PackedStringArray = []
	for spot: String in PLAYER_ONLY:
		if _reaches(start, PLAYER_ONLY[spot]):
			reached.append(spot)
	assert_array(reached).is_empty()


func _reaches(from: Vector3, to: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(_map, from, to, true)
	return not path.is_empty() and path[-1].distance_to(to) < REACH


func _load() -> void:
	await GuardHelpers.let_old_scenes_go(get_tree())
	_level = auto_free(LEVEL.instantiate())
	_level.get_node("Mission").free()
	# The navmesh of the geometry: locked doors keep guards without the key out (their own suites:
	# warehouse_door_navigation_test).
	WarehouseHelpers.strip_population(_level)
	add_child(_level)
	await KitGeometry.settle(get_tree(), 3)
	var region := _level.get_node("Navigation") as LevelNavigation
	_map = region.get_navigation_map()
	await GuardHelpers.use_sync_iterations(_map, region)
	GuardHelpers.isolate_region(_map, region)
	# A region switched to synchronous iterations after its bake can lose that update: bake again.
	region.bake()
	assert_bool(await KitGeometry.wait_for_navigation(get_tree(), _map, Vector3(0, 0, 0))).is_true()
