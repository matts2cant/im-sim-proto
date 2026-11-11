class_name NetworkLayout
extends RefCounted
## Pure placement of the deck's network map (ADR 0099, 0112 amendment): node boxes, cable routes and
## subnet boxes in content coordinates (px at zoom 1; NetworkView pans and zooms them). Nothing here
## knows what a device is: only its cables, its world position, its box size and its region (the
## subnet it is on, or none for a router between subnets).
## - Groups: a device with HUB_LINKS or more cables is a hub (a switch, today). Every other device
##   joins the hub of its region fewest cables away (breadth-first from every hub at once, the
##   earlier hub on a tie), hanging on the device it was reached from. A region without such a
##   device takes the one with the most cables as its hub; a part reaching no hub starts a group of
##   its own the same way. Routers belong to no group.
## - A group is a comb: its hub on top, a bus down from it, the devices on it in two columns (the
##   west half of them on the left, the east half on the right, each column north first), boxes
##   aligned on the bus side, ROW_GAP apart. A device hanging on another device sits one column
##   further out, starting on its parent's row (an indented tree). Column widths are rounded up to
##   WIDTH_STEP px, so a status change rarely moves anything.
## - Switch trees (a tidy tree per region): the cables between two hubs of a region make a tree
##   (breadth first from each root, west first). Its roots: the hubs the routers beside the region enter by, then the
##   hubs cabled to the most other hubs (a building's main switch). Each hub's block is its group
##   with its child hubs' blocks in rows below it (one row centred under it; several rows start at
##   its left with a spine beside them), children_per_row the count that fits the whole map in a
##   panel of `aspect` best. Blocks never overlap, so the cables between hubs never cross.
## - Regions: a region's trees stand side by side in its box (REGION_PAD around them, its title at
##   the top-left). Regions stand side by side, top-aligned, in a line from region 0: a router sits
##   between the two regions it joins (a region's first router on its right, the next on its left,
##   further regions outward), a router whose other region is hidden beside its one region.
## - Routes: a cable to a hanging device runs down its bus and across to its box; a cable from a
##   hub to a child hub runs down the hub's bus below its group (through the spine for a lower row),
##   along the line the child's row hangs from and down onto it. A router's cable enters the region
##   beside it in a lane at the box's top (the farthest root's lane highest) and drops onto a root;
##   onto a hub inside a tree (its branch kept last on the router's side) it runs down the box's side
##   and in above that hub's row. Anything else (a loop, a link through a device that is not a hub,
##   regions not side by side) is `extra`: lanes above every box, drawn last; it may cross. Cables
##   of one group that are not on its tree are straight lines.
## Same inputs, same placement: every order has a tie-break.

## A layout input `regions[i]` for a router (between regions).
const ROUTER: int = -1
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
## A region's box: padding around its groups, its title's inset from the box's top-left corner and
## the gap below the title.
const REGION_PAD: float = 28.0
const TITLE_INSET: Vector2 = Vector2(12.0, 8.0)
const TITLE_GAP: float = 14.0
## Gap between a router (or a box) and a box beside it, and between two boxes without a router.
const ROUTER_GAP: float = 40.0
const REGION_GAP: float = 72.0

## Per node (same order as the inputs): its box.
var rects: Array[Rect2] = []
## Per node: -1 its box hangs left of its bus (aligned on its right edge), 1 right, 0 a hub or router.
var sides: PackedInt32Array = []
## Per node: the index of its group's hub (a router: itself).
var hub_of: PackedInt32Array = []
## Per node: the node it hangs on (-1 for a hub or router).
var parent: PackedInt32Array = []
## The hubs, in group order (regions left to right, each row by row, each row in order).
var hubs: PackedInt32Array = []
## The routers, left to right.
var routers: PackedInt32Array = []
## Per node: its region, ROUTER for a router.
var region_of: PackedInt32Array = []
## Per region: its box (Rect2() for a region without nodes).
var region_rects: Array[Rect2] = []
## Per region: the top-left corner of its title.
var title_positions: Array[Vector2] = []
## Regions are drawn as boxes (more than one region, a router, or a title).
var boxed: bool = false
## Cables off the network's tree (a loop, a link between groups through a device that is not a hub, a
## link between regions not side by side): routed in lanes above every box; they may cross others.
var extra: PackedInt32Array = []
## Per cable (same order as `cables`): its route.
var routes: Array[PackedVector2Array] = []
## Everything drawn: the boxes, the column slots and the routes (it starts at the origin).
var bounds: Rect2 = Rect2()

