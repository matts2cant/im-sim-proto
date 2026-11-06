class_name RaiseAlarmEffect
extends Effect
## Raises the level's alarm (LevelAlarm, found through its group) at the stimulus origin, naming
## the stimulus source (ADR 0072). Nothing happens in a level without one.


func apply(ctx: EffectContext) -> void:
	var alarm := LevelAlarm.current(ctx.receiver.get_tree())
	if alarm != null:
		alarm.raise(ctx.stimulus.origin, ctx.stimulus.source_name())


func can_apply(ctx: EffectContext) -> bool:
	return LevelAlarm.current(ctx.receiver.get_tree()) != null
