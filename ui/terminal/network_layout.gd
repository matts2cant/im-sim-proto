class_name NetworkLayout
extends RefCounted
## Pure placement of the terminal's network graph (ADR 0099, replaces ADR 0083's floor plan): node
## boxes and cable routes in content coordinates (px at zoom 1; NetworkView pans and zooms them).
## Nothing here knows what a device is: only its cables, its world position and its box size.
## - Groups: a device with HUB_LINKS or more cables is a hub (a switch, today). Every other device
##   joins the hub fewest cables away (breadth-first from every hub at once, the earlier hub on a
##   tie), hanging on the device it was reached from. A network without such a device takes the one
##   with the most cables as its hub; a part reaching no hub starts a group of its own the same way.
## - A group is a comb: its hub on top, a bus down from it, the devices on it in two columns (the
##   west half of them on the left, the east half on the right, each column north first), boxes
##   aligned on the bus side, ROW_GAP apart. A device hanging on another device sits one column
##   further out, starting on its parent's row (an indented tree). Column widths are rounded up to
##   WIDTH_STEP px, so a status change rarely moves anything.
## - Groups stand in rows, top-aligned, GROUP_GAP apart (the row count that fits a panel of `aspect`
##   best; groups are taken north to south into rows, west to east within a row).
## - Routes: a cable to a hanging device runs down its bus and across to its box (no two cross);
##   neighbouring hubs in a row are joined straight; any other cable between groups runs up to a
##   lane above the row (through the gap beside its group when it starts in another row or on a
##   device that is not a hub), along it and down. Cables of one group that are not on its tree are
##   straight lines.
## Same inputs, same placement: every order has a tie-break.

## Cables that make a device a hub.
const HUB_LINKS: int = 3
## Gap between a bus and the boxes on it (px).
const STUB: float = 28.0
## Gap between a column and the next one out.
const COLUMN_GAP: float = 40.0
## Gap between a hub's box and its first row.
const HUB_GAP: float = 18.0
## Gap between two rows of a column (box to box).
const ROW_GAP: float = 8.0
## Gap between two groups side by side, and between two rows of groups (at least).
const GROUP_GAP: float = 96.0
const GROUP_ROW_GAP: float = 72.0
## A lane's distance above its row of groups, and the step between lanes.
const LANE_GAP: float = 22.0
const LANE_STEP: float = 8.0
const WIDTH_STEP: float = 24.0

## Per node (same order as the inputs): its box.
var rects: Array[Rect2] = []
## Per node: -1 its box hangs left of its bus (aligned on its right edge), 1 right, 0 a hub.
var sides: PackedInt32Array = []
## Per node: the index of its group's hub.
var hub_of: PackedInt32Array = []
## Per node: the node it hangs on (-1 for a hub).
var parent: PackedInt32Array = []
## The hubs, in group order (rows top to bottom, each west to east).
var hubs: PackedInt32Array = []
## Per cable (same order as `cables`): its route.
var routes: Array[PackedVector2Array] = []
## Everything drawn: boxes and routes.
var bounds: Rect2 = Rect2()

var _positions: Array[Vector3] = []
var _cables: Array[Vector2i] = []
var _sizes: Array[Vector2] = []
var _anchor: float = 0.0
var _links: Array[PackedInt32Array] = []
var _depth: PackedInt32Array = []
var _children: Array[Array] = []
# Per node: its column's slot (the box's row at the column's rounded width).
var _slots: Array[Rect2] = []
# Per node: x of the bus to its children (the gap beyond its column).
var _child_bus: PackedFloat32Array = []
# Per hub: its row of groups; per row: its hubs west to east, its top and its lane count.
var _row_of: Dictionary[int, int] = {}
var _rows: Array[Array] = []
var _row_top: PackedFloat32Array = []
var _lanes: PackedInt32Array = []
# Per hub: its group's bounds.
var _group_bounds: Dictionary[int, Rect2] = {}


## Places `sizes.size()` nodes: world `positions` (only their order matters: x east, z south),
## `cables` (index pairs) and box `sizes`; `anchor`: how far below its box's top a cable meets a
## box. `aspect`: the panel's width / height, for the rows of groups.
static func arrange(
	positions: Array[Vector3], cables: Array[Vector2i], sizes: Array[Vector2], anchor: float, aspect: float = 2.4
) -> NetworkLayout:
	var layout := NetworkLayout.new()
	layout._positions = positions
	layout._cables = cables
	layout._sizes = sizes
	layout._anchor = anchor
	layout._run(aspect)
	return layout


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