var _positions: Array[Vector3] = []
var _cables: Array[Vector2i] = []
var _sizes: Array[Vector2] = []
var _titles: Array[Vector2] = []
var _anchor: float = 0.0
var _links: Array[PackedInt32Array] = []
var _depth: PackedInt32Array = []
var _children: Array[Array] = []
# Per node: its column's slot (the box's row at the column's rounded width).
var _slots: Array[Rect2] = []
# Per node: x of the bus to its children (the gap beyond its column).
var _child_bus: PackedFloat32Array = []
# Per hub: its group's bounds (group coordinates until placed).
var _group_bounds: Dictionary[int, Rect2] = {}
var _region_count: int = 0
# Per region: its switch trees' roots (hubs), left to right.
var _roots: Array[PackedInt32Array] = []
# Hub -> its child hubs in its region's switch tree (left to right); child hub -> its uplink cable.
var _kids: Dictionary[int, Array] = {}
var _uplink: Dictionary[int, int] = {}
var _up_hub: Dictionary[int, int] = {}
# Per region: the cables of the routers right beside it into it; cable -> it comes from the left.
var _entries: Array[PackedInt32Array] = []
var _from_left: Dictionary[int, bool] = {}
# Left to right: Vector2i(0, region) or Vector2i(1, router node).
var _blocks: Array[Vector2i] = []
var _plans: Array[RegionPlan] = []
var _origins: Array[Vector2] = []


## One region's placement for a number of children per row, in region coordinates (its box's
## top-left at the origin).
class RegionPlan:
	extends RefCounted
	var children_per_row: int = 1
	## Hub -> where its group's origin (its box's top-centre) sits.
	var at: Dictionary[int, Vector2] = {}
	## Hub -> the y of the line each row of its child hubs hangs from; the x of its spine when they
	## stand in several rows (else NAN).
	var bands: Dictionary[int, PackedFloat32Array] = {}
	var spine: Dictionary[int, float] = {}
	## Child hub -> its row under its parent; its offset from its parent's origin (while building).
	var row: Dictionary[int, int] = {}
	var local: Dictionary[int, Vector2] = {}
	## Router cable -> the y it runs in: an entry lane at the box's top, or (`gutter`) the line the
	## row of its device hangs from, reached down the box's side.
	var lane_y: Dictionary[int, float] = {}
	var gutter: Dictionary[int, bool] = {}
	var size: Vector2 = Vector2.ZERO


## Places `sizes.size()` nodes: world `positions` (only their order matters: x east, z south),
## `cables` (index pairs) and box `sizes`; `anchor`: how far below its box's top a cable meets a
## box. `aspect`: the panel's width / height. `regions`: per node its region index (ROUTER for a
## router; empty: one region), `titles`: per region its title's size (zero: none).
static func arrange(
	positions: Array[Vector3],
	cables: Array[Vector2i],
	sizes: Array[Vector2],
	anchor: float,
	aspect: float = 2.4,
	regions: PackedInt32Array = PackedInt32Array(),
	titles: Array[Vector2] = [],
) -> NetworkLayout:
	var layout := NetworkLayout.new()
	layout._positions = positions
	layout._cables = cables
	layout._sizes = sizes
	layout._anchor = anchor
	layout._titles = titles
	layout.region_of.resize(sizes.size())
	layout.region_of.fill(0)
	for i in mini(regions.size(), sizes.size()):
		layout.region_of[i] = regions[i] if regions[i] >= 0 else ROUTER
	layout._run(aspect)
	return layout


