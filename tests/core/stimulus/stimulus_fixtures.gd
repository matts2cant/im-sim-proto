extends RefCounted
## Test helper (not a suite): builds small stimulus entities in code for integration tests.


## A Node3D entity at `position` under `parent` with a Tags component, an Attributes component and a
## StimulusReceiver holding `receptrons`. Children are added before the entity enters the tree, so
## the receiver wires itself up in its _ready.
static func entity(
	parent: Node, entity_name: String, position: Vector3, receptrons: Array[Receptron], tags: Array[StringName] = []
) -> Node3D:
	var root := Node3D.new()
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
