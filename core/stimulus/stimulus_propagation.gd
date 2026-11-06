class_name StimulusPropagation
extends RefCounted
## Pure propagation math: falloff, polyline length, segment/volume tests. No scene tree.


## Linear falloff: intensity x (1 - distance / radius) within the radius, -1 beyond it (ADR 0038).
static func falloff(intensity: float, radius: float, distance: float) -> float:
	if radius <= 0.0 or distance > radius:
		return -1.0
	return intensity * (1.0 - distance / radius)


static func polyline_length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total


## True when the segment a-b touches the box (slab test; a point inside counts).
static func segment_intersects_aabb(a: Vector3, b: Vector3, box: AABB) -> bool:
	var t_min := 0.0
	var t_max := 1.0
	var delta := b - a
	var low := box.position
	var high := box.end
	for axis in 3:
		if is_zero_approx(delta[axis]):
			if a[axis] < low[axis] or a[axis] > high[axis]:
				return false
			continue
		var t1 := (low[axis] - a[axis]) / delta[axis]
		var t2 := (high[axis] - a[axis]) / delta[axis]
		t_min = maxf(t_min, minf(t1, t2))
		t_max = minf(t_max, maxf(t1, t2))
		if t_min > t_max:
			return false
	return true


static func segment_intersects_sphere(a: Vector3, b: Vector3, center: Vector3, sphere_radius: float) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(center, a, b)
	return closest.distance_to(center) <= sphere_radius


## True when any straight segment of the polyline touches the box.
static func polyline_intersects_aabb(points: PackedVector3Array, box: AABB) -> bool:
	for i in range(1, points.size()):
		if segment_intersects_aabb(points[i - 1], points[i], box):
			return true
	return false
