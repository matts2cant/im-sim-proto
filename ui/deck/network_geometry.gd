class_name NetworkGeometry
extends RefCounted
## Pure checks on a network map's drawing (ADR 0099): cable crossings, cables under boxes, boxes
## too close. NetworkLayout's tests and the map readability checks use them.


## The number of places where two routes cross (touching ends and shared buses do not count).
static func crossings(p_routes: Array[PackedVector2Array]) -> int:
	var count := 0
	for i in p_routes.size():
		for j in range(i + 1, p_routes.size()):
			for a in p_routes[i].size() - 1:
				for b in p_routes[j].size() - 1:
					if _segments_cross(p_routes[i][a], p_routes[i][a + 1], p_routes[j][b], p_routes[j][b + 1]):
						count += 1
	return count


## Route segments that pass through a box other than their cable's two ends' (`p_cables[k]` are the
## ends of `p_routes[k]`); boxes shrunk by `inset` px.
static func routes_through_boxes(
	p_routes: Array[PackedVector2Array], p_cables: Array[Vector2i], p_rects: Array[Rect2], inset: float = 1.0
) -> int:
	var count := 0
	for k in mini(p_routes.size(), p_cables.size()):
		for i in p_rects.size():
			if i == p_cables[k].x or i == p_cables[k].y:
				continue
			var box := p_rects[i].grow(-inset)
			for s in p_routes[k].size() - 1:
				if _segment_hits_rect(p_routes[k][s], p_routes[k][s + 1], box):
					count += 1
					break
	return count


## True when two of `p_rects` overlap or are closer than `gap` (edge to edge).
static func rects_overlap(p_rects: Array[Rect2], gap: float = 0.0) -> bool:
	for i in p_rects.size():
		for j in range(i + 1, p_rects.size()):
			if p_rects[i].grow(gap * 0.5 - 0.001).intersects(p_rects[j].grow(gap * 0.5 - 0.001)):
				return true
	return false


# Proper crossing: each segment's ends strictly on both sides of the other.
static func _segments_cross(a1: Vector2, a2: Vector2, b1: Vector2, b2: Vector2) -> bool:
	var d1 := _orientation(b1, b2, a1)
	var d2 := _orientation(b1, b2, a2)
	var d3 := _orientation(a1, a2, b1)
	var d4 := _orientation(a1, a2, b2)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	var value := (b - a).cross(c - a)
	return 0.0 if absf(value) < 0.01 else signf(value)


# Liang-Barsky: true when the segment passes through the rectangle's inside.
static func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var low := 0.0
	var high := 1.0
	var delta := to - from
	for axis in 2:
		if absf(delta[axis]) < 0.000001:
			if from[axis] <= rect.position[axis] or from[axis] >= rect.end[axis]:
				return false
			continue
		var t1 := (rect.position[axis] - from[axis]) / delta[axis]
		var t2 := (rect.end[axis] - from[axis]) / delta[axis]
		low = maxf(low, minf(t1, t2))
		high = minf(high, maxf(t1, t2))
		if low >= high:
			return false
	return true