## True when `node` is a router (between regions).
func is_router(node: int) -> bool:
	return node >= 0 and node < region_of.size() and region_of[node] == ROUTER


func _run(aspect: float) -> void:
	var count := _sizes.size()
	rects.resize(count)
	_slots.resize(count)
	sides.resize(count)
	sides.fill(0)
	_child_bus.resize(count)
	_child_bus.fill(0.0)
	_region_count = _titles.size()
	for i in count:
		_region_count = maxi(_region_count, region_of[i] + 1)
	region_rects.resize(_region_count)
	region_rects.fill(Rect2())
	title_positions.resize(_region_count)
	title_positions.fill(Vector2.ZERO)
	if count == 0:
		return
	_group()
	for i in count:
		if is_router(i):
			rects[i] = Rect2(Vector2(-_sizes[i].x * 0.5, 0.0), _sizes[i])
			var width := _rounded(_sizes[i].x)
			_slots[i] = Rect2(Vector2(-width * 0.5, 0.0), Vector2(width, _sizes[i].y))
	for hub in hubs:
		_place_group(hub)
	boxed = not routers.is_empty() or _region_count > 1
	for title in _titles:
		boxed = boxed or title != Vector2.ZERO
	_sequence()
	_build_trees()
	_choose_plans(aspect)
	_apply()
	_route()
	_finish_bounds()


# Hubs, groups and the tree each group hangs on; the routers.
func _group() -> void:
	var count := _sizes.size()
	_links.clear()
	_children.clear()
	for i in count:
		_links.append(PackedInt32Array())
		_children.append([])
	for cable in _cables:
		if not _valid(cable):
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
	var found_routers: Array[int] = []
	var seeds: Array[int] = []
	for i in count:
		if is_router(i):
			hub_of[i] = i
			found_routers.append(i)
		elif _links[i].size() >= HUB_LINKS:
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
	found_routers.sort_custom(func(a: int, b: int) -> bool: return _before(a, b, 0))
	routers = PackedInt32Array(found_routers)


# Breadth-first from `seeds` at once over the nodes of their region in no group yet.
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
			if hub_of[other] >= 0 or region_of[other] != region_of[node]:
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


func _valid(cable: Vector2i) -> bool:
	var count := _sizes.size()
	return cable.x != cable.y and cable.x >= 0 and cable.y >= 0 and cable.x < count and cable.y < count


# The regions (present: with a hub) a router is cabled into, in its cable order.
func _router_regions(router: int) -> Array[int]:
	var found: Array[int] = []
	for other in _links[router]:
		var region := region_of[other]
		if region >= 0 and not found.has(region) and _has_hub(region):
			found.append(region)
	return found


func _has_hub(region: int) -> bool:
	for hub in hubs:
		if region_of[hub] == region:
			return true
	return false


# Regions and routers left to right: region 0 (else the first present), its first router to the
# right and the next to the left, each region behind a router further out on that side.
func _sequence() -> void:
	_blocks.clear()
	var placed_regions: Dictionary[int, bool] = {}
	var placed_routers: Dictionary[int, bool] = {}
	for region in _region_count:
		if placed_regions.has(region) or not _has_hub(region):
			continue
		# The first region spreads both ways; a region no router joins to it goes on the right.
		var side := 0 if _blocks.is_empty() else 1
		_blocks.append(Vector2i(0, region))
		placed_regions[region] = true
		_expand(region, side, placed_regions, placed_routers)
	for router in routers:
		if not placed_routers.has(router):
			_blocks.append(Vector2i(1, router))
	# Entries: a router's cables into the regions right beside it (from the left first).
	_entries.clear()
	_from_left.clear()
	for region in _region_count:
		_entries.append(PackedInt32Array())
	for from_left: bool in [true, false]:
		for i in _blocks.size():
			if _blocks[i].x != 1:
				continue
			var j := i + 1 if from_left else i - 1
			if j < 0 or j >= _blocks.size() or _blocks[j].x != 0:
				continue
			for k in _cables.size():
				var other := _other_end(k, _blocks[i].y)
				if other >= 0 and region_of[other] == _blocks[j].y:
					_entries[_blocks[j].y].append(k)
					_from_left[k] = from_left


