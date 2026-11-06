extends RefCounted
## Test helper (not a suite): builds small stimulus entities in code for integration tests.


## A Node3D entity at `position` under `parent` with a Tags component, an Attributes component and a
## StimulusReceiver holding `receptrons`. Children are added before the entity enters the tree, so
## the receiver wires itself up in its _ready.
static func entity(
	parent: Node, entity_name: String, position: Vector3, receptrons: Array[Receptron], tags: Array[StringName] = []
) -> Node3D:
	return compose(Node3D.new(), parent, entity_name, position, receptrons, tags)


## Like entity(), but the root is a RigidBody3D on the objects layer (a `size` m box of `mass` kg,
## colliding with world and objects) so physics effects (ApplyImpulseEffect) and components that need
## a body (ImpactNoise, Carryable) work on it. `gravity_scale` 0 keeps it floating in place.
static func rigid_entity(
	parent: Node,
	entity_name: String,
	position: Vector3,
	receptrons: Array[Receptron],
	tags: Array[StringName] = [],
	size: float = 0.4,
	mass: float = 2.0,
	gravity_scale: float = 1.0,
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass
	body.gravity_scale = gravity_scale
	body.collision_layer = PhysicsLayers.OBJECTS
	body.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.OBJECTS
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = box
	body.add_child(collision)
	return compose(body, parent, entity_name, position, receptrons, tags) as RigidBody3D


## Gives `root` Tags, Attributes and a StimulusReceiver holding `receptrons`, then adds it under
## `parent` at `position`.
static func compose(
	root: Node3D,
	parent: Node,
	entity_name: String,
	position: Vector3,
	receptrons: Array[Receptron],
	tags: Array[StringName] = [],
) -> Node3D:
	root.name = entity_name
	root.position = position
	var tag_node := Tags.new()
	tag_node.name = "Tags"
	tag_node.initial_tags = tags
	root.add_child(tag_node)
	var attributes := Attributes.new()
	attributes.name = "Attributes"
	root.add_child(attributes)
	var receiver := StimulusReceiver.new()
	receiver.name = "StimulusReceiver"
	receiver.receptrons = receptrons
	root.add_child(receiver)
	parent.add_child(root)
	return root


static func receptron(type: StringName, effects: Array[Effect] = [], receptron_name: String = "") -> Receptron:
	var result := Receptron.new()
	result.stimulus_type = type
	result.effects = effects
	result.resource_name = receptron_name
	return result


static func add_tag(tag: StringName) -> AddTagEffect:
	var effect := AddTagEffect.new()
	effect.tag = tag
	return effect


static func emit_radius(
	type: StringName, radius: float, propagation: Stimulus.Propagation = Stimulus.Propagation.STRAIGHT
) -> EmitStimulusEffect:
	var effect := EmitStimulusEffect.new()
	effect.type = type
	effect.intensity = radius
	effect.radius = radius
	effect.propagation = propagation
	return effect


static func receiver_of(node: Node) -> StimulusReceiver:
	return node.get_node("StimulusReceiver") as StimulusReceiver


static func tags_of(node: Node) -> TagContainer:
	return (node.get_node("Tags") as Tags).container


## EventLog entries of `kind` whose data id is `id`.
static func entries(kind: StringName, id: int = -1) -> Array[EventLogEntry]:
	return EventLog.find(kind).filter(func(entry: EventLogEntry) -> bool: return id < 0 or entry.data["id"] == id)


## Waits `count` physics frames on `tree`.
static func frames(tree: SceneTree, count: int) -> void:
	for i in count:
		await tree.physics_frame
