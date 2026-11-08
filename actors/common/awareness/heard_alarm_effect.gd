class_name HeardAlarmEffect
extends Effect
## Reports a heard siren pulse (the `heard_siren` receptron, ADR 0077) to the entity's AlarmHearing
## at the stimulus origin. Nothing happens on entities without one.


func apply(ctx: EffectContext) -> void:
	var hearing := AlarmHearing.of(ctx.entity)
	if hearing != null:
		hearing.hear(ctx.stimulus.origin)


func can_apply(ctx: EffectContext) -> bool:
	return AlarmHearing.of(ctx.entity) != null