# Places `region`'s routers not placed yet on `side` (0: the first right, the next left, ...) and
# the regions behind them further out, depth first.
func _expand(
	region: int, side: int, placed_regions: Dictionary[int, bool], placed_routers: Dictionary[int, bool]
) -> void:
	var toggle := 1
	for router in routers:
		if placed_routers.has(router) or not _router_regions(router).has(region):
			continue
		var direction := side
		if side == 0:
			direction = toggle
			toggle = -toggle
		placed_routers[router] = true
		_insert(Vector2i(1, router), direction)
		for other in _router_regions(router):
			if placed_regions.has(other):
				continue
			placed_regions[other] = true
			_insert(Vector2i(0, other), direction)
			_expand(other, direction, placed_regions, placed_routers)


func _insert(block: Vector2i, direction: int) -> void:
	if direction < 0:
		_blocks.push_front(block)
	else:
		_blocks.append(block)


# The other end of cable `k` when one end is `node`, else -1.
func _other_end(k: int, node: int) -> int:
	var cable := _cables[k]
	if not _valid(cable):
		return -1
	if cable.x == node:
		return cable.y
	if cable.y == node:
		return cable.x
	return -1


# The cable `k`'s end inside `region`, or -1.
func _inside(k: int, region: int) -> int:
	var cable := _cables[k]
	if region_of[cable.x] == region:
		return cable.x
	return cable.y if region_of[cable.y] == region else -1


# Each region's switch trees: roots first the groups the routers on its left enter by, then the
# groups nothing reaches yet (west first); each hub's child hubs breadth first over the cables between
# two hubs, west first. A router on the right entering a root puts that root last; entering a hub
# inside a tree, it puts that hub's branch last at every level, so its cable comes down the box's
# right side and in above that hub's row without crossing anything.
func _build_trees() -> void:
	_roots.clear()
	_kids.clear()
	_uplink.clear()
	_up_hub.clear()
	var between: Dictionary[int, Array] = {}
	for k in _cables.size():
		var cable := _cables[k]
		if not _valid(cable) or region_of[cable.x] < 0 or region_of[cable.x] != region_of[cable.y]:
			continue
		if not _is_hub(cable.x) or not _is_hub(cable.y) or hub_of[cable.x] == hub_of[cable.y]:
			continue
		for pair: Vector2i in [Vector2i(cable.x, cable.y), Vector2i(cable.y, cable.x)]:
			var list: Array = between.get(pair.x, [])
			list.append(Vector2i(pair.y, k))
			between[pair.x] = list
	for hub: int in between:
		between[hub].sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _before(a.x, b.x, 0))
	var seen: Dictionary[int, bool] = {}
	for region in _region_count:
		var candidates: Array[int] = []
		var right_targets: Array[int] = []
		for k in _entries[region]:
			var hub := hub_of[_inside(k, region)]
			if _from_left[k]:
				candidates.append(hub)
			elif not right_targets.has(hub):
				right_targets.append(hub)
		candidates.append_array(right_targets)
		# Then the hubs cabled to the most other hubs (a building's main switch), west first.
		var members: Array[int] = []
		for hub in hubs:
			if region_of[hub] == region:
				members.append(hub)
		var fan := func(hub: int) -> int: return between.get(hub, []).size()
		members.sort_custom(
			func(a: int, b: int) -> bool:
				return fan.call(a) > fan.call(b) or (fan.call(a) == fan.call(b) and _before(a, b, 0))
		)
		candidates.append_array(members)
		var roots: Array[int] = []
		for root in candidates:
			if not seen.has(root):
				roots.append(root)
				_grow(root, between, seen)
		for target in right_targets:
			var node := target
			while _up_hub.has(node):
				var up := _up_hub[node]
				_kids[up].erase(node)
				_kids[up].append(node)
				node = up
			var lead_by_left := false
			for k in _entries[region]:
				lead_by_left = lead_by_left or (_from_left[k] and hub_of[_inside(k, region)] == node)
			if not lead_by_left:
				roots.erase(node)
				roots.append(node)
		_roots.append(PackedInt32Array(roots))


