class_name RemoveTagEffect
extends Effect
## Removes a tag (exactly that tag, not its descendants) from the entity's Tags.

@export var tag: StringName = &""


func apply(ctx: EffectContext) -> void:
	var tags := ctx.tags()
	if tags == null:
		push_warning("RemoveTagEffect: %s has no Tags component" % ctx.entity)
		return
	tags.remove(tag)
