class_name AwarenessEffect
extends Effect
## Reports the stimulus to the entity's Awareness component (ADR 0068): NOISE as a heard noise at
## the stimulus origin with the perceived margin (the `heard_noise` receptron), HARM as harm from
## the stimulus source (the `harmed` receptron), ALERT as an external alert at the origin (for alarm
## or radio stimuli). The Awareness decides what it means (allies' noise ignored, harm only from
## hostiles). Nothing happens on entities without an Awareness.

enum Kind { NOISE, HARM, ALERT }

@export var kind: Kind = Kind.NOISE


func apply(ctx: EffectContext) -> void:
	var awareness := Awareness.of(ctx.entity)
	if awareness == null:
		return
	var stimulus := ctx.stimulus
	var source: Node = stimulus.source if is_instance_valid(stimulus.source) else null
	match kind:
		Kind.NOISE:
			awareness.notice_noise(stimulus.origin, ctx.perceived, source)
		Kind.HARM:
			var at := stimulus.origin
			if source is Node3D:
				at = (source as Node3D).global_position
			awareness.notice_harm(source, at)
		Kind.ALERT:
			awareness.alert_at(stimulus.origin)


func can_apply(ctx: EffectContext) -> bool:
	return Awareness.of(ctx.entity) != null
