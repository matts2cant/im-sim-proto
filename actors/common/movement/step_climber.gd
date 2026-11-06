class_name StepClimber
extends Node
## Component of a CharacterBody3D (its parent): walks the body up low obstacles and down small
## drops without jumping (ADR 0058). Every physics tick, after the body's controller moved it with
## move_and_slide() (parents process first), it fixes up the result when the body was on the floor
## before the move and the controller did not launch it upward (a jump):
## - Step up: the move ran into a wall. It casts the body's own shape up by the step height, forward
##   along the move and back down; if that lands on a walkable surface whose top is within the step
##   height, the body is put there and keeps the speed it tried to move at. The casts check the
##   headroom for the body's current shape (crouched or standing).
## - Step down: otherwise, if the move took the body off the floor and a walkable floor lies at
##   most the step height below the floor it left, the body is put on it and snapped, so
##   is_on_floor() stays true (no landing, no fall).
## Each step emits `stepped(rise)` (+ up, - down) so a view can ease over it. The component moves
## itself to be its parent's first child, so sibling components (MovementNoise, FallImpact,
## Knockback) run after it and read the stepped state. Skipped while the body has `stance.mantle`.
## It does not step onto a rigid body that collides with this body in the solver (it would be
## flung): only bodies props pass through (the player, ADR 0054) step onto physics props.
## Any controller that moves with move_and_slide() gets this by adding the node with a StepConfig.

## Emitted after the body was moved up (rise > 0) or down (rise < 0) by a step.
signal stepped(rise: float)

## Moves shorter than this (m) do not try a step.
const MIN_MOTION: float = 0.0005
## Collisions reported per shape cast.
const MAX_CONTACTS: int = 4

@export var config: StepConfig

var body: CharacterBody3D

var _was_on_floor: bool = false
## Height of the feet at the end of the last tick on the floor: step downs are measured from it.
var _floor_y: float = 0.0
var _result := PhysicsTestMotionResult3D.new()


func _ready() -> void:
	body = get_parent() as CharacterBody3D
	if body == null:
		push_warning("StepClimber %s: the parent is not a CharacterBody3D" % get_path())
		set_physics_process(false)
		return
	if get_index() != 0:
		body.move_child.call_deferred(self, 0)


## The StepClimber child of `node`, or null.
static func of(node: Node) -> StepClimber:
	if node == null:
		return null
	for child in node.get_children():
		if child is StepClimber:
			return child as StepClimber
	return null


func _physics_process(delta: float) -> void:
	if ActorState.has(body, ActorState.MANTLING):
		_was_on_floor = false
		return
	var motion := _intended_motion(delta)
	if StepRules.may_step(_was_on_floor, motion.y / delta):
		if step_up(motion, delta) == 0.0 and not body.is_on_floor():
			step_down(motion, delta)
	_was_on_floor = body.is_on_floor()
	if _was_on_floor:
		_floor_y = body.global_position.y


## Forgets the floor state (teleports, loading a save): the next move counts as starting in the air.
func reset() -> void:
	_was_on_floor = false


## If this tick's move (`motion`, before sliding) ran into a step, puts the body on top. Returns the
## rise, 0 when there was no step.
func step_up(motion: Vector3, delta: float) -> float:
	var flat := Vector3(motion.x, 0.0, motion.z)
	if flat.length() < MIN_MOTION or not _hit_wall(flat):
		return 0.0
	var from := body.global_transform
	_cast(from, Vector3.UP * config.step_height)
	var raised := from.translated(_result.get_travel())
	for reach in StepRules.reaches(flat.length(), config):
		_cast(raised, flat.normalized() * reach)
		var ahead := raised.translated(_result.get_travel())
		if not _cast(ahead, Vector3.DOWN * (ahead.origin.y - from.origin.y)):
			continue
		var rise := ahead.origin.y + _result.get_travel().y - from.origin.y
		var top := _support_height() - from.origin.y
		var lift := raised.origin.y - from.origin.y
		if _lands_on_pushed_body():
			return 0.0
		if StepRules.can_step_up(rise, top, lift, _support_normal(), body.floor_max_angle, config):
			body.global_position = ahead.origin + _result.get_travel()
			body.velocity = flat / delta
			body.apply_floor_snap()
			stepped.emit(rise)
			return rise
	return 0.0


