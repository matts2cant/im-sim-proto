extends RefCounted
## Test helper (not a suite): the M5 item resources, giving the player its M4 weapons, and world
## pickups for the inventory, pickup and inventory screen tests.

const PISTOL: ItemData = preload("res://items/weapons/pistol/pistol_item.tres")
const BATON: ItemData = preload("res://items/weapons/baton/baton_item.tres")
const AMMO: ItemData = preload("res://items/pistol_ammo/pistol_ammo.tres")
const MEDKIT: ItemData = preload("res://items/medkit/medkit.tres")
const MULTITOOL: ItemData = preload("res://items/multitool/multitool.tres")
const LOCKPICK: ItemData = preload("res://items/lockpick/lockpick.tres")
const BIOCELL: ItemData = preload("res://items/biocell/biocell.tres")
const KEYCARD: ItemData = preload("res://items/keycard/keycard.tres")
const DATAPAD: ItemData = preload("res://items/datapad/datapad.tres")


## Pistol (belt 1), baton (belt 2) and 30 pistol rounds: the M4 loadout the weapon tests expect.
static func arm(player: Player) -> void:
	player.inventory.give(PISTOL, 1)
	player.inventory.give(BATON, 1)
	player.inventory.give(AMMO, 30)


## Instances `item`'s world scene under `parent` at `position` with `count` and state overrides.
static func spawn_pickup(
	parent: Node, item: ItemData, position: Vector3, count: int = 1, state: Dictionary = {}
) -> RigidBody3D:
	var body := (load(item.world_scene) as PackedScene).instantiate() as RigidBody3D
	var pickup := ItemPickup.of(body)
	pickup.count = count
	pickup.state = state
	parent.add_child(body, true)
	body.global_position = position
	return body


## A bare item resource for unit tests: `id`, footprint, stack size.
static func make_item(id: StringName, footprint: Vector2i, max_stack: int = 1, state: Dictionary = {}) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.short_name = String(id).to_upper()
	item.footprint = footprint
	item.max_stack = max_stack
	item.default_state = state
	return item
