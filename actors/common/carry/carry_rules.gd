class_name CarryRules
extends RefCounted
## Pure carry/throw rules of a Carrier (tuning in CarryConfig, ADR 0053, ADR 0139).


## Objects up to the carry limit (the `carry_mass_limit` attribute) can be picked up.
static func can_carry(mass: float, limit: float) -> bool:
	return mass > 0.0 and mass <= limit


## Throw speed in m/s: the throw impulse over the mass, capped.
static func throw_speed(mass: float, config: CarryConfig) -> float:
	if mass <= 0.0:
		return config.throw_max_speed
	return minf(config.throw_max_speed, config.throw_impulse / mass)


## Move speed multiplier while carrying `mass` kg (0 = carrying nothing).
static func speed_factor(mass: float, config: CarryConfig) -> float:
	return config.heavy_carry_speed_factor if mass >= config.heavy_carry_mass else 1.0


## Largest half-extent of a local-space AABB (the body's collision shapes).
static func half_extent(aabb: AABB) -> float:
	return maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) * 0.5


## Distance from the eye to the held object's centre along the view: the base plus the object's
## largest half-extent (small crate 0.6 m -> 0.75 m, cardboard 0.5 m -> 0.7 m).
static func hold_distance(p_half_extent: float, config: CarryConfig) -> float:
	return config.hold_base_distance + p_half_extent


## How far below the view line (camera down) the centre sits: `hold_drop` plus the half-extent,
## so the object's top edge stays the same angle below the crosshair whatever its size.
static func hold_drop(p_half_extent: float, config: CarryConfig) -> float:
	return config.hold_drop + p_half_extent


## Where the held object's centre is shown: along the view from the eyes, then lower on the screen
## (camera down, so it stays in the same part of the view at any pitch).
static func hold_point(eye: Transform3D, p_half_extent: float, config: CarryConfig) -> Vector3:
	return (
		eye.origin - eye.basis.z * hold_distance(p_half_extent, config) - eye.basis.y * hold_drop(p_half_extent, config)
	)


## Where a release aims: the hold point, pushed forward (horizontally, along the view) until it is
## at least `body_radius` (the carrier's) + half-extent + `hold_clearance` from the eye (the
## carrier's axis), so the released object never starts inside the carrier when looking down.
## Looking level: the hold point.
static func release_target(eye: Transform3D, p_half_extent: float, body_radius: float, config: CarryConfig) -> Vector3:
	var point := hold_point(eye, p_half_extent, config)
	var forward := view_forward(eye.basis)
	var offset := point - eye.origin
	var along := offset.dot(forward)
	var min_along := body_radius + p_half_extent + config.hold_clearance
	return point + forward * maxf(min_along - along, 0.0)


## Horizontal unit vector the view faces (from the camera's right axis, so it holds at any pitch).
static func view_forward(basis: Basis) -> Vector3:
	var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
	return Vector3.UP.cross(right)


## Yaw (rotation about world up, 0 = facing -Z) of the view.
static func view_yaw(basis: Basis) -> float:
	return atan2(-basis.x.z, basis.x.x)


## Yaw of `basis` once it is turned upright by the shortest rotation that brings its local up to
## world up (upside down: rolled over its local X).
static func upright_yaw(basis: Basis) -> float:
	var b := basis.orthonormalized()
	var up := b.y
	var upright: Basis
	if up.dot(Vector3.UP) < -0.9999:
		upright = Basis(b.x, PI) * b
	elif up.dot(Vector3.UP) > 0.9999:
		upright = b
	else:
		var axis := up.cross(Vector3.UP).normalized()
		upright = Basis(axis, up.angle_to(Vector3.UP)) * b
	return atan2(-upright.x.z, upright.x.x)


## Yaw of the object relative to the view, snapped to the nearest 90 degrees.
static func snapped_yaw_offset(object_yaw: float, p_view_yaw: float) -> float:
	var relative := wrapf(object_yaw - p_view_yaw, -PI, PI)
	return wrapf(snappedf(relative, PI * 0.5), -PI, PI)


## Upright basis at the view's yaw plus `offset`.
static func held_basis(p_view_yaw: float, offset: float) -> Basis:
	return Basis(Vector3.UP, p_view_yaw + offset)


## Corner of the two-leg release path from the chest to the target: out horizontally first when
## the target is lower (so the object is lowered onto what is below it, e.g. a crate to stack on),
## up first when it is higher (onto a shelf).
static func release_corner(start: Vector3, target: Vector3) -> Vector3:
	if target.y <= start.y:
		return Vector3(target.x, start.y, target.z)
	return Vector3(start.x, target.y, start.z)


## Pick-up blend weight (0 -> 1, smoothstep) after `elapsed` of `duration` seconds.
static func pickup_blend(elapsed: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, clampf(elapsed / duration, 0.0, 1.0))


## Release placement: fraction of the cast (chest -> hold point) the object may travel, backed
## off by `margin` metres from the safe fraction the shape cast found (1 when nothing was hit).
static func release_fraction(safe_fraction: float, motion_length: float, margin: float) -> float:
	if safe_fraction >= 1.0:
		return 1.0
	if motion_length <= 0.0:
		return 0.0
	return clampf(safe_fraction - margin / motion_length, 0.0, 1.0)
