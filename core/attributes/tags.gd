class_name Tags
extends Node
## Component: the entity's tags. Declare the starting tags in the inspector; systems read and
## change `container`. Saveable (group `saveable`). In group `tags` (GROUP), so a system can find
## the entities carrying a tag (perception looks for hostile tags this way).

const GROUP: StringName = &"tags"

@export var initial_tags: Array[StringName] = []

var container := TagContainer.new()


func _ready() -> void:
	add_to_group(&"saveable")
	add_to_group(GROUP)
	for tag in initial_tags:
		container.add(tag)


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
