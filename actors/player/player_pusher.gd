class_name PlayerPusher
extends RefCounted
## Thin physics adapter for ADR 0054: the player's effect on rigid bodies (layer 4 objects), which
## do not collide with the player's kinematic body in the solver. Each movement tick it finds the
## bodies under the feet (presses them down with the player's weight) and the bodies the capsule
## is walking into (pushes them with a bounded impulse). The numbers come from PushRules.

## Query shapes are this much slimmer than the capsule so bodies touching its side do not count.
const SKIN: float = 0.02
## The push query starts this far above the feet so what the player stands on is not pushed.
const LIFT: float = 0.05

var _body: CharacterBody3D
var _config: PlayerConfig
var _sphere := SphereShape3D.new()
var _cylinder := CylinderShape3D.new()


func _init(body: CharacterBody3D, config: PlayerConfig) -> void:
	_body = body
	_config = config
	_sphere.radius = config.capsule_radius - SKIN
	_cylinder.radius = config.capsule_radius - SKIN


## One tick after move_and_slide(). `velocity` is the velocity the player tried to move with (before
## sliding), `height` the capsule height; `exclude` holds bodies to leave alone (the player itself,
## what it carries).
func step(velocity: Vector3, grounded: bool, height: float, delta: float, exclude: Array[RID]) -> void:
	var feet := _body.global_position
	var underfoot: Array[RigidBody3D] = []
	if grounded:
		underfoot = bodies_underfoot(feet, exclude)
		press(underfoot)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.01:
		return
	var skip: Array[RID] = exclude.duplicate()
	for body in underfoot:
		skip.append(body.get_rid())
	push(bodies_ahead(feet, height, flat.normalized(), skip), flat, delta)


## Rigid bodies the bottom of the capsule rests on (or is within `push_probe` of).
func bodies_underfoot(feet: Vector3, exclude: Array[RID]) -> Array[RigidBody3D]:
	var centre := feet + Vector3.UP * (_config.capsule_radius - _config.push_probe)
	return _rigid_bodies(_sphere, Transform3D(Basis.IDENTITY, centre), exclude)


## Rigid bodies within `push_probe` of the capsule along horizontal `direction`, above the feet.
func bodies_ahead(feet: Vector3, height: float, direction: Vector3, exclude: Array[RID]) -> Array[RigidBody3D]:
	_cylinder.height = maxf(height - LIFT, 0.1)
	var centre := feet + Vector3.UP * (LIFT + _cylinder.height * 0.5) + direction * _config.push_probe
	return _rigid_bodies(_cylinder, Transform3D(Basis.IDENTITY, centre), exclude)


## Presses each body down with an equal share of the player's weight (through its centre: standing
## near an edge does not tip a crate).
func press(bodies: Array[RigidBody3D]) -> void:
	var gravity := _body.get_gravity().length()
	var share := PushRules.weight_share(_config.body_mass, gravity, bodies.size())
	for body in bodies:
		var force := PushRules.capped_weight(share, body.mass, gravity, _config.weight_max_ratio)
		body.apply_central_force(Vector3.DOWN * force)


## Pushes each body away from the capsule axis, up to the player's speed toward it (at most
## `push_max_speed`).
func push(bodies: Array[RigidBody3D], velocity: Vector3, delta: float) -> void:
	var feet := _body.global_position
	for body in bodies:
		var away := body.global_position - feet
		away.y = 0.0
		if away.is_zero_approx():
			continue
		away = away.normalized()
		var target := minf(velocity.dot(away), _config.push_max_speed)
		var impulse := PushRules.push_impulse(
			body.mass, body.linear_velocity.dot(away), target, _config.push_force, delta, bodies.size()
		)
		if impulse > 0.0:
			body.apply_central_impulse(away * impulse)


func _rigid_bodies(shape: Shape3D, transform: Transform3D, exclude: Array[RID]) -> Array[RigidBody3D]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = transform
	params.collision_mask = PhysicsLayers.OBJECTS
	params.exclude = exclude
	var found: Array[RigidBody3D] = []
	for hit in _body.get_world_3d().direct_space_state.intersect_shape(params, 8):
		var body := hit["collider"] as RigidBody3D
		if body != null and not body.freeze and not found.has(body):
			found.append(body)
	return found