## After this tick's move (`motion`) took the body off the floor: puts it on a walkable floor at
## most the step height below the floor it left, straight below or, when the capsule's rounded
## bottom still hangs on the edge it left, a little further along the motion
## (StepRules.reaches). Returns the (negative) height change, 0 when there is none.
func step_down(motion: Vector3, delta: float) -> float:
	var from := body.global_transform
	var depth := config.step_height - (_floor_y - from.origin.y)
	if depth <= 0.0:
		return 0.0
	var start := from
	var found := _walkable_below(from, depth)
	var flat := Vector3(motion.x, 0.0, motion.z)
	if not found and flat.length() >= MIN_MOTION:
		for reach in StepRules.reaches(flat.length(), config):
			_cast(from, flat.normalized() * reach)
			start = from.translated(_result.get_travel())
			found = _walkable_below(start, depth)
			if found:
				break
	if not found:
		return 0.0
	body.global_position = start.origin + _result.get_travel()
	body.apply_floor_snap()
	if not body.is_on_floor():
		body.global_position = from.origin
		return 0.0
	body.velocity = Vector3(flat.x, 0.0, flat.z) / delta
	var drop := body.global_position.y - from.origin.y
	stepped.emit(drop)
	return drop


# The motion the controller asked for this tick, before any sliding: the first slide collision's
# travel + remainder, or the velocity when the move hit nothing.
func _intended_motion(delta: float) -> Vector3:
	if body.get_slide_collision_count() == 0:
		return body.velocity * delta
	var first := body.get_slide_collision(0)
	return first.get_travel() + first.get_remainder()


# True when this tick's move hit a wall (or a step's face or edge) while going along `flat`.
func _hit_wall(flat: Vector3) -> bool:
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		for j in collision.get_collision_count():
			var normal := collision.get_normal(j)
			if StepRules.is_wall(normal, body.floor_max_angle) and normal.dot(flat) < 0.0:
				return true
	return false


# Casts the body down from `from` up to `depth`; true when it lands on a walkable surface.
func _walkable_below(from: Transform3D, depth: float) -> bool:
	return _cast(from, Vector3.DOWN * depth) and StepRules.is_walkable(_support_normal(), body.floor_max_angle)


# Casts the body's shape from `from` along `motion` into _result; true when it hits something.
func _cast(from: Transform3D, motion: Vector3) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	params.margin = body.safe_margin
	params.max_collisions = MAX_CONTACTS
	return PhysicsServer3D.body_test_motion(body.get_rid(), params, _result)


# True when the last cast touched a rigid body that the solver pushes this body against (it is not
# frozen and its mask includes this body's layer): putting the body on it would fling it. Bodies
# that props pass through (the player, ADR 0054) step onto props; others shove them as before.
func _lands_on_pushed_body() -> bool:
	for i in _result.get_collision_count():
		var rigid := _result.get_collider(i) as RigidBody3D
		if rigid != null and not rigid.freeze and rigid.collision_mask & body.collision_layer != 0:
			return true
	return false


# The most upward contact normal of the last cast.
func _support_normal() -> Vector3:
	var best := Vector3.DOWN
	for i in _result.get_collision_count():
		var normal := _result.get_collision_normal(i)
		if normal.y > best.y:
			best = normal
	return best


# The highest point (world y) of the last cast's contacts that hold the body up (normal pointing up).
func _support_height() -> float:
	var top := -INF
	for i in _result.get_collision_count():
		if _result.get_collision_normal(i).y > 0.0:
			top = maxf(top, _result.get_collision_point(i).y)
	return top
