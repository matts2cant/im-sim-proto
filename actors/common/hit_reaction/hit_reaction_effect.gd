class_name HitReactionEffect
extends Effect
## The entity's HitReaction reacts to the damage stimulus that reached it (ADR 0127), on the hitbox
## part the RAY or CONTACT hit (none for an area hit). Runs after `body_damage` in the receiver's
## receptron list, so a hit that kills or knocks out finds the character unable to react.


func apply(ctx: EffectContext) -> void:
	var reaction := HitReaction.of(ctx.entity)
	if reaction == null:
		return
	reaction.react_to(ctx.stimulus, Hitboxes.part_of(ctx.collider()), ctx.perceived)
