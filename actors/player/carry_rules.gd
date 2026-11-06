class_name CarryRules
extends RefCounted
## Pure carry/throw rules for the player (tuning in PlayerConfig "Carry").


## Objects up to the carry limit (the `carry_mass_limit` attribute) can be picked up.
static func can_carry(mass: float, limit: float) -> bool:
	return mass > 0.0 and mass <= limit


## Throw speed in m/s: the throw impulse over the mass, capped.
static func throw_speed(mass: float, config: PlayerConfig) -> float:
	if mass <= 0.0:
		return config.throw_max_speed
	return minf(config.throw_max_speed, config.throw_impulse / mass)


## Move speed multiplier while carrying `mass` kg (0 = carrying nothing).
static func speed_factor(mass: float, config: PlayerConfig) -> float:
	return config.heavy_carry_speed_factor if mass >= config.heavy_carry_mass else 1.0


## Where the held object should be: along the view from the eyes, a little lower.
static func hold_point(eye: Transform3D, config: PlayerConfig) -> Vector3:
	return eye.origin - eye.basis.z * config.hold_distance + Vector3.DOWN * config.hold_drop


## Velocity that moves the held body towards the hold point (proportional, capped).
static func follow_velocity(body_position: Vector3, target: Vector3, config: PlayerConfig) -> Vector3:
	return ((target - body_position) * config.hold_follow_rate).limit_length(config.hold_max_speed)
