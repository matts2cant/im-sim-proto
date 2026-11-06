class_name NavWalker
extends CharacterBody3D
## Generic non-player movement controller (guards; any navigating character). Walks along the path
## of its NavigationAgent3D child at the speed asked for in move_to() (x the `move_speed_mult`
## attribute: leg injuries slow it), turns smoothly towards where it walks or the facing asked for
## (face_towards(), face_direction()), falls under gravity and moves with move_and_slide(), so the
## generic character components (StepClimber, MovementNoise, FallImpact, Knockback, ADR 0056/0058)
## work on it unchanged; a BodyPusher child gets the attempted velocity after each move (ADR 0054).
## It sets the stance tags MovementNoise reads (`stance.sprint` while asked to move at
## `sprint_tag_speed` or more). A character that cannot act (ActorState:
## dead, unconscious) stops moving and turning but still falls. Without a navmesh it walks
## straight at the target. Origin at the feet; faces -Z. Tuning: `config`. Saveable (position,
## facing, velocity). Something else decides where to go: one controller at a time (ADR 0070). The
## default is the AwarenessBehaviour; a component that takes over (CombatBehaviour) calls
## take_control() and release_control(), and the default skips its tick while
## is_controlled_by_other() is true. hold_facing() keeps it facing a point while it walks (backing
## away from a target it keeps in sight).

const MOVE_SPEED: StringName = &"move_speed_mult"

@export var config: NavWalkerConfig

## The speed asked for (m/s), before `move_speed_mult`.
var speed: float = 0.0
var agent: NavigationAgent3D

var _target: Vector3 = Vector3.ZERO
var _moving: bool = false
var _arrived: bool = false
var _face: Vector3 = Vector3.ZERO
var _controller: Node = null
var _hold_face: bool = false
var _hold_point: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
var _arrived_time: float = 0.0
var _pusher: BodyPusher


func _ready() -> void:
	add_to_group(&"saveable")
	for child in get_children():
		if child is NavigationAgent3D:
			agent = child as NavigationAgent3D
			break
	_pusher = BodyPusher.of(self)
	if agent != null:
		agent.target_desired_distance = config.arrive_distance
		agent.target_position = global_position


## Walks to `point` at `p_speed`. Asking again for the same point only changes the speed; once
## arrived short of it (blocked, unreachable, or a path that was not ready), asking again after
## `config.retry_time` tries again.
func move_to(point: Vector3, p_speed: float) -> void:
	speed = p_speed
	if _moving and point.distance_to(_target) < 0.05:
		return
	if _arrived and point.distance_to(_target) < 0.05:
		var there := _flat(point - global_position).length() <= config.arrive_distance
		if there or _arrived_time < config.retry_time:
			return
	_target = point
	_arrived_time = 0.0
	_moving = true
	_arrived = false
	_stuck_time = 0.0
	if agent != null:
		# Through another value first, so asking again for the same point re-plans the path.
		agent.target_position = global_position
		agent.target_position = point


## `by` steers the walker from now on (move_to, stop, face); the default controller pauses.
func take_control(by: Node) -> void:
	_controller = by


## `by` hands the walker back to the default controller (stops, drops a held facing).
func release_control(by: Node) -> void:
	if _controller != by:
		return
	_controller = null
	clear_hold_facing()
	stop()


## The node steering the walker now, or null (the default controller).
func controller() -> Node:
	return _controller if is_instance_valid(_controller) else null


## True when a controller other than `node` has taken the walker.
func is_controlled_by_other(node: Node) -> bool:
	var current := controller()
	return current != null and current != node


## Keeps facing `point` (horizontally) even while walking, until clear_hold_facing().
func hold_facing(point: Vector3) -> void:
	_hold_face = true
	_hold_point = point


func clear_hold_facing() -> void:
	_hold_face = false


## Stops where it is (keeps facing as asked).
func stop() -> void:
	_moving = false
	speed = 0.0


## True once the last move_to() target was reached (or as close as the navmesh gets, or blocked).
func is_arrived() -> bool:
	return _arrived


func is_moving() -> bool:
	return _moving


func target() -> Vector3:
	return _target


## Turns towards `point` (horizontally) while not walking.
func face_towards(point: Vector3) -> void:
	face_direction(point - global_position)


## Turns to horizontal `direction` while not walking.
func face_direction(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if not flat.is_zero_approx():
		_face = flat.normalized()


## Horizontal facing (-Z).
func facing() -> Vector3:
	var forward := -global_basis.z
	forward.y = 0.0
	return forward.normalized() if not forward.is_zero_approx() else Vector3.FORWARD


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Distance (m) it slides before standing still if it stops now.
func braking_distance() -> float:
	var current := horizontal_speed()
	return current * current / (2.0 * maxf(config.acceleration, 0.01))


func _physics_process(delta: float) -> void:
	if _arrived:
		_arrived_time += delta
	var can_act := ActorState.can_act(self)
	if not can_act:
		_moving = false
	var desired := Vector3.ZERO
	if _moving:
		desired = _walk_velocity(delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, config.acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * config.gravity_scale * delta
	if _hold_face:
		face_towards(_hold_point)
	elif not desired.is_zero_approx():
		# Walking: face the way it goes, and keep that facing when it stops.
		_face = _flat(desired).normalized()
	if can_act:
		_turn_towards(_face, delta)
	ActorState.set_tag(self, ActorState.SPRINTING, _moving and speed >= config.sprint_tag_speed)
	var attempted := velocity
	move_and_slide()
	if _pusher != null:
		_pusher.after_move(attempted, delta)


# The velocity along the path this tick (zero, and arrived, at the end of it or when stuck).
func _walk_velocity(delta: float) -> Vector3:
	var to_target := _flat(_target - global_position)
	if to_target.length() <= config.arrive_distance:
		return _arrive()
	var direction := to_target
	if agent != null and _has_navmesh():
		var next := agent.get_next_path_position()
		if agent.get_current_navigation_path().is_empty():
			# No path yet (the map has not taken in a freshly baked region): "finished" means nothing.
			# Ask again next tick and head straight for the target meanwhile.
			agent.target_position = _target
		else:
			if agent.is_navigation_finished():
				return _arrive()
			var to_next := _flat(next - global_position)
			if to_next.length() > 0.01:
				direction = to_next
			if _flat(agent.get_final_position() - global_position).length() <= config.arrive_distance:
				return _arrive()
	var wanted := speed * Attributes.read(self, MOVE_SPEED, 1.0)
	if _flat(get_real_velocity()).length() < wanted * config.stuck_speed_ratio:
		_stuck_time += delta
		if _stuck_time >= config.stuck_time:
			return _arrive()
	else:
		_stuck_time = 0.0
	return direction.normalized() * wanted


func _arrive() -> Vector3:
	_arrived = true
	_moving = false
	return Vector3.ZERO


func _has_navmesh() -> bool:
	var map := agent.get_navigation_map()
	return (
		map.is_valid()
		and NavigationServer3D.map_get_iteration_id(map) > 0
		and not NavigationServer3D.map_get_regions(map).is_empty()
	)


func _turn_towards(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(config.turn_rate) * delta)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


func save_state() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "velocity": velocity}


func load_state(data: Dictionary) -> void:
	global_position = data.get("position", global_position)
	rotation.y = float(data.get("yaw", rotation.y))
	velocity = data.get("velocity", velocity)
	_moving = false
	_arrived = false
	_face = Vector3.ZERO
	_hold_face = false
	var step := StepClimber.of(self)
	if step != null:
		step.reset()
