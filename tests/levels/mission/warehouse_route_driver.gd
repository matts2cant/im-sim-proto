extends RefCounted
## Test helper (not a suite): drives the real player through the populated warehouse mission with
## its guards at work (design/levels/mission-warehouse.md "Targets": route scenario tests). Loads
## `fixtures/warehouse_player.tscn` (the level and a Player the Mission adopts at PlayerSpawn) with
## the navmesh baked once on a synchronous map, closes the briefing and seeds every random source
## (guards' awareness and combat, weapons, debris) so a run is deterministic.
## Moves steer by waypoints and wait on conditions (a guard past a crossing), not on frame counts:
## the view turns toward each point every physics frame while the movement keys are held. Every
## move returns false and adds a note when it does not get there in time; guard reactions
## (awareness changes) and the mission's events are noted too, for failure messages.
## Coordinates are warehouse (world) coordinates: x east, z south; yaw 0 faces north (-Z).

enum Stance { WALK, CROUCH, SPRINT }

const GuardHelpers := preload("res://tests/actors/guard/guard_helpers.gd")
const Hands := preload("res://tests/levels/mission/warehouse_route_hands.gd")
const FIXTURE := "res://tests/levels/mission/fixtures/warehouse_player.tscn"
const GUARDS := "Population/People/Guards"
const TIME_FACTOR := 9.0
const TICK := 1.0 / 60.0
## Horizontal distance (centre to centre) at which a waypoint counts as reached.
const REACH := 0.3
## Ground speed per stance (m/s, metrics.md), for move time budgets.
const SPEEDS: Array[float] = [4.0, 2.0, 6.0]
const NORTH := 0.0
const WEST := PI / 2.0
const SOUTH := PI
const EAST := -PI / 2.0

var runner: GdUnitSceneRunner
var level: Node3D
var player: Player
var mission: Mission
var map: RID
## What happened (failed moves, guard reactions, mission events), in order.
var notes: PackedStringArray = []
## Interactions (look, use, read, doors, weapons, carrying).
var hands: Hands

var _tree: SceneTree


## The fixture for a scene runner: the whole level with its population; the navmesh bake at load is
## skipped (setup() bakes once on a synchronous map).
static func fixture(suite: GdUnitTestSuite) -> Node3D:
	var scene: Node3D = suite.auto_free((load(FIXTURE) as PackedScene).instantiate())
	(scene.get_node("Navigation") as LevelNavigation).bake_on_ready = false
	return scene


## Loads the level in `p_runner`; with `saved` (a snapshot() of an earlier segment) the level
## continues from that state, restored the way the quicksave restores it (LevelSnapshot).
func setup(p_runner: GdUnitSceneRunner, saved: Dictionary = {}) -> void:
	runner = p_runner
	runner.set_time_factor(TIME_FACTOR)
	level = runner.scene()
	_tree = level.get_tree()
	player = level.get_node("Player") as Player
	player.reload_on_reset = false
	mission = level.get_node("Mission") as Mission
	hands = Hands.new(self)
	EventLog.entry_added.connect(_on_entry)
	if not saved.is_empty():
		_tree.paused = true
		StimulusSystem.reserve_ids(int(saved.get(QuickSave.STIMULUS_IDS, 0)))
		LevelSnapshot.apply(level, saved)
	var region := level.get_node("Navigation") as LevelNavigation
	map = region.get_navigation_map()
	await GuardHelpers.use_sync_iterations(map, region)
	GuardHelpers.isolate_region(map, region)
	region.bake()
	for i in 120:
		if NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid():
			break
		await _tree.physics_frame
	_seed()
	if mission.briefing.is_open():
		mission.briefing.close()
	_tree.paused = false
	await frames(3)


## The level's saveable state now (LevelSnapshot, as the quicksave captures it): the next segment
## starts from it (setup()).
func snapshot() -> Dictionary:
	var data := LevelSnapshot.capture(level)
	data[QuickSave.STIMULUS_IDS] = StimulusSystem.last_id()
	return data


func teardown() -> void:
	hands = null
	if EventLog.entry_added.is_connected(_on_entry):
		EventLog.entry_added.disconnect(_on_entry)
	for action: StringName in [&"move_forward", &"crouch", &"sprint", &"jump", &"use", &"fire"]:
		Input.action_release(action)
	if map.is_valid():
		NavigationServer3D.map_set_use_async_iterations(map, true)
	# The summary (a pause screen) is still open after an extraction.
	if _tree != null:
		PauseScreens.reset(_tree)
		_tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func frames(count: int) -> void:
	for i in count:
		await _tree.physics_frame