# The tree from `root`, breadth first (each hub under the hub fewest cables from the root).
func _grow(root: int, between: Dictionary[int, Array], seen: Dictionary[int, bool]) -> void:
	seen[root] = true
	_kids[root] = []
	var queue: Array[int] = [root]
	var head := 0
	while head < queue.size():
		var hub := queue[head]
		head += 1
		for pair: Vector2i in between.get(hub, []):
			if seen.has(pair.x):
				continue
			seen[pair.x] = true
			_kids[pair.x] = []
			_kids[hub].append(pair.x)
			_uplink[pair.x] = pair.y
			_up_hub[pair.x] = hub
			queue.append(pair.x)


# Each region's children per row: the count that fits the whole map in a panel of `aspect` best
# (most per row, so fewest rows, on a tie), the regions with the most groups chosen first.
func _choose_plans(aspect: float) -> void:
	_plans.clear()
	var widest: Array[int] = []
	for region in _region_count:
		var most := 1
		for hub: int in _kids:
			if region_of[hub] == region:
				most = maxi(most, _kids[hub].size())
		widest.append(most)
		_plans.append(_plan(region, most))
	var by_size: Array[int] = []
	for region in _region_count:
		by_size.append(region)
	by_size.sort_custom(
		func(a: int, b: int) -> bool: return widest[a] > widest[b] or (widest[a] == widest[b] and a < b)
	)
	for region in by_size:
		var best := _plans[region]
		var best_score := _score(aspect)
		for per_row in range(widest[region] - 1, 0, -1):
			_plans[region] = _plan(region, per_row)
			var score := _score(aspect)
			if score > best_score + 0.000001:
				best_score = score
				best = _plans[region]
		_plans[region] = best


# The fitted zoom (up to a factor) of the whole map with the current plans.
func _score(aspect: float) -> float:
	var extent := Vector2.ZERO
	for i in _blocks.size():
		extent.x += _block_size(i).x + (_gap(i - 1, i) if i > 0 else 0.0)
		extent.y = maxf(extent.y, _block_size(i).y)
	return minf(aspect / maxf(extent.x, 1.0), 1.0 / maxf(extent.y, 1.0))


func _block_size(i: int) -> Vector2:
	var block := _blocks[i]
	if block.x == 0:
		return _plans[block.y].size
	return Vector2(_slots[block.y].size.x, _router_anchor_y(i) - _anchor + _sizes[block.y].y)


func _gap(i: int, j: int) -> float:
	if _blocks[i].x == 0 and _blocks[j].x == 0:
		return REGION_GAP
	return ROUTER_GAP


# The y of the first free line below `region`'s title (region coordinates).
func _top_free(region: int) -> float:
	if not boxed:
		return 0.0
	var title := _titles[region] if region < _titles.size() else Vector2.ZERO
	return TITLE_INSET.y + title.y + TITLE_GAP


# A router's cable end height: the entry lane it enters the region on its right by (else on its
# left), else the first free line below the titles.
func _router_anchor_y(i: int) -> float:
	var router := _blocks[i].y
	for j: int in [i + 1, i - 1]:
		if j < 0 or j >= _blocks.size() or _blocks[j].x != 0:
			continue
		var plan := _plans[_blocks[j].y]
		for k in _entries[_blocks[j].y]:
			if _other_end(k, router) >= 0 and plan.lane_y.has(k) and not plan.gutter.has(k):
				return plan.lane_y[k]
	var top := 0.0
	for region in _region_count:
		top = maxf(top, _top_free(region))
	return top


