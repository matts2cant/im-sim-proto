class_name BodyPusher
extends Node
## Component of a CharacterBody3D (its parent) for ADR 0054: the character's effect on rigid bodies
## (layer 4 objects), which do not collide with kinematic characters in the solver. The controller
## calls after_move() right after its move_and_slide() with the velocity it tried to move at (not
## during scripted moves such as a mantle); it finds the bodies under the feet (presses them down
## with the character's weight) and the bodies the capsule is walking into (pushes them with a
## bounded impulse). The numbers come from PushRules, the tuning from `config`. Frozen bodies
## (carried ones included) are left alone. The attempted velocity must come from the controller: a
## body pushed out of an overlap by move_and_slide() reports that recovery as slide travel, which
## would read as walking into whatever it overlapped (a quickload next to a table of pickups).

## Query shapes are this much slimmer than the capsule so bodies touching its side do not count.
const SKIN: float = 0.02
## The push query starts this far above the feet so what the character stands on is not pushed.
const LIFT: float = 0.05
## Capsule size used when the body's shape is not a capsule.
const FALLBACK_RADIUS: float = 0.35
const FALLBACK_HEIGHT: float = 1.8

@export var config: PushConfig

var body: CharacterBody3D

var _sphere := SphereShape3D.new()
var _cylinder := CylinderShape3D.new()


func _ready() -> void:
	body = Entities.of_component(self) as CharacterBody3D
	if body == null:
		push_warning("BodyPusher %s: the parent is not a CharacterBody3D" % get_path())


## The BodyPusher child of `node`, or null.
static func of(node: Node) -> BodyPusher:
	if node == null:
		return null
	for child in node.get_children():
		if child is BodyPusher:
			return child as BodyPusher
	return null


## After the controller's move_and_slide(): `attempted` is the velocity it tried to move with
## (before sliding).
func after_move(attempted: Vector3, delta: float) -> void:
	if body == null or ActorState.has(body, ActorState.MANTLING):
		return
	var own: Array[RID] = [body.get_rid()]
	step(attempted, body.is_on_floor(), delta, own)


## One tick after the move. `velocity` is the velocity the body tried to move with (before
## sliding); `exclude` holds bodies to leave alone (the body itself).
func step(velocity: Vector3, grounded: bool, delta: float, exclude: Array[RID]) -> void:
	var feet := body.global_position
	var underfoot: Array[RigidBody3D] = []
	if grounded:
		underfoot = bodies_underfoot(feet, exclude)
		press(underfoot)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.01:
		return
	var skip: Array[RID] = exclude.duplicate()
	for found in underfoot:
		skip.append(found.get_rid())
	push(bodies_ahead(feet, capsule_height(), flat.normalized(), skip), flat, delta)


## Rigid bodies the bottom of the capsule rests on (or is within `push_probe` of).
func bodies_underfoot(feet: Vector3, exclude: Array[RID]) -> Array[RigidBody3D]:
	var radius := capsule_radius()
	_sphere.radius = radius - SKIN
	var centre := feet + Vector3.UP * (radius - config.push_probe)
	return _rigid_bodies(_sphere, Transform3D(Basis.IDENTITY, centre), exclude)


## Rigid bodies within `push_probe` of the capsule along horizontal `direction`, above the feet.
func bodies_ahead(feet: Vector3, height: float, direction: Vector3, exclude: Array[RID]) -> Array[RigidBody3D]:
	_cylinder.radius = capsule_radius() - SKIN
	_cylinder.height = maxf(height - LIFT, 0.1)
	var centre := feet + Vector3.UP * (LIFT + _cylinder.height * 0.5) + direction * config.push_probe
	return _rigid_bodies(_cylinder, Transform3D(Basis.IDENTITY, centre), exclude)


## Presses each body down with an equal share of the character's weight (through its centre:
## standing near an edge does not tip a crate).
func press(bodies: Array[RigidBody3D]) -> void:
	var gravity := body.get_gravity().length()
	var share := PushRules.weight_share(config.body_mass, gravity, bodies.size())
	for pressed in bodies:
		var force := PushRules.capped_weight(share, pressed.mass, gravity, config.weight_max_ratio)
		pressed.apply_central_force(Vector3.DOWN * force)


## Pushes each body away from the capsule axis, up to the character's speed toward it (at most
## `push_max_speed`).
func push(bodies: Array[RigidBody3D], velocity: Vector3, delta: float) -> void:
	var feet := body.global_position
	for pushed in bodies:
		var away := pushed.global_position - feet
		away.y = 0.0
		if away.is_zero_approx():
			continue
		away = away.normalized()
		var target := minf(velocity.dot(away), config.push_max_speed)
		var impulse := PushRules.push_impulse(
			pushed.mass, pushed.linear_velocity.dot(away), target, config.push_force, delta, bodies.size()
		)
		if impulse > 0.0:
			pushed.apply_central_impulse(away * impulse)


## Radius of the body's capsule (its first enabled collision shape).
func capsule_radius() -> float:
	var capsule := _capsule()
	return capsule.radius if capsule != null else FALLBACK_RADIUS


## Height of the body's capsule (changes when the character crouches).
func capsule_height() -> float:
	var capsule := _capsule()
	return capsule.height if capsule != null else FALLBACK_HEIGHT


func _capsule() -> CapsuleShape3D:
	for child in body.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return (child as CollisionShape3D).shape as CapsuleShape3D
	return null


func _rigid_bodies(shape: Shape3D, transform: Transform3D, exclude: Array[RID]) -> Array[RigidBody3D]:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = transform
	params.collision_mask = PhysicsLayers.OBJECTS
	params.exclude = exclude
	var found: Array[RigidBody3D] = []
	for hit in body.get_world_3d().direct_space_state.intersect_shape(params, 8):
		var rigid := hit["collider"] as RigidBody3D
		if rigid != null and not rigid.freeze and not found.has(rigid):
			found.append(rigid)
	return found
