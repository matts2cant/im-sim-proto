class_name ReviveEffect
extends Effect
## Wakes the entity (ADR 0071): BodyParts.revive() (stun 0, conscious, `state.unconscious` removed),
## or without BodyParts just removes `state.unconscious` (logged `actor.revived` either way). The
## `revive` receptron blocks the dead.


func apply(ctx: EffectContext) -> void:
	var by := ctx.stimulus.source_name()
	var parts := BodyParts.of(ctx.entity)
	if parts != null:
		parts.revive(by)
		return
	if ActorState.has(ctx.entity, ActorState.UNCONSCIOUS):
		ActorState.set_tag(ctx.entity, ActorState.UNCONSCIOUS, false)
		var data := {"actor": String(ctx.entity.name), "by": by}
		EventLog.record(EventKinds.ACTOR_REVIVED, by, String(ctx.entity.name), data)


func can_apply(ctx: EffectContext) -> bool:
	return ActorState.has(ctx.entity, ActorState.UNCONSCIOUS) and not ActorState.is_dead(ctx.entity)
