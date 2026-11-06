class_name KnockbackEffect
extends Effect
## Shoves the entity's Knockback component with the perceived intensity as an impulse (N s).
## Direction: a RAY (`force.impact`) pushes along the ray; anything else (`force.blast`, RADIUS)
## pushes away from the stimulus origin, towards the receiver (where the falloff was measured).
## Entities without a Knockback (static bodies) are not moved.


func apply(ctx: EffectContext) -> void:
	var knockback := Knockback.of(ctx.entity)
	if knockback == null:
		return
	knockback.push(direction(ctx) * ctx.perceived, ctx.stimulus.source_name())


static func direction(ctx: EffectContext) -> Vector3:
	if ctx.stimulus.shape == Stimulus.Shape.RAY:
		var along := ctx.stimulus.direction.normalized()
		return along if not along.is_zero_approx() else Vector3.ZERO
	var away := ctx.receiver.global_position - ctx.stimulus.origin
	return away.normalized() if away.length() > 0.001 else Vector3.UP
