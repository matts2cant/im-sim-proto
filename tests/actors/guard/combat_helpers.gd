extends RefCounted
## Test helper (not a suite): loads the combat yard (tests/scenarios/fixtures/combat_yard.tscn: a
## 30 x 30 m lit floor, a 12 m cover wall across x -6..6 at z -12 (0.4 m thick, 3 m high),
## LevelNavigation) in a scene runner with synchronous navigation, adds an armed guard named "Guard"
## (guard_pistol.tscn or guard_baton.tscn) with seeded generators, and builds stand-in targets:
## minimal characters (character_fixtures.gd) with Hitboxes and a tag (`actor.player` is hostile to
## guards, `actor.guard` an ally). The rules under test are about tags and components.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const HITBOXES := preload("res://actors/common/body/hitboxes.tscn")
const YARD := "res://tests/scenarios/fixtures/combat_yard.tscn"
const YARD_WITH_PLAYER := "res://tests/scenarios/fixtures/combat_yard_player.tscn"
const PISTOL_GUARD := "res://actors/guard/guard_pistol.tscn"
const BATON_GUARD := "res://actors/guard/guard_baton.tscn"
const TIME_FACTOR := 9.0
const TICK := 1.0 / 60.0

var runner: GdUnitSceneRunner
var scene: Node
var guard: NavWalker
var awareness: GradedAwareness
var combat: CombatBehaviour
var holder: WeaponHolder

var _map_was_async: bool = true


## Loads the yard with `p_runner`, adds `guard_scene` at the origin facing -Z (holding its post).
func setup(p_runner: GdUnitSceneRunner, guard_scene: String) -> void:
	runner = p_runner
	runner.set_time_factor(TIME_FACTOR)
	scene = runner.scene()
	guard = (load(guard_scene) as PackedScene).instantiate() as NavWalker
	guard.name = "Guard"
	scene.add_child(guard)
	awareness = GradedAwareness.of_node(guard)
	combat = CombatBehaviour.of(guard)
	holder = combat.holder
	holder.seed_rng(7)
	combat.model.rng.seed = 11
	var map := guard.get_world_3d().navigation_map
	_map_was_async = NavigationServer3D.map_get_use_async_iterations(map)
	NavigationServer3D.map_set_use_async_iterations(map, false)
	var region := scene.find_child("LevelNavigation", true, false) as LevelNavigation
	NavigationServer3D.region_set_use_async_iterations(region.get_rid(), false)
	region.bake()
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


## A standing character at `feet` facing `yaw` (0: -Z) with Hitboxes, BodyParts (dummy profile) and
## the tag `tag`, on `layer` (the player's by default).
func figure(
	figure_name: String, feet: Vector3, tag: StringName, yaw: float = 0.0, layer: int = PhysicsLayers.PLAYER
) -> CharacterBody3D:
	var body := Characters.character(scene, figure_name, feet, [] as Array[StringName], layer)
	body.rotation.y = yaw
	body.add_child(HITBOXES.instantiate())
	Characters.tags_of(body).add(tag)
	return body


## A hostile stand-in (tag `actor.player`).
func intruder(feet: Vector3, yaw: float = PI) -> CharacterBody3D:
	return figure("Intruder", feet, &"actor.player", yaw)


## An ally stand-in (tag `actor.guard`, actors layer).
func ally(feet: Vector3, yaw: float = 0.0) -> CharacterBody3D:
	return figure("Ally", feet, &"actor.guard", yaw, PhysicsLayers.ACTORS)


## Waits up to `limit` seconds for an EventLog entry of `kind` from the guard; returns it or null.
func wait_for(kind: StringName, limit: float) -> EventLogEntry:
	for tick in roundi(limit * 60.0):
		var found := guard_entries(kind)
		if not found.is_empty():
			return found[0]
		await frames(1)
	var last := guard_entries(kind)
	return last[0] if not last.is_empty() else null


## EventLog entries of `kind` whose source is the guard.
static func guard_entries(kind: StringName) -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(func(entry: EventLogEntry) -> bool: return entry.source == "Guard")


## The `to` states of the guard's awareness changes, in order.
static func states() -> Array[String]:
	var result: Array[String] = []
	for entry in guard_entries(&"actor.awareness"):
		result.append(String(entry.data["to"]))
	return result


## Total health of all six parts of `body`.
static func total_health(body: Node) -> float:
	var parts := BodyParts.of(body)
	var total := 0.0
	for part in BodyDamageModel.PARTS:
		total += parts.health(part)
	return total
