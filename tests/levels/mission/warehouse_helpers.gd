extends RefCounted
## Test helper (not a suite): loads the warehouse mission with a player for traversal tests and
## plays moves. Fixture: `fixtures/warehouse_player.tscn` (the level plus a Player, so the Mission
## adopts it); the mission briefing is closed so the game runs. Coordinates are warehouse (world)
## coordinates: x east, z south, origin at the compound centre; yaw 0 faces north (-Z).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const KitGeometry := preload("res://tests/levels/kit/kit_geometry.gd")
const LEVEL_SCENE: PackedScene = preload("res://levels/mission/warehouse.tscn")
const FIXTURE := "res://tests/levels/mission/fixtures/warehouse_player.tscn"
const LEVEL := "res://levels/mission/warehouse.tscn"
const NORTH := 0.0
const WEST := PI / 2.0
const SOUTH := PI
const EAST := -PI / 2.0

var driver: PlayerDriver
var player: Player
var level: Node


## Loads the fixture in `runner`, closes the briefing and lets CSG build its collision. Traversal
## tests drive the layout: wave 2's population (guards who would stop the player, doors) is removed.
func setup(runner: GdUnitSceneRunner) -> void:
	driver = PlayerDriver.new(runner)
	player = driver.player
	player.reload_on_reset = false
	level = runner.scene()
	strip_population(level)
	await driver.frames(3)
	var mission := level.get_node("Mission") as Mission
	if mission.briefing.is_open():
		mission.briefing.close()
	await driver.frames(5)


## The player fixture (the level and a Player) for a scene runner, without the navmesh bake at load
## (nobody walks a path in the tests that use it); with `strip` the wave 2 population is removed
## before it loads (setup() would remove it after: its guards and props would load for nothing).
static func fixture(suite: GdUnitTestSuite, strip: bool = true) -> Node3D:
	var level: Node3D = suite.auto_free((load(FIXTURE) as PackedScene).instantiate())
	(level.get_node("Navigation") as LevelNavigation).bake_on_ready = false
	if strip:
		strip_population(level)
	return level


## Loads the warehouse under `suite` for queries (no Mission: no player spawns, no briefing pauses
## it) and lets CSG build its collision. Without `population` the wave 2 population is removed (the
## layout only). The level's own navmesh bake at load is skipped; with `navigation` the navmesh is
## baked once on a synchronous map isolated from other suites' regions (restore the map's
## asynchronous iterations in `after()`: `navigation_map()`). Suites whose tests only query the
## level call this once from `before()` (design/tech/testing.md "Writing fast tests").
static func load_for_queries(suite: GdUnitTestSuite, population: bool, navigation: bool) -> Node3D:
	await GuardHelpers.let_old_scenes_go(suite.get_tree())
	var level: Node3D = suite.auto_free(LEVEL_SCENE.instantiate())
	level.get_node("Mission").free()
	if not population:
		strip_population(level)
	var region := level.get_node("Navigation") as LevelNavigation
	region.bake_on_ready = false
	suite.add_child(level)
	await KitGeometry.settle(suite.get_tree(), 5)
	if navigation:
		var map := region.get_navigation_map()
		await GuardHelpers.use_sync_iterations(map, region)
		GuardHelpers.isolate_region(map, region)
		region.bake()
		# Wait for the map to hold the region's polygons (a map without any answers closest-point
		# queries with the origin, so a probe at the origin proves nothing).
		for i in 120:
			if NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid():
				break
			await suite.get_tree().physics_frame
		suite.assert_bool(NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()).is_true()
	return level


## The navigation map of a level loaded by load_for_queries().
static func navigation_map(level: Node3D) -> RID:
	return (level.get_node("Navigation") as LevelNavigation).get_navigation_map()


## Removes the level's `Population` (wave 2: guards, doors, devices, props) so a test sees the
## layout only.
static func strip_population(level: Node) -> void:
	var population := level.get_node_or_null("Population")
	if population != null:
		population.free()


## Places the player at rest (standing) and plays `steps`: each step holds its actions
## (input action names) together for `frames` physics frames.
func play(feet: Vector3, yaw: float, steps: Array[Dictionary]) -> void:
	await driver.place(feet, yaw)
	await moves(steps)


## Turns the player to `yaw` where it stands, crouched (e.g. at a duct corner), and plays `steps`.
func turn_and_play(yaw: float, steps: Array[Dictionary]) -> void:
	player.load_state(
		{"position": player.global_position, "yaw": yaw, "pitch": 0.0, "crouched": true, "velocity": Vector3.ZERO}
	)
	await driver.frames(2)
	await moves(steps)


func moves(steps: Array[Dictionary]) -> void:
	for step: Dictionary in steps:
		var actions: Array = step.get("hold", [])
		for action: StringName in actions:
			driver.runner.simulate_action_press(action)
		await driver.frames(int(step["frames"]))
		for action: StringName in actions:
			driver.runner.simulate_action_release(action)
	await driver.frames(2)


## Leg health (both legs) of the player's body: fall damage lands there.
func leg_health() -> float:
	var parts := player.get_node("BodyParts") as BodyParts
	return parts.health(&"leg_l") + parts.health(&"leg_r")


static func mantle(frames: int = 50) -> Dictionary:
	return {"hold": [&"move_forward", &"jump"], "frames": frames}


static func walk(frames: int) -> Dictionary:
	return {"hold": [&"move_forward"], "frames": frames}


static func crawl(frames: int) -> Dictionary:
	return {"hold": [&"move_forward", &"crouch"], "frames": frames}


static func wait(frames: int) -> Dictionary:
	return {"hold": [], "frames": frames}