# The router cables entering `region` in lanes at its box's top, top lane first: from the left
# onto roots (the farthest root highest), then from the right onto roots (the farthest highest).
func _lane_entries(region: int) -> Array[int]:
	var roots := _roots[region]
	var from_left: Array[int] = []
	var from_right: Array[int] = []
	for k in _entries[region]:
		var hub := hub_of[_inside(k, region)]
		if not roots.has(hub):
			continue
		if _from_left[k]:
			from_left.append(k)
		else:
			from_right.append(k)
	var order := func(a: int, b: int, far_first: int) -> bool:
		var ia := roots.find(hub_of[_inside(a, region)]) * far_first
		var ib := roots.find(hub_of[_inside(b, region)]) * far_first
		return ia < ib or (ia == ib and a < b)
	from_left.sort_custom(func(a: int, b: int) -> bool: return order.call(a, b, -1))
	from_right.sort_custom(func(a: int, b: int) -> bool: return order.call(a, b, 1))
	from_left.append_array(from_right)
	return from_left


# `region`'s switch trees side by side under its entry lanes, each hub's child hubs in rows of
# `per_row` below its group.
func _plan(region: int, per_row: int) -> RegionPlan:
	var plan := RegionPlan.new()
	plan.children_per_row = maxi(per_row, 1)
	var roots := _roots[region]
	if roots.is_empty():
		return plan
	var left := REGION_PAD if boxed else 0.0
	var top := _top_free(region)
	var lanes := _lane_entries(region)
	for i in lanes.size():
		plan.lane_y[lanes[i]] = top + i * LANE_STEP
	if not lanes.is_empty():
		top += (lanes.size() - 1) * LANE_STEP + LANE_GAP
	var x := left
	var bottom := top
	for root in roots:
		var block := _block(root, plan)
		plan.at[root] = Vector2(x - block.position.x, top - block.position.y)
		_place_tree(root, plan)
		x += block.size.x + GROUP_GAP
		bottom = maxf(bottom, top + block.size.y)
	# Router cables onto a hub inside a tree: down the box's side, in above that hub's row.
	for k in _entries[region]:
		var hub := hub_of[_inside(k, region)]
		if plan.lane_y.has(k) or not _up_hub.has(hub):
			continue
		plan.lane_y[k] = plan.bands[_up_hub[hub]][plan.row[hub]]
		plan.gutter[k] = true
	var pad := REGION_PAD if boxed else 0.0
	plan.size = Vector2(x - GROUP_GAP + pad, bottom + pad)
	if boxed and region < _titles.size():
		plan.size.x = maxf(plan.size.x, _titles[region].x + TITLE_INSET.x * 2.0)
	return plan


# `hub`'s block in its group's coordinates (its box's top-centre at the origin): its group, then
# each row of its child hubs' blocks below it, GROUP_GAP apart; one row is centred under the hub,
# several rows start at its group's left with a spine beside them.
func _block(hub: int, plan: RegionPlan) -> Rect2:
	var comb := _group_bounds[hub]
	var kids: Array = _kids.get(hub, [])
	plan.spine[hub] = NAN
	plan.bands[hub] = PackedFloat32Array()
	if kids.is_empty():
		return comb
	var blocks: Dictionary[int, Rect2] = {}
	for child: int in kids:
		blocks[child] = _block(child, plan)
	var rows := ceili(kids.size() / float(plan.children_per_row))
	var spine := comb.position.x - LANE_GAP * 0.5
	var bands := PackedFloat32Array()
	var result := comb
	var y := comb.end.y + LANE_GAP
	for r in rows:
		var row := kids.slice(r * plan.children_per_row, (r + 1) * plan.children_per_row)
		var width := -GROUP_GAP
		for child: int in row:
			width += blocks[child].size.x + GROUP_GAP
		var x := comb.position.x + LANE_GAP * 0.5 if rows > 1 else -width * 0.5
		bands.append(y)
		var top := y + LANE_GAP
		var bottom := top
		for child: int in row:
			var block := blocks[child]
			plan.local[child] = Vector2(x - block.position.x, top - block.position.y)
			plan.row[child] = r
			result = result.merge(Rect2(block.position + plan.local[child], block.size))
			x += block.size.x + GROUP_GAP
			bottom = maxf(bottom, top + block.size.y)
		y = bottom + LANE_GAP
	if rows > 1:
		result = result.expand(Vector2(spine - LANE_GAP * 0.5, comb.position.y))
		plan.spine[hub] = spine
	plan.bands[hub] = bands
	return result


