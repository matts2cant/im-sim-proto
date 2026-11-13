extends RefCounted
## Test helper (not a suite): the network lab (gallery room 8) with the real Player in
## `fixtures/lab_player.tscn` (the room alone, its origin at ORIGIN, not turned: lab-local = world -
## ORIGIN; the hub's environment). Stands the player at a station, reads datapads, takes the deck
## from the entrance table, clicks (LMB) with the item in hand and opens computers bare-handed.
## Positions are lab-local (design/levels/hub-and-gallery.md "8 Network lab").

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const FIXTURE := "res://tests/levels/gallery/network_lab/fixtures/lab_player.tscn"
const ORIGIN := Vector3(-250, 0, -250)
## Stand spots (lab-local feet), 0.9 m or more in front of each station.
const AT_TABLE := Vector3(2.6, 0, -5.6)
const AT_JACK := Vector3(-0.9, 0, -6.0)
const AT_PC1 := Vector3(-0.6, 0, -8.5)
const AT_PC2 := Vector3(-0.6, 0, -12.0)
const AT_CONSOLE := Vector3(2.6, 0, -16.4)
const AT_BREAKER := Vector3(0.1, 0, -16.6)
const IN_CLOSET := Vector3(6.0, 0, -19.6)

var runner: GdUnitSceneRunner
var driver: PlayerDriver
var lab: Node3D
var player: Player


func setup(p_runner: GdUnitSceneRunner) -> void:
	runner = p_runner
	driver = PlayerDriver.new(runner)
	player = driver.player
	player.reload_on_reset = false
	lab = runner.find_child("NetworkLab") as Node3D
	await driver.settle()


func node(path: String) -> Node3D:
	return lab.get_node(path) as Node3D


func device(path: String) -> Device:
	return Device.of(node(path))


func computer(path: String) -> Computer:
	return Computer.of(node(path))


## The tracer on RTR-01.
func tracer() -> Tracer:
	return node("Devices/BayA/Rtr01").get_node("Tracer") as Tracer


## Puts the player at lab-local `feet` looking at lab-local `look`, at rest.
func stand(feet: Vector3, look: Vector3) -> void:
	player.load_state(Objects.aiming_state(player, ORIGIN + feet, ORIGIN + look))
	await driver.frames(3)


## E on a datapad (a path under Items/): reads it into the log; the reading overlay is closed.
func read(path: String) -> void:
	(node(path).get_node("Readable") as Readable).use(player)
	for overlay: Node in player.find_children("*", "ReadingOverlay", true, false):
		(overlay as ReadingOverlay).close()
	await driver.frames(1)


## Takes the deck from the entrance table and holds it (belt); false when it could not.
func take_deck() -> bool:
	await stand(AT_TABLE, node("Items/Deck").position)
	if not player.inventory.pick_up(ItemPickup.of(node("Items/Deck"))):
		return false
	player.inventory.hold(player.inventory.inventory.stacks_of(&"deck")[0])
	await driver.frames(2)
	return true


## Stands at `feet` aiming at the entity `path`, then holds LMB for 2 frames.
func click(feet: Vector3, path: String) -> void:
	player.load_state(Objects.aiming_state(player, ORIGIN + feet, node(path).global_position))
	await driver.frames(3)
	await driver.hold(&"fire", 2)
	await driver.frames(1)


## Physics frames for `seconds` of game time.
func seconds(value: float) -> void:
	await driver.frames(roundi(value * 60.0))
