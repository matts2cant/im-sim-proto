class_name NetworkLayout
extends RefCounted
## Pure placement of the terminal's network graph (ADR 0083): each device's world position seen
## from above, so the graph reads like a floor plan. World x goes right and world z goes down (north,
## -Z, at the top). The points are scaled to fit a panel of `size` with `margin` on every side and
## centred; each axis is scaled on its own to use the panel, but never more than `max_stretch` times
## the other. Nodes closer than `min_gap` are then pushed apart (devices stacked on one wall), and
## kept inside the margins. `separate_boxes()` pushes apart the nodes' label boxes instead (names
## and status lines are wide: centre distances do not keep them from overlapping, M9e). No scene
## tree.

## Push-apart passes.
const PASSES: int = 40
## Push-apart passes for boxes (crowded graphs need more: each pass only halves an overlap).
const BOX_PASSES: int = 60
## Grid step (px) of the search for a free spot when pushing apart jams.
const FREE_STEP: float = 4.0
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


## Pushes the nodes' boxes apart (moving `placed`, in place) until every two are at least `gap` apart
## edge to edge, as far as the panel (`size`, boxes kept `inset` inside its edges) allows. Box `i` is
## `boxes[i]` relative to its point `placed[i]` (Rect2 offset and size). An overlapping pair moves
## apart, half each, along the axis it overlaps least (side by side or one above the other), so a
## label never hides another and the plan keeps its shape; a box held by the panel's edge leaves its
## share to the other one, and a pair that cannot part along that axis parts along the other. Boxes
## that start on top of each other part along an axis picked by their order.
static func separate_boxes(
	placed: Array[Vector2], boxes: Array[Rect2], gap: float, size: Vector2, inset: float = 0.0
) -> void:
	var count := mini(placed.size(), boxes.size())
	var low: Array[Vector2] = []
	var high: Array[Vector2] = []
	for i in count:
		low.append(Vector2(inset, inset) - boxes[i].position)
		high.append((size - Vector2(inset, inset) - boxes[i].end).max(low[i]))
		placed[i] = placed[i].clamp(low[i], high[i])
	for pass_index in BOX_PASSES:
		var moved := false
		for i in count:
			for j in range(i + 1, count):
				var a := Rect2(placed[i] + boxes[i].position, boxes[i].size).grow(gap * 0.5)
				var b := Rect2(placed[j] + boxes[j].position, boxes[j].size).grow(gap * 0.5)
				var overlap := Vector2(
					minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x),
					minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
				)
				if overlap.x <= EPSILON or overlap.y <= EPSILON:
					continue
				var apart := b.get_center() - a.get_center()
				var first := Vector2.AXIS_X if overlap.x < overlap.y else Vector2.AXIS_Y
				for axis: int in [first, 1 - first]:
					var side := signf(apart[axis]) if absf(apart[axis]) > EPSILON else (1.0 if j % 2 == 0 else -1.0)
					var push := Vector2.ZERO
					push[axis] = side * overlap[axis]
					if _push_pair(placed, i, j, push, low, high):
						moved = true
						break
		if not moved:
			break
	# Jammed (a crowded corner): move each box still overlapping to the nearest free spot.
	for k in count:
		if _overlaps_any(placed, boxes, k, gap):
			placed[k] = _nearest_free(placed, boxes, k, gap, low[k], high[k])


# True when box k overlaps (or comes closer than `gap` to) any other box.
static func _overlaps_any(
	placed: Array[Vector2], boxes: Array[Rect2], k: int, gap: float, at: Vector2 = Vector2.INF
) -> bool:
	var own := Rect2((placed[k] if at == Vector2.INF else at) + boxes[k].position, boxes[k].size).grow(
		gap * 0.5 - EPSILON
	)
	for other in mini(placed.size(), boxes.size()):
		if (
			other != k
			and own.intersects(Rect2(placed[other] + boxes[other].position, boxes[other].size).grow(gap * 0.5))
		):
			return true
	return false


# The free point nearest box k's (square rings of FREE_STEP px around it, within `low`..`high`);
# its own point when there is none.
static func _nearest_free(
	placed: Array[Vector2], boxes: Array[Rect2], k: int, gap: float, low: Vector2, high: Vector2
) -> Vector2:
	var rings := ceili((high - low).length() / FREE_STEP)
	for ring in range(1, rings + 1):
		for step in ring * 8:
			# Walk the ring's square: four sides of 2 x ring steps each.
			var side := step / (ring * 2)
			var along := step % (ring * 2) - ring
			var offset := Vector2i(along, -ring)
			match side:
				1:
					offset = Vector2i(ring, along)
				2:
					offset = Vector2i(-along, ring)
				3:
					offset = Vector2i(-ring, -along)
			var at := placed[k] + Vector2(offset) * FREE_STEP
			if at.x < low.x or at.y < low.y or at.x > high.x or at.y > high.y:
				continue
			if not _overlaps_any(placed, boxes, k, gap, at):
				return at
	return placed[k]


# Moves boxes i and j apart by `push` (i back, j forward), half each, within their bounds; a box held
# by its bound leaves the rest to the other. True when they moved at all.
static func _push_pair(
	placed: Array[Vector2], i: int, j: int, push: Vector2, low: Array[Vector2], high: Array[Vector2]
) -> bool:
	var new_i := (placed[i] - push * 0.5).clamp(low[i], high[i])
	var new_j := (placed[j] + push * 0.5).clamp(low[j], high[j])
	var left := push - ((placed[i] - new_i) + (new_j - placed[j]))
	new_j = (new_j + left).clamp(low[j], high[j])
	left = push - ((placed[i] - new_i) + (new_j - placed[j]))
	new_i = (new_i - left).clamp(low[i], high[i])
	var moved := not new_i.is_equal_approx(placed[i]) or not new_j.is_equal_approx(placed[j])
	placed[i] = new_i
	placed[j] = new_j
	return moved


## True when two of the boxes (relative to their points, as in separate_boxes()) overlap or are
## closer than `gap` (tests and checks).
static func boxes_overlap(placed: Array[Vector2], boxes: Array[Rect2], gap: float = 0.0) -> bool:
	for i in mini(placed.size(), boxes.size()):
		for j in range(i + 1, mini(placed.size(), boxes.size())):
			var a := Rect2(placed[i] + boxes[i].position, boxes[i].size).grow(gap * 0.5 - EPSILON)
			var b := Rect2(placed[j] + boxes[j].position, boxes[j].size).grow(gap * 0.5 - EPSILON)
			if a.intersects(b):
				return true
	return false
