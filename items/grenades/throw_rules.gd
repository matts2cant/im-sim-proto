class_name ThrowRules
extends RefCounted
## Pure rules of throwing and sticking (ADR 0131): the launch speed that makes a throw land a given
## distance away on flat ground, the launch velocity for a view, and the pose of a weapon stuck on a
## surface. No scene tree.

## Highest launch elevation (degrees): looking straight up still throws slightly forward.
const MAX_ELEVATION_DEG: float = 85.0


## Horizontal distance (m) a body launched at `speed` m/s, `elevation` radians above the horizontal,
## from `height` m above flat ground, travels before it reaches the ground (no drag).
static func ballistic_range(speed: float, elevation: float, height: float, gravity: float) -> float:
	var vertical := speed * sin(elevation)
	var horizontal := speed * cos(elevation)
	var fall := vertical * vertical + 2.0 * gravity * maxf(height, 0.0)
	return horizontal * (vertical + sqrt(fall)) / gravity


## The launch speed (m/s) at `elevation` from `height` that lands `distance` m away (bisection: the
## range grows with the speed).
static func launch_speed(distance: float, elevation: float, height: float, gravity: float) -> float:
	var low := 0.0
	var high := 200.0
	for i in 48:
		var mid := (low + high) * 0.5
		if ballistic_range(mid, elevation, height, gravity) < distance:
			low = mid
		else:
			high = mid
	return (low + high) * 0.5


## The launch velocity for an eye looking along `view_forward`: the view direction raised by
## `lift_deg`, at the speed that lands `distance` m from the eye on flat ground `eye_height` below it
## when looking level (the body starts `spawn_forward` m ahead of the eye). The same speed for every
## view: a fixed arc.
static func launch_velocity(
	view_forward: Vector3, distance: float, eye_height: float, lift_deg: float, spawn_forward: float, gravity: float
) -> Vector3:
	var forward := view_forward.normalized()
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.000001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var pitch := asin(clampf(forward.y, -1.0, 1.0))
	var elevation := minf(pitch + deg_to_rad(lift_deg), deg_to_rad(MAX_ELEVATION_DEG))
	var level := deg_to_rad(lift_deg)
	var speed := launch_speed(maxf(distance - spawn_forward, 0.1), level, eye_height, gravity)
	return (flat * cos(elevation) + Vector3.UP * sin(elevation)) * speed


## The pose of a body stuck on a surface at `point` with outward `normal`: its +Y along the normal,
## its centre `offset` m out from the surface, its -Z along the view projected on the surface.
static func stick_transform(point: Vector3, normal: Vector3, view_forward: Vector3, offset: float) -> Transform3D:
	var up := normal.normalized()
	var forward := view_forward - up * view_forward.dot(up)
	if forward.length_squared() < 0.000001:
		forward = up.cross(Vector3.RIGHT)
		if forward.length_squared() < 0.000001:
			forward = up.cross(Vector3.BACK)
	forward = forward.normalized()
	var back := -forward
	var right := up.cross(back).normalized()
	return Transform3D(Basis(right, up, back), point + up * offset)
