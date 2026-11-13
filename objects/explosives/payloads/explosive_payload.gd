class_name ExplosivePayload
extends Node3D
## Component (ADR 0131, M14b): what an explosive entity (a grenade: an Explosive and a Breakable)
## releases when it goes off. One scene per grenade type (`objects/explosives/payloads/*_payload.tscn`),
## instanced as a child of the entity, beside its Explosive:
## - `config` is the blast (damage, push, noise, fire, flash): the Explosive uses it (taken in
##   Explosive._ready() when its own config is empty; set with Explosive.use_config() here when the
##   payload is ready later).
## - On Explosive.exploded (emitted before the entity is freed), whatever set it off (a fuse, a
##   proximity trigger, a shot, a blast chain), it emits `released(origin, cause)` for its effect
##   components (EmpPulse) and spawns `lasting` (a GasCloud, a JammingField) in the level at the blast
##   centre: under the level root (level_of()), never under the entity, which is removed, nor under
##   what it was stuck to.
## EventLog: `payload.released {entity, lasting}`.

## The blast went off at `origin`; `cause` set it off (null: none).
signal released(origin: Vector3, cause: Stimulus)

const GROUP: StringName = &"explosive_payload"

## The blast (Explosive's config).
@export var config: ExplosiveConfig
## Spawned in the level at the blast centre when it goes off (null: nothing lasts).
@export var lasting: PackedScene
@export var entity_path: NodePath = ^".."

var entity: Node3D
var explosive: Explosive


func _ready() -> void:
	add_to_group(GROUP)
	entity = get_node_or_null(entity_path) as Node3D
	explosive = Explosive.of(entity) if entity != null else null
	if explosive == null:
		push_warning("ExplosivePayload %s: its entity has no Explosive" % get_path())
		return
	if config != null and explosive.config != config:
		explosive.use_config(config)
	explosive.exploded.connect(_on_exploded)


## The ExplosivePayload child of `node`, or null.
static func of(node: Node) -> ExplosivePayload:
	if node == null:
		return null
	for child in node.get_children():
		if child is ExplosivePayload:
			return child as ExplosivePayload
	return null


## The level `node` is in: the current scene when it holds `node`, else its topmost ancestor below
## the tree root (a test fixture).
static func level_of(node: Node) -> Node:
	var tree := node.get_tree()
	var scene := tree.current_scene if tree != null else null
	if scene != null and scene.is_ancestor_of(node):
		return scene
	var top := node
	while top.get_parent() != null and top.get_parent() != tree.root:
		top = top.get_parent()
	return top


## Instances `scene` under the level of `near` (level_of()) with its centre at `origin`; returns it.
static func spawn_in_level(scene: PackedScene, near: Node, origin: Vector3) -> Node3D:
	var level := level_of(near)
	var node := scene.instantiate() as Node3D
	if level is Node3D:
		node.position = (level as Node3D).global_transform.affine_inverse() * origin
	else:
		node.position = origin
	level.add_child(node, true)
	return node


func _on_exploded() -> void:
	var origin := explosive.global_position
	released.emit(origin, explosive.trigger)
	var spawned := ""
	if lasting != null:
		spawned = String(ExplosivePayload.spawn_in_level(lasting, self, origin).name)
	var entity_name := String(entity.name) if is_instance_valid(entity) else ""
	EventLog.record(EventKinds.PAYLOAD_RELEASED, entity_name, spawned, {"entity": entity_name, "lasting": spawned})
