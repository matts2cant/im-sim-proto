class_name Attributes
extends Node
## Component: the entity's attributes. Declare base values in the inspector; systems and effects
## add modifiers to `attribute_set`. Saveable (group `saveable`).

@export var base_values: Dictionary[StringName, float] = {}

var attribute_set := AttributeSet.new()


func _ready() -> void:
	add_to_group(&"saveable")
	for attribute: StringName in base_values:
		attribute_set.set_base(attribute, base_values[attribute])


## The Attributes component of `entity` (its child named `Attributes`), or null.
static func of(entity: Node) -> Attributes:
	if not is_instance_valid(entity):
		return null
	return entity.get_node_or_null(^"Attributes") as Attributes


## `base_value` changed by `entity`'s modifiers of `attribute` (AttributeSet.evaluate(): the stored
## base is ignored); `base_value` itself when the entity has no Attributes. How consumers read a
## tuning value that skills and augmentations may change (ADR 0061).
static func read(entity: Node, attribute: StringName, base_value: float) -> float:
	var attributes := of(entity)
	if attributes == null:
		return base_value
	return attributes.attribute_set.evaluate(attribute, base_value)


func value(attribute: StringName) -> float:
	return attribute_set.value(attribute)


func save_state() -> Dictionary:
	return attribute_set.to_dict()


func load_state(data: Dictionary) -> void:
	attribute_set.from_dict(data)
