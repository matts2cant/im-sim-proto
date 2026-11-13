class_name ThrowRules
extends RefCounted
## Pure rules of throwing and sticking (ADR 0131): the launch speed that makes a throw land a given
## distance away on flat ground, the launch velocity for a view, and the pose of a weapon stuck on a
## surface. No scene tree.

## Highest launch elevation (degrees): looking straight up still throws slightly forward.
const MAX_ELEVATION_DEG: float = 85.0
## A stuck body stands upright beside surfaces steeper than this (degrees from level), on its base
## on the others.
const WALL_SLOPE_DEG: float = 45.0


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


## The pose of a body stuck on a surface at `point` with outward `normal`, seen along `view_forward`.
## The body's long axis is its +Y; its centre is `end_offset` m from either end and `side_offset` m
## from its side (an upright cylinder: half height and radius).
## - A floor or a ceiling (at most WALL_SLOPE_DEG from level): its base on the surface, +Y along the
##   normal (on a ceiling it hangs upside down, its top and the mine's light towards the room).
## - A wall (steeper): upright, +Y world up, its side against the surface.
## Its +X points along the view (projected on a floor or ceiling, straight into a wall), so the user
## sees its -X side (a grenade's lever in profile). Its centre sits where that cylinder just touches
## the surface's plane: `end_offset` out on a floor or ceiling, `side_offset` out on a vertical wall.
static func stick_transform(
	point: Vector3, normal: Vector3, view_forward: Vector3, end_offset: float, side_offset: float
) -> Transform3D:
	var out := normal.normalized()
	var up := out
	var into := view_forward - out * view_forward.dot(out)
	if absf(out.y) < cos(deg_to_rad(WALL_SLOPE_DEG)):
		up = Vector3.UP
		into = -Vector3(out.x, 0.0, out.z)
	if into.length_squared() < 0.000001:
		into = Vector3.RIGHT - up * up.x
		if into.length_squared() < 0.000001:
			into = Vector3.BACK - up * up.z
	into = into.normalized()
	var basis := Basis(into, up, into.cross(up).normalized())
	return Transform3D(basis, point + out * stick_reach(out, up, end_offset, side_offset))


## How far (m) out along `normal` the centre of an upright cylinder with axis `axis`, `end_offset`
## half height and `side_offset` radius sits when it just touches the surface's plane.
static func stick_reach(normal: Vector3, axis: Vector3, end_offset: float, side_offset: float) -> float:
	var along := absf(normal.normalized().dot(axis.normalized()))
	return end_offset * along + side_offset * sqrt(maxf(1.0 - along * along, 0.0))