# `hub`'s subtree from block to region coordinates (`plan.at[hub]` set).
func _place_tree(hub: int, plan: RegionPlan) -> void:
	var at := plan.at[hub]
	if not is_nan(plan.spine[hub]):
		plan.spine[hub] += at.x
	var bands := plan.bands[hub]
	for r in bands.size():
		bands[r] += at.y
	plan.bands[hub] = bands
	for child: int in _kids.get(hub, []):
		plan.at[child] = at + plan.local[child]
		_place_tree(child, plan)


func _is_hub(node: int) -> bool:
	return hub_of[node] == node and not is_router(node)


# Every block at its place: regions top-aligned left to right, routers between them.
func _apply() -> void:
	_origins.clear()
	_origins.resize(_region_count)
	_origins.fill(Vector2.ZERO)
	var placed: Array[int] = []
	var x := 0.0
	for i in _blocks.size():
		if i > 0:
			x += _gap(i - 1, i)
		var block := _blocks[i]
		if block.x == 0:
			var plan := _plans[block.y]
			_origins[block.y] = Vector2(x, 0.0)
			region_rects[block.y] = Rect2(Vector2(x, 0.0), plan.size)
			title_positions[block.y] = Vector2(x, 0.0) + TITLE_INSET
			for root in _roots[block.y]:
				_apply_tree(root, plan, Vector2(x, 0.0), placed)
			x += plan.size.x
		else:
			var router := block.y
			var slot := _slots[router]
			var at := Vector2(x - slot.position.x, _router_anchor_y(i) - _anchor)
			rects[router].position += at
			_slots[router].position += at
			x += slot.size.x
	hubs = PackedInt32Array(placed)
	var ordered: Array[int] = []
	for block in _blocks:
		if block.x == 1:
			ordered.append(block.y)
	routers = PackedInt32Array(ordered)


func _apply_tree(hub: int, plan: RegionPlan, origin: Vector2, placed: Array[int]) -> void:
	placed.append(hub)
	_shift_group(hub, plan.at[hub] + origin)
	for child: int in _kids.get(hub, []):
		_apply_tree(child, plan, origin, placed)


func _shift_group(hub: int, shift: Vector2) -> void:
	for i in rects.size():
		if hub_of[i] == hub and not is_router(i):
			rects[i].position += shift
			_slots[i].position += shift
			_child_bus[i] += shift.x
	_group_bounds[hub] = Rect2(_group_bounds[hub].position + shift, _group_bounds[hub].size)


func _route() -> void:
	routes.clear()
	extra = PackedInt32Array()
	for k in _cables.size():
		var cable := _cables[k]
		var route := PackedVector2Array()
		if not _valid(cable):
			routes.append(route)
			continue
		var a := cable.x
		var b := cable.y
		if parent[b] == a:
			route = _tree_route(a, b)
		elif parent[a] == b:
			route = _tree_route(b, a)
		elif hub_of[a] == hub_of[b]:
			route = PackedVector2Array([_attach(a), _attach(b)])
		elif _uplink.get(b, -1) == k:
			route = _uplink_route(a, b)
		elif _uplink.get(a, -1) == k:
			route = _uplink_route(b, a)
		elif _entry_region(k) >= 0:
			route = _entry_route(k, _entry_region(k))
		else:
			route = _global_route(a, b, -LANE_GAP - extra.size() * LANE_STEP)
			extra.append(k)
		routes.append(_simplified(route))


# From hub `up` down its bus to the line its row of child hubs hangs from (through its spine for a
# lower row), along it and down onto hub `child`.
func _uplink_route(up: int, child: int) -> PackedVector2Array:
	var region := region_of[up]
	var plan := _plans[region]
	var origin := _origins[region]
	var bands := plan.bands[up]
	var band := bands[plan.row[child]] + origin.y
	var from := _centre(up)
	var to := _centre(child)
	var top := rects[child].position.y
	if plan.row[child] == 0 or is_nan(plan.spine[up]):
		return PackedVector2Array([from, Vector2(from.x, band), Vector2(to.x, band), Vector2(to.x, top), to])
	var first := bands[0] + origin.y
	var spine := plan.spine[up] + origin.x
	return PackedVector2Array(
		[
			from,
			Vector2(from.x, first),
			Vector2(spine, first),
			Vector2(spine, band),
			Vector2(to.x, band),
			Vector2(to.x, top),
			to,
		]
	)


