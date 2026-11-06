class_name BodyDamageEffect
extends Effect
## Applies the perceived intensity as damage of the stimulus type to the entity's BodyParts, on the
## part of the hitbox that was hit (RAY / CONTACT `collider`), or shared out when there is none.
## The stimulus source is the attacker (knockout "from behind" rule).
## Damage = (perceived - threshold) x scale; nothing at or below the threshold. The generic
## `body_damage` receptron takes the intensity as it is (0, x1); `fall_damage` turns an impact speed
## into damage (10 m/s, x16 shared by the legs: (v - 10) x 8 per leg).

## Perceived intensity that does nothing; only the excess counts.
@export var threshold: float = 0.0
@export var scale: float = 1.0


func apply(ctx: EffectContext) -> void:
	var body := BodyParts.of(ctx.entity)
	if body == null:
		return
	var amount := damage(ctx.perceived)
	if amount <= 0.0:
		return
	var attacker: Node3D = null
	if is_instance_valid(ctx.stimulus.source) and ctx.stimulus.source is Node3D:
		attacker = ctx.stimulus.source as Node3D
	var part := Hitboxes.part_of(ctx.collider())
	body.take_damage(ctx.stimulus.type, amount, part, ctx.stimulus, attacker)


## Damage dealt for a perceived intensity.
func damage(perceived: float) -> float:
	return maxf(perceived - threshold, 0.0) * scale
