class_name HeatEffect
extends Effect
## Adds the perceived fire intensity as heat to the entity's Flammable and Explosive components.


func apply(ctx: EffectContext) -> void:
	var flammable := Flammable.of(ctx.entity)
	if flammable != null:
		flammable.add_heat(ctx.perceived, ctx.stimulus)
	var explosive := Explosive.of(ctx.entity)
	if explosive != null:
		explosive.add_heat(ctx.perceived, ctx.stimulus)
