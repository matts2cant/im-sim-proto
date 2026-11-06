class_name ApplyModifierEffect
extends Effect
## Adds a copy of `modifier` to the entity's Attributes, so each firing is its own modifier.

@export var modifier: Modifier
## When true, modifiers from the same source are removed first (no stacking across firings).
@export var replace_same_source: bool = false


func apply(ctx: EffectContext) -> void:
	var attributes := ctx.attributes()
	if attributes == null:
		push_warning("ApplyModifierEffect: %s has no Attributes component" % ctx.entity)
		return
	if modifier == null:
		return
	if replace_same_source:
		attributes.remove_by_source(modifier.source)
	attributes.add_modifier(modifier.duplicate() as Modifier)
