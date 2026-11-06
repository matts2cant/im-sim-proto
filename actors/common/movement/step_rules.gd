class_name StepRules
extends RefCounted
## Pure rules for StepClimber (ADR 0058): when a body may step, what counts as a wall, a walkable
## top and a step, how far a step reaches, and the view easing.

## Rises below this (m) are not steps: the floor's own unevenness and the collision margin.
const MIN_RISE: float = 0.01
## Contacts whose normal points down more than this (y) are ceilings, not walls.
const CEILING_Y: float = -0.1
## Tolerance (m) on the step height for float32 contact points.
const HEIGHT_EPSILON: float = 0.001
## Asked-for upward speeds (m/s) above this are launches, not walking (ramps give 0).
const MAX_RISE_SPEED: float = 0.1
## The view offset decays as exp(-EASE_RATE x t / smooth_time): 5 % left after smooth_time.
const EASE_RATE: float = 3.0


static func is_walkable(normal: Vector3, max_floor_angle: float) -> bool:
	return normal.angle_to(Vector3.UP) <= max_floor_angle + 0.001


## A contact the body cannot walk on that is not a ceiling: a wall, a step's face or its edge.
static func is_wall(normal: Vector3, max_floor_angle: float) -> bool:
	return not is_walkable(normal, max_floor_angle) and normal.y > CEILING_Y


## True when a body may step onto an obstacle: the obstacle's top is `top` above the feet (<= step
## height), the body could rise `raised` above its feet before its head hit anything (at least to
## the top: it fits there at its current height), it lands `rise` above its feet (>= MIN_RISE) and
## the surface it lands on has a walkable `normal`. All heights in metres from the feet.
static func can_step_up(
	rise: float, top: float, raised: float, normal: Vector3, max_floor_angle: float, config: StepConfig
) -> bool:
	if rise < MIN_RISE or top > config.step_height + HEIGHT_EPSILON or raised < top - HEIGHT_EPSILON:
		return false
	return is_walkable(normal, max_floor_angle)


## How far (m) a step moves the body along its motion, in the order to try: this tick's motion
## first (no extra push), then step_reach when the motion is shorter.
static func reaches(motion_length: float, config: StepConfig) -> Array[float]:
	if motion_length >= config.step_reach:
		return [motion_length]
	return [motion_length, config.step_reach]


## A body may step (up or down) after a move when it was on the floor before it and the controller
## did not launch it upward (`vertical_speed`, m/s, of the motion it asked for: a jump, a blast).
static func may_step(was_on_floor: bool, vertical_speed: float) -> bool:
	return was_on_floor and vertical_speed <= MAX_RISE_SPEED


## A view offset (m, view minus body) after easing for `delta` seconds: limited to the step height
## (stairs do not pile it up), then decays toward 0 over about smooth_time.
static func ease_offset(offset: float, delta: float, config: StepConfig) -> float:
	if config.smooth_time <= 0.0:
		return 0.0
	var limited := clampf(offset, -config.step_height, config.step_height)
	return limited * exp(-EASE_RATE * delta / config.smooth_time)
