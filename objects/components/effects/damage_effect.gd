class_name DamageEffect
extends Effect
## Applies the perceived intensity as damage of the stimulus type to the entity's Breakable.


func apply(ctx: EffectContext) -> void:
	var breakable := Breakable.of(ctx.entity)
	if breakable != null:
		breakable.take_damage(ctx.stimulus.type, ctx.perceived, ctx.stimulus)
