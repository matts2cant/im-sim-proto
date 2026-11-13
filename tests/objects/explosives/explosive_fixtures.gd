extends RefCounted
## Test helper (not a suite): grenade stand-ins built from components (ADR 0131, M14b): a Node3D
## entity with Tags, Attributes (health), a StimulusReceiver taking damage and heat, a Breakable that
## leaves the explosion to its Explosive, an Explosive without a config of its own and a payload
## scene (objects/explosives/payloads/) as a child: what m14a's grenade entities compose. Tests set
## them off with Explosive.explode(), as a fuse, a mine or a shot would.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const FRAG: PackedScene = preload("res://objects/explosives/payloads/frag_payload.tscn")
const GAS: PackedScene = preload("res://objects/explosives/payloads/gas_payload.tscn")
const EMP: PackedScene = preload("res://objects/explosives/payloads/emp_payload.tscn")
const JAMMING: PackedScene = preload("res://objects/explosives/payloads/jamming_payload.tscn")
const TAKE_DAMAGE: Receptron = preload("res://objects/components/receptrons/take_damage.tres")
const HEAT_FROM_FIRE: Receptron = preload("res://objects/components/receptrons/heat_from_fire.tres")
const METAL: MaterialProfile = preload("res://objects/materials/metal.tres")
const HEALTH: float = 10.0


## A grenade stand-in named `entity_name` at `position` under `parent` carrying `payload`;
## `payload_first`: the payload comes before the Explosive among the children (both orders work).
static func grenade(
	parent: Node, entity_name: String, position: Vector3, payload: PackedScene, payload_first: bool = false
) -> Node3D:
	var root := Node3D.new()
	var breakable := Breakable.new()
	breakable.name = "Breakable"
	breakable.material = METAL
	breakable.break_on_depleted = false
	var explosive := Explosive.new()
	explosive.name = "Explosive"
	var part := payload.instantiate()
	if payload_first:
		root.add_child(part)
	root.add_child(breakable)
	root.add_child(explosive)
	if not payload_first:
		root.add_child(part)
	var receptrons: Array[Receptron] = [TAKE_DAMAGE, HEAT_FROM_FIRE]
	var entity := Fixtures.compose(root, parent, entity_name, position, receptrons, [&"object.explosive"])
	(entity.get_node("Attributes") as Attributes).attribute_set.set_base(Breakable.HEALTH, HEALTH)
	return entity


static func explosive_of(entity: Node) -> Explosive:
	return Explosive.of(entity)


## Frees every gas cloud and jamming field left in `tree` (they spawn in the level, not under the
## fixture).
static func clear_effects(tree: SceneTree) -> void:
	for group: StringName in [GasCloud.GROUP, JammingField.GROUP]:
		for node in tree.get_nodes_in_group(group):
			if node is JammingField:
				(node as JammingField).end()
			node.free()


## The first node of `group` in `tree`, or null.
static func first(tree: SceneTree, group: StringName) -> Node3D:
	return tree.get_first_node_in_group(group) as Node3D


## Runs game time `factor` times faster with the physics delta kept at 1/60 s (as a scene runner's
## set_time_factor()); returns the settings to give restore_time().
static func speed_up(factor: float) -> Vector2:
	var saved := Vector2(Engine.time_scale, Engine.physics_ticks_per_second)
	Engine.physics_ticks_per_second = roundi(60.0 * factor)
	Engine.time_scale = factor
	return saved


static func restore_time(saved: Vector2) -> void:
	Engine.time_scale = saved.x
	Engine.physics_ticks_per_second = roundi(saved.y)


## Waits `seconds` of game time (physics frames of 1/60 s).
static func seconds(tree: SceneTree, value: float) -> void:
	for i in roundi(value * 60.0):
		await tree.physics_frame


## A static wall (world layer) of `size` centred at `centre` under `parent`.
static func wall(parent: Node, centre: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Wall"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	parent.add_child(body)
	return body
