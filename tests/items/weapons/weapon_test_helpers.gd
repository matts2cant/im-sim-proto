extends RefCounted
## Test helper (not a suite): gives the player of a PlayerDriver the pistol (belt 1), the baton
## (belt 2) and 30 rounds, aims it at a point, equips weapons through the belt keys and fires through
## the `fire` action, for the M4 weapon, dummy and HUD tests. The player's passive Combat Strength is
## uninstalled so the M4 numbers (baton stun 20, blunt 5) hold; skills start Untrained.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
const Items := preload("res://tests/items/item_test_helpers.gd")
const DUMMY_RANGE := "res://tests/actors/dummy/fixtures/dummy_range.tscn"
const SEED := 4242

var driver: PlayerDriver
var player: Player


func _init(p_driver: PlayerDriver) -> void:
	driver = p_driver
	player = driver.player
	player.weapons.seed_rng(SEED)
	player.augmentations.set_installed(&"combat_strength", false)
	Items.arm(player)


## Stands the player at `feet` aiming its eye at `target`, lets it land and clears the log. The
## teleport counts as one airborne frame, so the aim cone is settled to its floor afterwards.
func aim_at(feet: Vector3, target: Vector3) -> void:
	player.load_state(Objects.aiming_state(player, feet, target))
	await driver.frames(5)
	player.weapons.settle()
	EventLog.clear()


## belt_1 = pistol, belt_2 = baton (one frame released afterwards, so the next press is an edge).
func equip(slot: int) -> void:
	await driver.hold(StringName("belt_%d" % slot), 2)
	await driver.frames(1)


## Presses and releases `fire`, then waits for the stimuli to be delivered.
func fire(wait: int = 4) -> void:
	await driver.hold(&"fire", 2)
	await driver.frames(wait)


## The world position of `dummy`'s hitbox for `part`.
static func part_position(dummy: TrainingDummy, part: StringName) -> Vector3:
	return dummy.hitboxes.box(part).global_position


static func damaged(part: StringName) -> Array[EventLogEntry]:
	return Objects.logged(&"actor.damaged", "part", part)
