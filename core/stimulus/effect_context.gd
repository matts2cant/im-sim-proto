class_name EffectContext
extends RefCounted
## What an Effect gets to work with when its receptron fires.

var receiver: StimulusReceiver
## The entity the receiver belongs to (StimulusReceiver.entity).
var entity: Node
var stimulus: Stimulus
var perceived: float


func _init(p_receiver: StimulusReceiver, p_stimulus: Stimulus, p_perceived: float) -> void:
	receiver = p_receiver
	entity = p_receiver.entity
	stimulus = p_stimulus
	perceived = p_perceived


## The entity's tags, or null without a Tags component.
func tags() -> TagContainer:
	return receiver.tags.container if receiver.tags != null else null


## The entity's attributes, or null without an Attributes component.
func attributes() -> AttributeSet:
	return receiver.attributes.attribute_set if receiver.attributes != null else null
