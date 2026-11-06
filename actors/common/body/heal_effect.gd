class_name HealEffect
extends Effect
## Heals the entity's BodyParts by the perceived intensity, split over the damaged parts
## (BodyParts.heal()). A medkit's `heal` CONTACT on its user reaches it through the `heal` receptron
## (ADR 0057). can_apply(): only when there is a living, hurt body to heal.


func apply(ctx: EffectContext) -> void:
	var body := BodyParts.of(ctx.entity)
	if body != null:
		body.heal(ctx.perceived, ctx.stimulus.source_name())


func can_apply(ctx: EffectContext) -> bool:
	var body := BodyParts.of(ctx.entity)
	if body == null or body.is_dead() or ctx.perceived <= 0.0:
		return false
	return BodyDamageModel.PARTS.any(body.model.is_damaged)
