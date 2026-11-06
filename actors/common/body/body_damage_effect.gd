class_name BodyDamageEffect
extends Effect
## Applies the perceived intensity as damage of the stimulus type to the entity's BodyParts, on the
## part of the hitbox that was hit (RAY / CONTACT `collider`), or shared out when there is none.
## The stimulus source is the attacker (knockout "from behind" rule).


func apply(ctx: EffectContext) -> void:
	var body := BodyParts.of(ctx.entity)
	if body == null:
		return
	var attacker: Node3D = null
	if is_instance_valid(ctx.stimulus.source) and ctx.stimulus.source is Node3D:
		attacker = ctx.stimulus.source as Node3D
	var part := Hitboxes.part_of(ctx.collider())
	body.take_damage(ctx.stimulus.type, ctx.perceived, part, ctx.stimulus, attacker)
