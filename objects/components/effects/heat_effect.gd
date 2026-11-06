class_name HeatEffect
extends Effect
## Adds the perceived fire intensity as heat to every heat-reactive component of the entity: its
## direct children in group GROUP that implement `add_heat(amount: float, cause: Stimulus) -> void`
## (Flammable, Explosive). A new heat-reactive component joins the group; this effect never names it.

const GROUP: StringName = &"heat_reactive"
const METHOD: StringName = &"add_heat"


func apply(ctx: EffectContext) -> void:
	if not is_instance_valid(ctx.entity):
		return
	for child in ctx.entity.get_children():
		if child.is_in_group(GROUP) and child.has_method(METHOD):
			child.call(METHOD, ctx.perceived, ctx.stimulus)
