class_name LogEventEffect
extends Effect
## Records an EventLog entry of `kind` (source: the stimulus source, target: the entity) with the
## stimulus id, type and perceived intensity. Stand-in reactions before a system exists (the
## player's `player.hurt` in M3, replaced by body-part damage in M4).

@export var kind: StringName = &""


func apply(ctx: EffectContext) -> void:
	if kind.is_empty():
		return
	var data := {
		"id": ctx.stimulus.id,
		"type": ctx.stimulus.type,
		"perceived": ctx.perceived,
		"shape": Stimulus.shape_name(ctx.stimulus.shape),
	}
	EventLog.record(kind, ctx.stimulus.source_name(), String(ctx.entity.name), data)
