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


func value(attribute: StringName) -> float:
	return attribute_set.value(attribute)


func save_state() -> Dictionary:
	return attribute_set.to_dict()


func load_state(data: Dictionary) -> void:
	attribute_set.from_dict(data)