func _run(aspect: float) -> void:
	var count := _sizes.size()
	rects.resize(count)
	_slots.resize(count)
	sides.resize(count)
	sides.fill(0)
	_child_bus.resize(count)
	_child_bus.fill(0.0)
	if count == 0:
		return
	_group()
	for hub in hubs:
		_place_group(hub)
	_arrange_groups(aspect)
	_route()
	bounds = rects[0]
	for rect in rects:
		bounds = bounds.merge(rect)
	for route in routes:
		for point in route:
			bounds = bounds.expand(point)


# Hubs, groups and the tree each group hangs on.
func _group() -> void:
	var count := _sizes.size()
	_links.clear()
	_children.clear()
	for i in count:
		_links.append(PackedInt32Array())
		_children.append([])
	for cable in _cables:
		if cable.x == cable.y or cable.x < 0 or cable.y < 0 or cable.x >= count or cable.y >= count:
			continue
		if not _links[cable.x].has(cable.y):
			_links[cable.x].append(cable.y)
			_links[cable.y].append(cable.x)
	for i in count:
		_links[i].sort()
	hub_of.resize(count)
	hub_of.fill(-1)
	parent.resize(count)
	parent.fill(-1)
	_depth.resize(count)
	_depth.fill(0)
	var seeds: Array[int] = []
	for i in count:
		if _links[i].size() >= HUB_LINKS:
			seeds.append(i)
	var found: Array[int] = []
	while true:
		_spread(seeds, found)
		var next := -1
		for i in count:
			if hub_of[i] < 0 and (next < 0 or _links[i].size() > _links[next].size()):
				next = i
		if next < 0:
			break
		seeds = [next]
	hubs = PackedInt32Array(found)


# Breadth-first from `seeds` at once over the nodes in no group yet.
func _spread(seeds: Array[int], found: Array[int]) -> void:
	var queue: Array[int] = []
	for start in seeds:
		hub_of[start] = start
		found.append(start)
		queue.append(start)
	var head := 0
	while head < queue.size():
		var node := queue[head]
		head += 1
		for other in _links[node]:
			if hub_of[other] >= 0:
				continue
			hub_of[other] = hub_of[node]
			parent[other] = node
			_depth[other] = _depth[node] + 1
			_children[node].append(other)
			queue.append(other)


# The comb of `hub` in group coordinates: the hub's box top-centre at the origin.
func _place_group(hub: int) -> void:
	rects[hub] = Rect2(Vector2(-_sizes[hub].x * 0.5, 0.0), _sizes[hub])
	var hub_width := _rounded(_sizes[hub].x)
	_slots[hub] = Rect2(Vector2(-hub_width * 0.5, 0.0), Vector2(hub_width, _sizes[hub].y))
	var members: Array[int] = []
	members.assign(_children[hub])
	members.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 0))
	var half := floori(members.size() * 0.5)
	var left: Array[int] = []
	left.assign(members.slice(0, half))
	var right: Array[int] = []
	right.assign(members.slice(half))
	var top := _sizes[hub].y + HUB_GAP
	for side: int in [-1, 1]:
		var column: Array[int] = left if side < 0 else right
		column.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 2))
		var widths: Dictionary[int, float] = {}
		for member in column:
			_measure(member, widths)
		var edges: Dictionary[int, float] = {1: STUB}
		for depth in range(2, widths.size() + 2):
			edges[depth] = edges[depth - 1] + widths.get(depth - 1, 0.0) + COLUMN_GAP
		var y := top
		for member in column:
			y = _place_subtree(member, side, y, edges, widths) + ROW_GAP
	# From the columns' rounded widths: a status change within a step does not move the group.
	var group := _slots[hub]
	for i in rects.size():
		if hub_of[i] == hub:
			group = group.merge(_slots[i])
	_group_bounds[hub] = group


# The widest box (rounded up) at each depth of `node`'s subtree.
func _measure(node: int, widths: Dictionary[int, float]) -> void:
	var width := _rounded(_sizes[node].x)
	widths[_depth[node]] = maxf(widths.get(_depth[node], 0.0), width)
	for child: int in _children[node]:
		_measure(child, widths)


