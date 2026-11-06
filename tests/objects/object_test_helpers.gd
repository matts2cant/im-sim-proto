extends RefCounted
## Test helper (not a suite): object scenes, aiming the player and EventLog lookups for the M3
## object, carry and fire tests.

const SMALL_CRATE := "res://objects/small_crate/small_crate.tscn"
const LARGE_CRATE := "res://objects/large_crate/large_crate.tscn"
const METAL_CRATE := "res://objects/metal_crate/metal_crate.tscn"
const CARDBOARD_BOX := "res://objects/cardboard_box/cardboard_box.tscn"
const EXPLOSIVE_BARREL := "res://objects/explosive_barrel/explosive_barrel.tscn"
const GLASS_BOTTLE := "res://objects/glass_bottle/glass_bottle.tscn"
const WOODEN_BARRICADE := "res://objects/wooden_barricade/wooden_barricade.tscn"
const BRAZIER := "res://objects/brazier/brazier.tscn"


## Instances `path` under `parent` at `position` (name kept readable: SmallCrate2 for a second one).
static func spawn(parent: Node, path: String, position: Vector3, node_name: String = "") -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	if not node_name.is_empty():
		node.name = node_name
	parent.add_child(node, true)
	node.global_position = position
	return node


## Player state standing at `feet` looking at `target` (yaw and pitch from the standing eye).
static func aiming_state(player: Player, feet: Vector3, target: Vector3) -> Dictionary:
	var eye := feet + Vector3.UP * player.config.standing_eye_height
	var to := target - eye
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	return {"position": feet, "yaw": yaw, "pitch": pitch, "crouched": false, "velocity": Vector3.ZERO}


## EventLog entries of `kind` whose data `key` equals `value` (any when key is empty).
static func logged(kind: StringName, key: String = "", value: Variant = null) -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(
		func(entry: EventLogEntry) -> bool: return key.is_empty() or entry.data.get(key) == value
	)


## The `stimulus.emitted` entry of stimulus `id`, or null.
static func emitted(id: int) -> EventLogEntry:
	for entry in EventLog.find(&"stimulus.emitted"):
		if entry.data["id"] == id:
			return entry
	return null


static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame
