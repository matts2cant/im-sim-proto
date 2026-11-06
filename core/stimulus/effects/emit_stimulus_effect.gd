class_name EmitStimulusEffect
extends Effect
## Emits a new stimulus from the receiver's position with the entity as source. It is processed on
## the next tick at depth + 1 (chains are how emergence happens).

@export var type: StringName = &""
@export var intensity: float = 1.0
@export var shape: Stimulus.Shape = Stimulus.Shape.RADIUS
## RADIUS reach in metres. For noise use radius = intensity = loudness (ADR 0038).
@export var radius: float = 1.0
@export var propagation: Stimulus.Propagation = Stimulus.Propagation.STRAIGHT
## RAY only, in the receiver's local space.
@export var direction: Vector3 = Vector3.FORWARD
## RAY only.
@export var length: float = 1.0
## Attribute of the entity that scales the intensity on emit (Stimulus.scale_attribute; empty: none).
@export var scale_attribute: StringName = &""


func apply(ctx: EffectContext) -> void:
	StimulusSystem.emit(make_stimulus(ctx))


## The stimulus apply() emits. CONTACT targets the source of the stimulus being reacted to.
func make_stimulus(ctx: EffectContext) -> Stimulus:
	var stimulus := Stimulus.new()
	stimulus.type = type
	stimulus.intensity = intensity
	stimulus.shape = shape
	stimulus.radius = radius
	stimulus.propagation = propagation
	stimulus.source = ctx.entity
	stimulus.origin = ctx.receiver.global_position
	stimulus.direction = ctx.receiver.global_basis * direction
	stimulus.length = length
	stimulus.scale_attribute = scale_attribute
	if is_instance_valid(ctx.stimulus.source):
		stimulus.target = ctx.stimulus.source
	return stimulus