# Places `node` at row `y` on `side` and its subtree beside and below it; returns the bottom.
func _place_subtree(
	node: int, side: int, y: float, edges: Dictionary[int, float], widths: Dictionary[int, float]
) -> float:
	var depth := _depth[node]
	var edge: float = edges[depth]
	var x := edge if side > 0 else -edge - _sizes[node].x
	rects[node] = Rect2(Vector2(x, y), _sizes[node])
	var slot_width: float = widths.get(depth, 0.0)
	_slots[node] = Rect2(Vector2(edge if side > 0 else -edge - slot_width, y), Vector2(slot_width, _sizes[node].y))
	sides[node] = side
	_child_bus[node] = side * (edge + widths.get(depth, 0.0) + COLUMN_GAP * 0.5)
	var bottom := y + _sizes[node].y
	var row := y
	var kids: Array[int] = []
	kids.assign(_children[node])
	kids.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 2))
	for child in kids:
		var end := _place_subtree(child, side, row, edges, widths)
		bottom = maxf(bottom, end)
		row = end + ROW_GAP
	return bottom


func _rounded(width: float) -> float:
	return ceilf(width / WIDTH_STEP - 0.001) * WIDTH_STEP


# True when node a comes before b along world `axis` (0: x, 2: z), then the other axis, then index.
func _before(a: int, b: int, axis: int) -> bool:
	var other := 2 - axis
	var pa := _positions[a] if a < _positions.size() else Vector3.ZERO
	var pb := _positions[b] if b < _positions.size() else Vector3.ZERO
	if not is_equal_approx(pa[axis], pb[axis]):
		return pa[axis] < pb[axis]
	if not is_equal_approx(pa[other], pb[other]):
		return pa[other] < pb[other]
	return a < b


# Rows of groups: the count that gives the largest fitted zoom in a panel of `aspect`, fewest on a tie.
func _arrange_groups(aspect: float) -> void:
	var order: Array[int] = []
	order.assign(Array(hubs))
	order.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 2))
	var best: Array[Array] = []
	var best_score := -1.0
	for row_count in range(1, order.size() + 1):
		var per_row := ceili(float(order.size()) / row_count)
		var candidate: Array[Array] = []
		for start in range(0, order.size(), per_row):
			var row: Array[int] = []
			row.assign(order.slice(start, start + per_row))
			row.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 0))
			candidate.append(row)
		var extent := Vector2.ZERO
		for row: Array in candidate:
			var row_size := Vector2(-GROUP_GAP, 0.0)
			for hub: int in row:
				row_size.x += _group_bounds[hub].size.x + GROUP_GAP
				row_size.y = maxf(row_size.y, _group_bounds[hub].size.y)
			extent.x = maxf(extent.x, row_size.x)
			extent.y += row_size.y + GROUP_ROW_GAP
		var score := minf(aspect / maxf(extent.x, 1.0), 1.0 / maxf(extent.y, 1.0))
		if score > best_score + 0.000001:
			best_score = score
			best = candidate
	_rows = best
	hubs = PackedInt32Array()
	for r in _rows.size():
		for hub: int in _rows[r]:
			_row_of[hub] = r
			hubs.append(hub)
	# Lanes per row, then the rows' tops (room for their lanes above them).
	_lanes.resize(_rows.size())
	_lanes.fill(0)
	for cable in _cables:
		var lane_row := _lane_row(cable)
		if lane_row >= 0:
			_lanes[lane_row] += 1
	_row_top.resize(_rows.size())
	var y := 0.0
	for r in _rows.size():
		if r > 0:
			y += maxf(GROUP_ROW_GAP, LANE_GAP * 2.0 + _lanes[r] * LANE_STEP)
		_row_top[r] = y
		var x := 0.0
		var height := 0.0
		for hub: int in _rows[r]:
			var local := _group_bounds[hub]
			var shift := Vector2(x - local.position.x, y - local.position.y)
			for i in rects.size():
				if hub_of[i] == hub:
					rects[i].position += shift
					_child_bus[i] += shift.x
			_group_bounds[hub] = Rect2(local.position + shift, local.size)
			x += local.size.x + GROUP_GAP
			height = maxf(height, local.size.y)
		y += height
	_lanes.fill(0)


# The row whose lane carries `cable`, or -1 (inside a group, or two neighbouring hubs).
func _lane_row(cable: Vector2i) -> int:
	var a := hub_of[cable.x] if cable.x >= 0 and cable.x < hub_of.size() else -1
	var b := hub_of[cable.y] if cable.y >= 0 and cable.y < hub_of.size() else -1
	if a < 0 or b < 0 or a == b:
		return -1
	if _row_of[a] == _row_of[b] and cable.x == a and cable.y == b:
		var row: Array = _rows[_row_of[a]]
		if absi(row.find(a) - row.find(b)) == 1:
			return -1
	return maxi(_row_of[a], _row_of[b])


func _route() -> void:
	routes.clear()
	for cable in _cables:
		var route := PackedVector2Array()
		var count := rects.size()
		if cable.x < 0 or cable.y < 0 or cable.x >= count or cable.y >= count or cable.x == cable.y:
			routes.append(route)
			continue
		if parent[cable.y] == cable.x:
			route = _tree_route(cable.x, cable.y)
		elif parent[cable.x] == cable.y:
			route = _tree_route(cable.y, cable.x)
		else:
			var lane_row := _lane_row(cable)
			if lane_row < 0 and hub_of[cable.x] == hub_of[cable.y]:
				route = PackedVector2Array([_attach(cable.x), _attach(cable.y)])
			elif lane_row < 0:
				route = PackedVector2Array([_centre(cable.x), _centre(cable.y)])
			else:
				route = _lane_route(cable, lane_row)
		routes.append(_simplified(route))


# From `from` (the node `to` hangs on) down its bus and across to `to`'s box.
func _tree_route(from: int, to: int) -> PackedVector2Array:
	var y := rects[to].position.y + _anchor
	var inner := _inner_x(to)
	if sides[from] == 0:
		var bus := rects[from].get_center().x
		return PackedVector2Array([_centre(from), Vector2(bus, y), Vector2(inner, y)])
	var start := Vector2(_outer_x(from), rects[from].position.y + _anchor)
	var bus_x := _child_bus[from]
	return PackedVector2Array([start, Vector2(bus_x, start.y), Vector2(bus_x, y), Vector2(inner, y)])


# Up (or through the gap beside a group) to a lane above `lane_row`, along it and down.
func _lane_route(cable: Vector2i, lane_row: int) -> PackedVector2Array:
	var lane_y := _row_top[lane_row] - LANE_GAP - _lanes[lane_row] * LANE_STEP
	var lane := _lanes[lane_row]
	_lanes[lane_row] += 1
	var first := _to_lane(cable.x, cable.y, lane_row, lane_y, lane)
	var last := _to_lane(cable.y, cable.x, lane_row, lane_y, lane)
	last.reverse()
	first.append_array(last)
	return first


# The path from `node` to the lane at `lane_y` (toward `other`).
func _to_lane(node: int, other: int, lane_row: int, lane_y: float, lane: int) -> PackedVector2Array:
	var hub := hub_of[node]
	var centre := _centre(node)
	if sides[node] == 0 and _row_of[hub] == lane_row:
		return PackedVector2Array([centre, Vector2(centre.x, rects[node].position.y), Vector2(centre.x, lane_y)])
	var side := sides[node]
	if side == 0:
		side = 1 if _centre(other).x >= centre.x else -1
	var group := _group_bounds[hub]
	var gap := LANE_GAP + lane * LANE_STEP
	var gutter := group.end.x + gap if side > 0 else group.position.x - gap
	var start := centre if sides[node] == 0 else _attach(node, true)
	return PackedVector2Array([start, Vector2(gutter, start.y), Vector2(gutter, lane_y)])


# Where a cable meets `node`'s box: its bus side (`outer`: the far side), `_anchor` below its top.
func _attach(node: int, outer: bool = false) -> Vector2:
	if sides[node] == 0:
		return _centre(node)
	return Vector2(_outer_x(node) if outer else _inner_x(node), rects[node].position.y + _anchor)


func _centre(node: int) -> Vector2:
	return Vector2(rects[node].get_center().x, rects[node].position.y + _anchor)


func _inner_x(node: int) -> float:
	return rects[node].position.x if sides[node] >= 0 else rects[node].end.x


func _outer_x(node: int) -> float:
	return rects[node].end.x if sides[node] >= 0 else rects[node].position.x


# Without repeated points.
static func _simplified(route: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in route:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(point):
			result.append(point)
	return result


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
