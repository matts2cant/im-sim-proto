class_name Tags
extends Node
## Component: the entity's tags. Declare the starting tags in the inspector; systems read and
## change `container`. Saveable (group `saveable`). In group `tags` (GROUP), so a system can find
## the entities carrying a tag (perception looks for hostile tags this way).
## Found with Tags.of(entity): like Attributes, a core component with a fixed node name (NODE_NAME,
## conventions.md "Entities and components").

const GROUP: StringName = &"tags"
## The node name every entity gives its Tags (of() looks it up by name: it is read on hot paths).
const NODE_NAME: NodePath = ^"Tags"

@export var initial_tags: Array[StringName] = []

var container := TagContainer.new()


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	add_to_group(GROUP)
	for tag in initial_tags:
		container.add(tag)


## The Tags component of `entity` (its child named NODE_NAME), or null.
static func of(entity: Node) -> Tags:
	if entity == null or not is_instance_valid(entity):
		return null
	return entity.get_node_or_null(NODE_NAME) as Tags


## The Tags of `node` or of its nearest ancestor that has them (a prop's collider may be a child of
## the entity), or null.
static func above(node: Node) -> Tags:
	while node != null:
		var found := of(node)
		if found != null:
			return found
		node = node.get_parent()
	return null


func has(query: StringName) -> bool:
	return container.has(query)


func add(tag: StringName) -> bool:
	return container.add(tag)


func remove(tag: StringName) -> bool:
	return container.remove(tag)


func save_state() -> Dictionary:
	return container.to_dict()


func load_state(data: Dictionary) -> void:
	container.from_dict(data)
