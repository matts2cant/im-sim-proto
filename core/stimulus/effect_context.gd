class_name EffectContext
extends RefCounted
## What an Effect gets to work with when its receptron fires.

var receiver: StimulusReceiver
## The entity the receiver belongs to (StimulusReceiver.entity).
var entity: Node
var stimulus: Stimulus
var perceived: float
## Delivery details from StimulusSystem: `distance`; RADIUS `propagation`; CONTACT and RAY
## `collider` (the node touched or hit, e.g. a hitbox); RAY `position` and `normal` of the hit.
var data: Dictionary


func _init(p_receiver: StimulusReceiver, p_stimulus: Stimulus, p_perceived: float, p_data: Dictionary = {}) -> void:
	receiver = p_receiver
	entity = p_receiver.entity
	stimulus = p_stimulus
	perceived = p_perceived
	data = p_data


## The node the stimulus actually touched or hit (a hitbox inside the entity), or null.
func collider() -> Node:
	var node: Variant = data.get("collider")
	if not is_instance_valid(node) or not node is Node:
		return null
	return node as Node


## The entity's tags, or null without a Tags component.
func tags() -> TagContainer:
	return receiver.tags.container if receiver.tags != null else null


## The entity's attributes, or null without an Attributes component.
func attributes() -> AttributeSet:
	return receiver.attributes.attribute_set if receiver.attributes != null else null
