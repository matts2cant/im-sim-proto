class_name RestoreEffect
extends Effect
## Restores the entity (the `restore` receptron: a training dummy's reset, the range's reset button):
## BodyParts.reset() (full health, no stun, `state.dead` and `state.unconscious` removed, whatever
## added them), or without BodyParts just removes those two tags. Logged `actor.reset {actor, by}`.

## The stimulus type of the `restore` receptron (a CONTACT on the body).
const STIMULUS: StringName = &"restore"


func apply(ctx: EffectContext) -> void:
	var by := ctx.stimulus.source_name()
	var parts := BodyParts.of(ctx.entity)
	if parts != null:
		parts.reset()
	else:
		ActorState.set_tag(ctx.entity, ActorState.DEAD, false)
		ActorState.set_tag(ctx.entity, ActorState.UNCONSCIOUS, false)
	var data := {"actor": String(ctx.entity.name), "by": by}
	EventLog.record(&"actor.reset", by, String(ctx.entity.name), data)


## Something to restore: a body, or a down tag to remove.
func can_apply(ctx: EffectContext) -> bool:
	return BodyParts.of(ctx.entity) != null or not ActorState.can_act(ctx.entity)
