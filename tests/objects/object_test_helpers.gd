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


## Component builders for entities composed in code (StimulusFixtures.entity / rigid_entity): the
## generality tests put shipping components on entities that are not the shipping props.


## Small, fast fire tuning: ignites at `threshold`, burns `fuel` seconds (pulses of 2.0 / 1.5 m).
static func fire_config(threshold: float = 3.0, fuel: float = 1.0) -> FlammableConfig:
	var config := FlammableConfig.new()
	config.ignition_threshold = threshold
	config.cool_rate = 0.5
	config.fuel_seconds = fuel
	config.intensity = 2.0
	config.radius = 1.5
	config.pulse_interval = 0.5
	config.noise_loudness = 4.0
	config.light_range_factor = 3.0
	config.light_energy = 1.0
	config.light_flicker = 0.1
	config.flame_size = 0.2
	return config


## A small blast: heat trigger at `threshold`; `force.blast` of `impulse` N s over 3 m.
static func explosive_config(threshold: float = 3.0, impulse: float = 30.0) -> ExplosiveConfig:
	var config := ExplosiveConfig.new()
	config.heat_threshold = threshold
	config.cool_rate = 0.5
	config.damage_intensity = 40.0
	config.damage_radius = 3.0
	config.fire_intensity = 10.0
	config.fire_radius = 2.0
	config.noise_loudness = 20.0
	config.impulse = impulse
	config.impulse_radius = 3.0
	config.light_range = 4.0
	config.light_energy = 1.0
	return config


## Adds a Flammable with `config` to `entity` (which needs Tags and the heat_from_fire receptron).
static func add_flammable(entity: Node3D, config: FlammableConfig) -> Flammable:
	var flammable := Flammable.new()
	flammable.name = "Flammable"
	flammable.config = config
	entity.add_child(flammable)
	return flammable


## Adds an Explosive with `config` to `entity`. Add any Breakable first: it hooks its `depleted`.
static func add_explosive(entity: Node3D, config: ExplosiveConfig) -> Explosive:
	var explosive := Explosive.new()
	explosive.name = "Explosive"
	explosive.config = config
	entity.add_child(explosive)
	return explosive


## Adds a Breakable (wood, shared break settings) to `entity` with `health` in its Attributes.
static func add_breakable(entity: Node3D, health: float, break_on_depleted: bool = true) -> Breakable:
	(entity.get_node("Attributes") as Attributes).attribute_set.set_base(Breakable.HEALTH, health)
	var breakable := Breakable.new()
	breakable.name = "Breakable"
	breakable.material = load("res://objects/materials/wood.tres") as MaterialProfile
	breakable.settings = load("res://objects/components/break_settings.tres") as BreakSettings
	breakable.break_on_depleted = break_on_depleted
	breakable.size = 0.4
	entity.add_child(breakable)
	return breakable