## Puts the player at rest at `feet` facing `yaw` (an arranged segment start), standing or crouched.
func place(feet: Vector3, yaw: float, crouched: bool = false) -> void:
	player.load_state({"position": feet, "yaw": yaw, "pitch": 0.0, "crouched": crouched, "velocity": Vector3.ZERO})
	if crouched:
		runner.simulate_action_press(&"crouch")
	await frames(4)
	if crouched:
		runner.simulate_action_release(&"crouch")


## Moves through `points` in order: each frame the view turns toward the next point (horizontally)
## and the movement keys for `stance` are held, until the feet are within REACH of it.
func go(points: Array[Vector3], stance: Stance = Stance.WALK) -> bool:
	for point in points:
		if not await _go_to(point, stance):
			return false
	return true


## Walks to `start` (within 0.12 m) and climb()s from there.
func climb_from(start: Vector3, yaw: float, top: float, hold: int = 6) -> bool:
	if not await _go_to(start, Stance.WALK, 0.0, 0.12):
		return false
	return await climb(yaw, top, hold)


## Mantles (or jumps) facing `yaw`: forward and jump held for `hold` frames, then forward only, until
## the feet stand still within 0.15 m of `top` (height) or `max_frames` pass.
func climb(yaw: float, top: float, hold: int = 6, max_frames: int = 120) -> bool:
	player.rotation.y = yaw
	runner.simulate_action_press(&"move_forward")
	runner.simulate_action_press(&"jump")
	await frames(hold)
	runner.simulate_action_release(&"jump")
	runner.simulate_action_release(&"move_forward")
	for i in max_frames:
		await _tree.physics_frame
		if not player.is_mantling() and player.is_on_floor() and absf(player.global_position.y - top) < 0.15:
			return true
	notes.append("climb to %.2f failed: feet at %s" % [top, player.global_position])
	return false


## Waits until `condition` (no arguments, returns bool) holds, at most `max_seconds` of game time.
func wait_until(condition: Callable, max_seconds: float, what: String) -> bool:
	for i in roundi(max_seconds / TICK):
		if condition.call():
			return true
		await _tree.physics_frame
	if condition.call():
		return true
	notes.append("waited %.0f s for %s at %s" % [max_seconds, what, player.global_position])
	return false


## The guard named `guard_name` (its layout name, e.g. "G2YardPatrolWest").
func guard(guard_name: String) -> NavWalker:
	return level.get_node(GUARDS + "/" + guard_name) as NavWalker


## Name of the patrol point guard `guard_name` walks to (or waits at); "" without a route.
func patrol_target(guard_name: String) -> String:
	var behaviour := guard(guard_name).get_node("Behaviour") as AwarenessBehaviour
	if behaviour.route == null:
		return ""
	var points := behaviour.route.points()
	return String(points[posmod(behaviour.patrol_index, points.size())].name)


## Waits until guard `guard_name` (holding a post) has glanced aside (to `side`: 1 its left, -1 its
## right, 0 either) and turned back to its post's facing: the next glance (to the other side) is
## then `glance_interval - glance_hold` (4.5 s) away.
func glance_over(guard_name: String, side: int = 0, max_seconds: float = 15.0) -> bool:
	var walker := guard(guard_name)
	var behaviour := walker.get_node("Behaviour") as AwarenessBehaviour
	var off_post := func() -> float:
		var facing := walker.facing()
		return wrapf(atan2(-facing.x, -facing.z) - behaviour.post_yaw, -PI, PI)
	var aside := func() -> bool:
		var angle: float = off_post.call()
		return absf(angle) > 0.3 and (side == 0 or signf(angle) == float(side))
	if not await wait_until(aside, max_seconds, guard_name + " to glance"):
		return false
	return await wait_until(func() -> bool: return absf(off_post.call()) < 0.05, 3.0, guard_name + " to turn back")


## True when the player stands in `guard_name`'s rear arc (120 degrees centred on its back): a
## baton hit there knocks an unaware guard out at once.
func behind(guard_name: String) -> bool:
	var walker := guard(guard_name)
	return StunRules.is_behind(walker.global_position, walker.facing(), player.global_position, 120.0)


## Horizontal distance from the player to the nearest guard that can act, among guards on about the
## same floor (within 3 m of height).
func nearest_guard() -> float:
	var best := INF
	for node in guards():
		var walker := node as Node3D
		if not ActorState.can_act(walker) or absf(walker.global_position.y - player.global_position.y) > 3.0:
			continue
		best = minf(best, _flat(walker.global_position - player.global_position).length())
	return best