# The region router cable `k` enters (from a router right beside it), or -1.
func _entry_region(k: int) -> int:
	for region in _entries.size():
		if _entries[region].has(k):
			return region
	return -1


# From the router beside `region` into the box: along an entry lane at its top and down onto a
# root, or down the box's side and in above the row of a hub inside a tree.
func _entry_route(k: int, region: int) -> PackedVector2Array:
	var cable := _cables[k]
	var router := cable.x if is_router(cable.x) else cable.y
	var target := cable.y if router == cable.x else cable.x
	var plan := _plans[region]
	var lane_y := plan.lane_y[k] + _origins[region].y
	var box := region_rects[region]
	var start := _centre(router)
	var from_left := start.x < box.position.x
	var turn := box.position.x - ROUTER_GAP * 0.5 if from_left else box.end.x + ROUTER_GAP * 0.5
	if plan.gutter.has(k):
		turn = box.position.x + REGION_PAD * 0.5 if from_left else box.end.x - REGION_PAD * 0.5
	var route := PackedVector2Array([start, Vector2(turn, start.y), Vector2(turn, lane_y)])
	var target_x := rects[target].get_center().x if _is_hub(target) else _placed_gutter_x(target)
	var back := _rise(target, target_x, lane_y)
	back.reverse()
	route.append_array(back)
	return route


# Up to a lane above every box at `lane_y` (before the shift to the origin) and down.
func _global_route(a: int, b: int, lane_y: float) -> PackedVector2Array:
	var xa := _centre(a).x if sides[a] == 0 else _placed_gutter_x(a)
	var xb := _centre(b).x if sides[b] == 0 else _placed_gutter_x(b)
	var route := _rise(a, xa, lane_y)
	var back := _rise(b, xb, lane_y)
	back.reverse()
	route.append_array(back)
	return route


func _placed_gutter_x(node: int) -> float:
	var group := _group_bounds[hub_of[node]]
	return group.end.x + LANE_GAP if sides[node] >= 0 else group.position.x - LANE_GAP


# From `node` to a lane at `lane_y` met at `lane_x`: a hub or router straight up from its top when
# the lane is met above it, else out of its far side (a hub: its centre) across to `lane_x` and
# along it up or down.
func _rise(node: int, lane_x: float, lane_y: float) -> PackedVector2Array:
	var centre := _centre(node)
	if sides[node] == 0 and absf(lane_x - centre.x) < 0.01 and lane_y < rects[node].position.y:
		return PackedVector2Array([centre, Vector2(centre.x, rects[node].position.y), Vector2(centre.x, lane_y)])
	var start := centre if sides[node] == 0 else _attach(node, true)
	return PackedVector2Array([start, Vector2(lane_x, start.y), Vector2(lane_x, lane_y)])


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


# Everything (boxes, slots, routes) moved so the bounds start at the origin.
func _finish_bounds() -> void:
	var first := true
	for region in _region_count:
		if region_rects[region].has_area():
			bounds = region_rects[region] if first else bounds.merge(region_rects[region])
			first = false
	for i in rects.size():
		bounds = _slots[i] if first else bounds.merge(_slots[i])
		first = false
	for route in routes:
		for point in route:
			bounds = bounds.expand(point)
	var shift := -bounds.position
	for i in rects.size():
		rects[i].position += shift
	for k in routes.size():
		for p in routes[k].size():
			routes[k][p] += shift
	for region in _region_count:
		if region_rects[region].has_area():
			region_rects[region].position += shift
			title_positions[region] += shift
	bounds.position = Vector2.ZERO


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
