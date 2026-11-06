class_name ApplyImpulseEffect
extends Effect
## Pushes a RigidBody3D entity: the perceived intensity is the impulse in N s (`force.blast`,
## `force.impact`; ADR 0057). Direction from push_direction(): RADIUS stimuli push away from their
## origin, tilted up by `radial_lift`; RAY and CONTACT push along `stimulus.direction`. The impulse
## lands at the hit point (`position` in the context data, RAY) when there is one, else at the
## centre of mass. Entities that are not rigid bodies are ignored (characters have their own effect).

## Upward component added to RADIUS pushes before normalising (0.3: a blast tumbles things rather
## than sliding them along the floor). Not used for RAY or CONTACT.
@export var radial_lift: float = 0.0


func apply(ctx: EffectContext) -> void:
	var body := ctx.entity as RigidBody3D
	var amount := ctx.perceived
	if body == null or amount <= 0.0:
		return
	var direction := push_direction(ctx.stimulus, body.global_position)
	if ctx.stimulus.shape == Stimulus.Shape.RADIUS:
		direction = (direction + Vector3.UP * radial_lift).normalized()
	var impulse := direction * amount
	var at: Variant = ctx.data.get("position")
	if at is Vector3:
		body.apply_impulse(impulse, (at as Vector3) - body.global_position)
	else:
		body.apply_central_impulse(impulse)


## Unit direction `stimulus` pushes something at `target`: RADIUS from the origin to the target (up
## when they coincide), RAY and CONTACT along the stimulus direction.
static func push_direction(stimulus: Stimulus, target: Vector3) -> Vector3:
	if stimulus.shape == Stimulus.Shape.RADIUS:
		var offset := target - stimulus.origin
		return offset.normalized() if offset.length() > 0.001 else Vector3.UP
	var direction := stimulus.direction.normalized()
	return direction if not direction.is_zero_approx() else Vector3.UP