## Moves through `points` walking while every guard on the floor is at least `quiet_distance` away,
## crouching (quiet) while one is nearer.
func sneak(points: Array[Vector3], quiet_distance: float = 10.0) -> bool:
	for point in points:
		if not await _go_to(point, Stance.WALK, quiet_distance):
			return false
	return true


## Walks to `zone_point` (inside the Extraction zone) until the mission finishes; true when it did.
func extract(zone_point: Vector3) -> bool:
	runner.simulate_action_press(&"move_forward")
	for i in roundi(10.0 / TICK):
		if mission.finished:
			break
		var to := _flat(zone_point - player.global_position)
		if to.length() > REACH:
			player.rotation.y = atan2(-to.x, -to.y)
		await _tree.physics_frame
	runner.simulate_action_release(&"move_forward")
	if not mission.finished:
		notes.append("no extraction at %s" % player.global_position)
	return mission.finished


## Starts a segment that continues an earlier one: `saved` is its snapshot(); fails the test
## (a note) when it is missing (the segments of a route run in order in one suite).
func resume(p_runner: GdUnitSceneRunner, saved: Dictionary) -> bool:
	if saved.is_empty():
		notes.append("no saved state: this segment continues the previous test of its suite")
		return false
	await setup(p_runner, saved)
	return true


## Guard reactions and mission events noted so far, one per line.
func report() -> String:
	return "\n".join(notes)


# Steers to `point`; with `quiet_distance` > 0 crouches while a guard is nearer than that.
func _go_to(point: Vector3, stance: Stance, quiet_distance: float = 0.0, reach: float = REACH) -> bool:
	var actions: Array[StringName] = [&"move_forward"]
	if stance == Stance.CROUCH:
		actions.append(&"crouch")
	elif stance == Stance.SPRINT:
		actions.append(&"sprint")
	var distance := _flat(point - player.global_position).length()
	var slowest := SPEEDS[Stance.CROUCH] if quiet_distance > 0.0 else SPEEDS[stance]
	var budget := roundi((distance / slowest * 2.0 + 2.0) / TICK)
	for action in actions:
		runner.simulate_action_press(action)
	var reached := false
	var quiet := false
	for i in budget:
		var to := _flat(point - player.global_position)
		if to.length() < reach:
			reached = true
			break
		player.rotation.y = atan2(-to.x, -to.y)
		if quiet_distance > 0.0 and (i % 6 == 0):
			var wants := nearest_guard() < quiet_distance
			if wants != quiet:
				quiet = wants
				if quiet:
					runner.simulate_action_press(&"crouch")
				else:
					runner.simulate_action_release(&"crouch")
		await _tree.physics_frame
	for action in actions:
		runner.simulate_action_release(action)
	if quiet:
		runner.simulate_action_release(&"crouch")
	if not reached:
		notes.append("did not reach %s: feet at %s" % [point, player.global_position])
	return reached


## Every guard of the level, reinforcements included.
func guards() -> Array[Node]:
	var result: Array[Node] = level.get_node(GUARDS).get_children()
	result.append_array(mission.reinforcements.get_children())
	return result


func _seed() -> void:
	seed(9)
	var index := 0
	for node in guards():
		index += 1
		var awareness := GradedAwareness.of_node(node)
		if awareness != null:
			awareness.model.rng.seed = 100 + index
		var combat := CombatBehaviour.of(node)
		if combat != null:
			combat.model.rng.seed = 200 + index
			combat.holder.seed_rng(300 + index)
	player.weapons.seed_rng(7)


func _on_entry(entry: EventLogEntry) -> void:
	if entry.kind == &"mission.reinforcements":
		_seed.call_deferred()
	var line := ""
	match entry.kind:
		&"actor.awareness":
			line = (
				"%s %s -> %s (%s)"
				% [
					entry.data.get("actor", entry.source),
					entry.data.get("from", ""),
					entry.data.get("to", ""),
					entry.data.get("reason", ""),
				]
			)
		&"alarm.raised", &"actor.body_found", &"actor.knocked_out", &"actor.died", &"mission.reinforcements":
			line = "%s %s -> %s %s" % [entry.kind, entry.source, entry.target, entry.data]
		&"mission.objective_completed", &"mission.completed", &"mission.extraction_refused":
			line = "%s %s" % [entry.kind, entry.data]
	if not line.is_empty():
		notes.append("%.1f s: %s (player at %s)" % [mission.time, line, _rounded(player.global_position)])


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _rounded(v: Vector3) -> Vector3:
	return Vector3(snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1))
