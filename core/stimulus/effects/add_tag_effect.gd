class_name AddTagEffect
extends Effect
## Adds a tag to the entity's Tags.

@export var tag: StringName = &""


func apply(ctx: EffectContext) -> void:
	var tags := ctx.tags()
	if tags == null:
		push_warning("AddTagEffect: %s has no Tags component" % ctx.entity)
		return
	tags.add(tag)
