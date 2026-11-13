class_name HeatEffect
extends Effect
## Adds the perceived fire intensity as heat to every heat-reactive component of the entity: its
## direct children in group GROUP that implement `add_heat(amount: float, cause: Stimulus) -> void`
## (Flammable, Explosive). A new heat-reactive component joins the group; this effect never names it.

const GROUP: StringName = &"heat_reactive"
const METHOD: StringName = &"add_heat"


func apply(ctx: EffectContext) -> void:
	for child in Entities.members(ctx.entity, GROUP, METHOD):
		child.call(METHOD, ctx.perceived, ctx.stimulus)
