class_name NetworkLayout
extends RefCounted
## Pure placement of the terminal's network graph (ADR 0083): each device's world position seen
## from above, so the graph reads like a floor plan. World x goes right and world z goes down (north,
## -Z, at the top). The points are scaled to fit a panel of `size` with `margin` on every side and
## centred; each axis is scaled on its own to use the panel, but never more than `max_stretch` times
## the other. Nodes closer than `min_gap` are then pushed apart (devices stacked on one wall), and
## kept inside the margins. No scene tree.

## Push-apart passes.
const PASSES: int = 40
## Float slack.
const EPSILON: float = 0.0001
## Turn between the escape directions of points that start on top of each other (golden angle).
const SPREAD_ANGLE: float = 2.39996


## Panel positions of `points` (world positions), in the same order.
static func project(
	points: Array[Vector3], size: Vector2, margin: float, max_stretch: float = 2.0, min_gap: float = 0.0
) -> Array[Vector2]:
	var placed: Array[Vector2] = []
	if points.is_empty():
		return placed
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in points:
		var flat := Vector2(point.x, point.z)
		low = low.min(flat)
		high = high.max(flat)
	var extent := high - low
	var room := (size - Vector2(margin, margin) * 2.0).max(Vector2.ZERO)
	var scale_x := room.x / extent.x if extent.x > EPSILON else INF
	var scale_y := room.y / extent.y if extent.y > EPSILON else INF
	if is_inf(scale_x) and is_inf(scale_y):
		scale_x = 0.0
		scale_y = 0.0
	elif is_inf(scale_x):
		scale_x = scale_y
	elif is_inf(scale_y):
		scale_y = scale_x
	var stretch := maxf(max_stretch, 1.0)
	scale_x = minf(scale_x, scale_y * stretch)
	scale_y = minf(scale_y, scale_x * stretch)
	var middle := (low + high) * 0.5
	for point in points:
		var flat := Vector2(point.x, point.z) - middle
		placed.append(size * 0.5 + Vector2(flat.x * scale_x, flat.y * scale_y))
	if min_gap > 0.0:
		separate(placed, min_gap, size, margin)
	return placed


## Pushes `placed` apart (in place) until no two are closer than `min_gap`, as far as the panel
## (`size` minus `margin`) allows.
static func separate(placed: Array[Vector2], min_gap: float, size: Vector2, margin: float) -> void:
	var low := Vector2(margin, margin)
	var high := (size - low).max(low)
	for pass_index in PASSES:
		var moved := false
		for i in placed.size():
			for j in range(i + 1, placed.size()):
				var apart := placed[j] - placed[i]
				var distance := apart.length()
				if distance >= min_gap - EPSILON:
					continue
				var direction := apart / distance if distance > EPSILON else Vector2.RIGHT.rotated(j * SPREAD_ANGLE)
				var push := direction * (min_gap - distance) * 0.5
				placed[i] -= push
				placed[j] += push
				moved = true
		for i in placed.size():
			placed[i] = placed[i].clamp(low, high)
		if not moved:
			return
