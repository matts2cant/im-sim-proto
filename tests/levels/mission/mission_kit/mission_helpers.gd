extends RefCounted
## Test helper (not a suite): the mission fixture (`fixtures/mission_fixture.tscn`, root at
## (-300, 0, 600): floor, PlayerSpawn (0, 0, 10) facing -Z, the manifest datapad (2, 0, 6), a keycard
## (-2, 0, 6), a crate tagged `mission.shipment` (6, 0, 0), an alarm controller, Extraction at
## (0, 0, -12) (4 x 3 x 4 m), ReinforcementSpawn (12, 0, 12), a Mission with
## `fixtures/mission_fixture.tres` and LevelNavigation) opened as the current scene, and shortcuts.

const Wait := preload("res://tests/helpers/wait.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const FIXTURE := "res://tests/levels/mission/mission_kit/fixtures/mission_fixture.tscn"
const HUB := "res://levels/hub/hub.tscn"
const ORIGIN := Vector3(-300, 0, 600)


## Opens the fixture as the current scene (the briefing opens at once).
static func open(tree: SceneTree) -> Node3D:
	return await Saves.open_level(tree, FIXTURE) as Node3D


static func mission(level: Node) -> Mission:
	return level.get_node("Mission") as Mission


static func player(level: Node) -> Player:
	return level.get_node("Player") as Player


## Fixture-local point -> world.
static func at(local: Vector3) -> Vector3:
	return ORIGIN + local


## Puts the player at fixture-local `local` facing `yaw`, at rest.
static func place(level: Node, local: Vector3, yaw: float = 0.0) -> void:
	player(level).load_state({"position": at(local), "yaw": yaw, "pitch": 0.0, "velocity": Vector3.ZERO})


## Closes the briefing with Esc (as the player would).
static func close_briefing(level: Node) -> void:
	Saves.press(KEY_ESCAPE)
	await Wait.frames(level.get_tree(), 2)


## Reads the manifest datapad in place and closes the reading overlay.
static func read_manifest(level: Node) -> void:
	var readable := level.get_node("Manifest/Readable") as Readable
	readable.use(player(level))
	(player(level).get_node("ReadingOverlay") as ReadingOverlay).close()


## Waits until the current scene is no longer `old` (a level change); returns the new one or null.
static func wait_for_scene_change(tree: SceneTree, old: Node, max_frames: int = 60) -> Node:
	for i in max_frames:
		await tree.process_frame
		if tree.current_scene != old and tree.current_scene != null and tree.current_scene.is_node_ready():
			return tree.current_scene
	return null


## Item id -> count over the player's inventory stacks.
static func inventory_counts(level: Node) -> Dictionary:
	var counts := {}
	for stack in player(level).inventory.grid.stacks:
		var id := String(stack.item.id)
		counts[id] = int(counts.get(id, 0)) + stack.count
	return counts
