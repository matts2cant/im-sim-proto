class_name Attributes
extends Node
## Component: the entity's attributes. Declare base values in the inspector; systems and effects
## add modifiers to `attribute_set`. Saveable (group `saveable`).
## Found with Attributes.of(entity): like Tags, a core component with a fixed node name (NODE_NAME).
## Two reads, by where the base lives (conventions.md "Entities and components"):
## - value_of(entity, attribute): an attribute the entity stores (its base here: health, energy,
##   move_speed_mult, carry_limit), with its modifiers; `missing` without Attributes.
## - read(entity, attribute, base): a tuning value whose base lives in a config, changed by the
##   entity's modifiers (aim spread, Wi-Fi range; ADR 0061).

## The node name every entity gives its Attributes (of() looks it up by name: a hot path).
const NODE_NAME: NodePath = ^"Attributes"

@export var base_values: Dictionary[StringName, float] = {}

var attribute_set := AttributeSet.new()


func _ready() -> void:
	add_to_group(LevelSnapshot.GROUP)
	for attribute: StringName in base_values:
		attribute_set.set_base(attribute, base_values[attribute])


## The Attributes component of `entity` (its child named NODE_NAME), or null.
static func of(entity: Node) -> Attributes:
	if entity == null or not is_instance_valid(entity):
		return null
	return entity.get_node_or_null(NODE_NAME) as Attributes


## `base_value` changed by `entity`'s modifiers of `attribute` (AttributeSet.evaluate(): the stored
## base is ignored); `base_value` itself when the entity has no Attributes. How consumers read a
## tuning value that skills and augmentations may change (ADR 0061).
static func read(entity: Node, attribute: StringName, base_value: float) -> float:
	var attributes := of(entity)
	if attributes == null:
		return base_value
	return attributes.attribute_set.evaluate(attribute, base_value)


## The value of the attribute `entity` stores (its base with its modifiers), or `missing` when the
## entity has no Attributes.
static func value_of(entity: Node, attribute: StringName, missing: float = 0.0) -> float:
	var attributes := of(entity)
	return attributes.value(attribute) if attributes != null else missing


func value(attribute: StringName) -> float:
	return attribute_set.value(attribute)


func save_state() -> Dictionary:
	return attribute_set.to_dict()


func load_state(data: Dictionary) -> void:
	attribute_set.from_dict(data)
