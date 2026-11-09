class_name VisionRules
extends RefCounted
## Pure vision rules (ADR 0067): how fast a watcher's suspicion rises while it sees a target.
## gain per second = base x light x distance x zone x stance x wary; the light factor has floors for
## close targets and moving ones (ADR 0095). No scene tree.


## Zone multiplier for a target `angle` degrees off the facing (horizontal) at horizontal
## `distance`: 1 in the focus cone, `peripheral_factor` in the peripheral zone, 0 outside both.
static func zone_factor(angle: float, distance: float, config: PerceptionConfig) -> float:
	var off := absf(angle)
	if off <= config.focus_half_angle and distance <= config.focus_range:
		return 1.0
	if off <= config.peripheral_half_angle and distance <= config.peripheral_range:
		return config.peripheral_factor
	return 0.0


## Light multiplier for a target at light level `level` (0 dark .. 1 lit) and horizontal `distance`,
## moving at horizontal `speed` (m/s): 0 at or below light_min, 1 at or above light_full; at least
## close_light within close_distance; at least moving_light while faster than moving_speed (a step,
## not a ramp: ADR 0095).
static func light_factor(level: float, distance: float, config: PerceptionConfig, speed: float = 0.0) -> float:
	var span := maxf(config.light_full - config.light_min, 0.0001)
	var factor := clampf((level - config.light_min) / span, 0.0, 1.0)
	if distance <= config.close_distance:
		factor = maxf(factor, config.close_light)
	if speed > config.moving_speed:
		factor = maxf(factor, config.moving_light)
	return factor


## Distance multiplier: 1 up to distance_full, linear down to distance_far_factor at distance_far
## (and beyond).
static func distance_factor(distance: float, config: PerceptionConfig) -> float:
	if distance <= config.distance_full:
		return 1.0
	var span := maxf(config.distance_far - config.distance_full, 0.0001)
	var t := clampf((distance - config.distance_full) / span, 0.0, 1.0)
	return lerpf(1.0, config.distance_far_factor, t)


## Suspicion gained per second while the target is in line of sight; `speed` is the target's
## horizontal speed (m/s), for the moving floor of the light factor.
static func gain(
	angle: float,
	distance: float,
	light_level: float,
	crouched: bool,
	wary: bool,
	config: PerceptionConfig,
	speed: float = 0.0,
) -> float:
	var zone := zone_factor(angle, distance, config)
	if zone <= 0.0:
		return 0.0
	var light := light_factor(light_level, distance, config, speed)
	if light <= 0.0:
		return 0.0
	var stance := config.crouch_factor if crouched else 1.0
	var wary_mult := config.wary_factor if wary else 1.0
	return config.base_gain * light * distance_factor(distance, config) * zone * stance * wary_mult


## Horizontal angle (degrees, 0..180) between `facing` and the direction from `eye` to `point`.
static func angle_off(facing: Vector3, eye: Vector3, point: Vector3) -> float:
	var forward := Vector2(facing.x, facing.z)
	var to := Vector2(point.x - eye.x, point.z - eye.z)
	if forward.is_zero_approx() or to.is_zero_approx():
		return 0.0
	return rad_to_deg(absf(forward.angle_to(to)))


## Horizontal distance between two points.
static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
