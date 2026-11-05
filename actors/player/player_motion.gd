class_name PlayerMotion
extends RefCounted
## Pure movement rules: mode selection, speed caps, acceleration, jump launch speed, eye height.

enum Mode { IDLE, WALK, SPRINT, CROUCH, AIR, MANTLE }

const MODE_NAMES: Dictionary[Mode, StringName] = {
	Mode.IDLE: &"idle",
	Mode.WALK: &"walk",
	Mode.SPRINT: &"sprint",
	Mode.CROUCH: &"crouch",
	Mode.AIR: &"air",
	Mode.MANTLE: &"mantle",
}


static func mode_name(mode: Mode) -> StringName:
	return MODE_NAMES[mode]


## `input` is the move vector as from Input.get_vector(left, right, forward, back): -y is forward.
static func select_mode(
	grounded: bool, crouched: bool, sprint_held: bool, input: Vector2, config: PlayerConfig
) -> Mode:
	if not grounded:
		return Mode.AIR
	if crouched:
		return Mode.CROUCH
	if input.is_zero_approx():
		return Mode.IDLE
	if sprint_held and is_forwardish(input, config.sprint_max_angle_deg):
		return Mode.SPRINT
	return Mode.WALK


static func is_forwardish(input: Vector2, max_angle_deg: float) -> bool:
	if input.is_zero_approx():
		return false
	return absf(Vector2.UP.angle_to(input)) <= deg_to_rad(max_angle_deg)


## Speed cap on the ground for a mode. Idle uses the walk cap (only deceleration happens there).
static func max_speed(mode: Mode, config: PlayerConfig) -> float:
	match mode:
		Mode.SPRINT:
			return config.sprint_speed
		Mode.CROUCH:
			return config.crouch_speed
		_:
			return config.walk_speed


## New horizontal velocity. `wish` is the world-space move direction (length 0..1, y ignored).
## On the ground: accelerate toward wish x max_speed, or decelerate to rest without input.
## In the air: only air_control x acceleration, and no braking without input (momentum is kept).
static func horizontal_velocity(
	current: Vector3, wish: Vector3, max_speed: float, grounded: bool, delta: float, config: PlayerConfig
) -> Vector3:
	var flat := Vector3(current.x, 0.0, current.z)
	var flat_wish := Vector3(wish.x, 0.0, wish.z).limit_length(1.0)
	var target := flat_wish * max_speed
	if grounded:
		var rate := config.ground_deceleration if flat_wish.is_zero_approx() else config.ground_acceleration
		return flat.move_toward(target, rate * delta)
	if flat_wish.is_zero_approx():
		return flat
	return flat.move_toward(target, config.ground_acceleration * config.air_control * delta)


## Launch speed that reaches `apex_height` under `gravity` (both positive).
static func jump_speed(apex_height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * apex_height)


static func eye_height(crouched: bool, config: PlayerConfig) -> float:
	return config.crouched_eye_height if crouched else config.standing_eye_height


## Moves the eye toward its target so a full stand/crouch change takes eye_transition_time.
static func step_eye(current: float, target: float, delta: float, config: PlayerConfig) -> float:
	if config.eye_transition_time <= 0.0:
		return target
	var rate := (config.standing_eye_height - config.crouched_eye_height) / config.eye_transition_time
	return move_toward(current, target, absf(rate) * delta)
