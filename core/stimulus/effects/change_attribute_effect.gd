class_name ChangeAttributeEffect
extends Effect
## Changes the base value of one of the entity's attributes by perceived intensity x `per_intensity`,
## clamped to [`min_value`, the value of `max_attribute`] (no upper bound when `max_attribute` is
## empty). A biocell's `energy` stimulus restores `energy` up to `energy_max` this way (ADR 0061).
## can_apply(): only when the entity has the attribute and the change would move it (energy full:
## a biocell is refused).

@export var attribute: StringName = &""
## Change per unit of perceived intensity (negative drains).
@export var per_intensity: float = 1.0
## Attribute whose current value caps the result; empty: no cap.
@export var max_attribute: StringName = &""
@export var min_value: float = 0.0


func apply(ctx: EffectContext) -> void:
	var attributes := ctx.attributes()
	if attributes == null or not attributes.has(attribute):
		return
	attributes.set_base(attribute, target_value(attributes, ctx.perceived))


func can_apply(ctx: EffectContext) -> bool:
	var attributes := ctx.attributes()
	if attributes == null or not attributes.has(attribute):
		return false
	return not is_equal_approx(target_value(attributes, ctx.perceived), attributes.base(attribute))


## The base value of `attribute` after a change by `perceived`.
func target_value(attributes: AttributeSet, perceived: float) -> float:
	var result := maxf(attributes.base(attribute) + perceived * per_intensity, min_value)
	if not max_attribute.is_empty():
		result = minf(result, attributes.value(max_attribute))
	return result
