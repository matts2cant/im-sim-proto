class_name HealEffect
extends Effect
## Heals the entity's BodyParts by the perceived intensity, split over the damaged parts
## (BodyParts.heal()). A medkit's `heal` CONTACT on its user reaches it through the `heal` receptron
## (ADR 0057). A `heal` that touches one of the entity's hitboxes (the CONTACT's target, delivered as
## `collider`, like a hit) heals that body part only (a medkit used on a part, ADR 0111).
## can_apply(): only when there is a living, hurt body (or hurt part) to heal.


func apply(ctx: EffectContext) -> void:
	var body := BodyParts.of(ctx.entity)
	if body != null:
		body.heal(ctx.perceived, ctx.stimulus.source_name(), Hitboxes.part_of(ctx.collider()))


func can_apply(ctx: EffectContext) -> bool:
	var body := BodyParts.of(ctx.entity)
	if body == null or body.is_dead() or ctx.perceived <= 0.0:
		return false
	var part := Hitboxes.part_of(ctx.collider())
	if not part.is_empty():
		return BodyDamageModel.PARTS.has(part) and body.model.is_damaged(part)
	return BodyDamageModel.PARTS.any(body.model.is_damaged)
