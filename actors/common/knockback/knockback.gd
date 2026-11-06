class_name Knockback
extends Node
## Component of a CharacterBody3D (its parent): shoves from `force.*` stimuli (`force.blast`,
## `force.impact`; the `knockback` receptron runs KnockbackEffect, which calls push()). The
## velocity change is impulse x impulse_scale / mass (KnockbackConfig). The upward part goes into
## the body's velocity, capped at max_up_speed (the controller's gravity brings it down). The
## horizontal part is carried here, capped at max_speed: after the body's controller moved
## (parents process first), this moves the body by it (move_and_collide, sliding along what it
## hits) and damps it out. A controller's own acceleration would cancel a velocity change within a
## tick, so any controller gets the shove without knowing about it (ADR 0056). Transient: not saved.

@export var config: KnockbackConfig

var body: CharacterBody3D
## Horizontal shove velocity still being carried (m/s).
var carried: Vector3 = Vector3.ZERO


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	if body == null:
		push_warning("Knockback %s: the parent is not a CharacterBody3D" % get_path())
		set_physics_process(false)


static func of(node: Node) -> Knockback:
	if node == null:
		return null
	for child in node.get_children():
		if child is Knockback:
			return child as Knockback
	return null


## Velocity change an impulse (N s) gives this body, before the caps.
func velocity_change(impulse: Vector3) -> Vector3:
	return impulse * config.impulse_scale / config.mass


## Shoves the body with `impulse` (N s, world space). Returns the velocity change applied.
func push(impulse: Vector3, source_name: String = "") -> Vector3:
	if body == null:
		return Vector3.ZERO
	var change := velocity_change(impulse)
	var before := carried
	carried = (carried + Vector3(change.x, 0.0, change.z)).limit_length(config.max_speed)
	var vertical := body.velocity.y
	if change.y > 0.0:
		# Never faster than the cap, but never slows a faster rise (a jump) either.
		body.velocity.y = maxf(vertical, minf(vertical + change.y, config.max_up_speed))
	else:
		body.velocity.y = vertical + change.y
	var applied := carried - before + Vector3.UP * (body.velocity.y - vertical)
	var data := {"actor": String(body.name), "impulse": impulse.length(), "speed": applied.length()}
	EventLog.record(&"actor.knocked_back", source_name, String(body.name), data)
	return applied


func _physics_process(delta: float) -> void:
	if carried.is_zero_approx():
		return
	var hit := body.move_and_collide(carried * delta)
	if hit != null:
		var normal := hit.get_normal()
		body.move_and_collide(hit.get_remainder().slide(normal))
		carried = carried.slide(normal)
		carried.y = 0.0
	var rate := config.ground_damping if body.is_on_floor() else config.air_damping
	carried = carried.move_toward(Vector3.ZERO, rate * delta)
