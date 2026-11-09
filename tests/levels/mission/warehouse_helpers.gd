extends RefCounted
## Test helper (not a suite): loads the warehouse mission with a player for traversal tests and
## plays moves. Fixture: `fixtures/warehouse_player.tscn` (the level plus a Player, so the Mission
## adopts it); the mission briefing is closed so the game runs. Coordinates are warehouse (world)
## coordinates: x east, z south, origin at the compound centre; yaw 0 faces north (-Z).

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const FIXTURE := "res://tests/levels/mission/fixtures/warehouse_player.tscn"
const LEVEL := "res://levels/mission/warehouse.tscn"
const NORTH := 0.0
const WEST := PI / 2.0
const SOUTH := PI
const EAST := -PI / 2.0

var driver: PlayerDriver
var player: Player
var level: Node


## Loads the fixture in `runner`, closes the briefing and lets CSG build its collision.
func setup(runner: GdUnitSceneRunner) -> void:
	driver = PlayerDriver.new(runner)
	player = driver.player
	player.reload_on_reset = false
	level = runner.scene()
	await driver.frames(3)
	var mission := level.get_node("Mission") as Mission
	if mission.briefing.is_open():
		mission.briefing.close()
	await driver.frames(5)


## Opens every door of the level at once (routes through doorways, not the locks: those have their
## own suites).
func open_every_door() -> void:
	for node in level.get_tree().get_nodes_in_group(Door.GROUP):
		var door := node as Door
		if level.is_ancestor_of(door):
			door.load_state({"open": true})


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
