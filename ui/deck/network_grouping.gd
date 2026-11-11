class_name NetworkGrouping
extends RefCounted
## NetworkLayout's first pass (ADR 0099, 0112 amendment): the groups and their combs, in group
## coordinates. Finds the hubs (HUB_LINKS cables or more; else a region's or a part's best-cabled
## device), hangs every other device on the hub of its region fewest cables away (an indented tree:
## `parent`, `hub_of`), sorts out the routers, and places each group as a comb: its hub on top, its
## devices in two columns down a bus (west half left, east half right, each north first), a hanging
## device one column further out. Writes `rects`, `sides`, `hub_of`, `parent`, `hubs` and `routers`
## of the layout, and the links, trees, slots, child buses and group bounds of the shared state.

var _state: NetworkLayoutState
var _layout: NetworkLayout


func _init(state: NetworkLayoutState) -> void:
	_state = state
	_layout = state.layout


## Groups the nodes, places the routers' boxes at the origin and each group's comb.
func run() -> void:
	_group()
	var sizes := _state.sizes
	for i in sizes.size():
		if _layout.is_router(i):
			_layout.rects[i] = Rect2(Vector2(-sizes[i].x * 0.5, 0.0), sizes[i])
			var width := _state.rounded(sizes[i].x)
			_state.slots[i] = Rect2(Vector2(-width * 0.5, 0.0), Vector2(width, sizes[i].y))
	for hub in _layout.hubs:
		_place_group(hub)


# Hubs, groups and the tree each group hangs on; the routers.
func _group() -> void:
	var count := _state.sizes.size()
	var links := _state.links
	links.clear()
	_state.children.clear()
	for i in count:
		links.append(PackedInt32Array())
		_state.children.append([])
	for cable in _state.cables:
		if not _state.valid(cable):
			continue
		if not links[cable.x].has(cable.y):
			links[cable.x].append(cable.y)
			links[cable.y].append(cable.x)
	for i in count:
		links[i].sort()
	_layout.hub_of.resize(count)
	_layout.hub_of.fill(-1)
	_layout.parent.resize(count)
	_layout.parent.fill(-1)
	_state.depth.resize(count)
	_state.depth.fill(0)
	var found_routers: Array[int] = []
	var seeds: Array[int] = []
	for i in count:
		if _layout.is_router(i):
			_layout.hub_of[i] = i
			found_routers.append(i)
		elif links[i].size() >= NetworkLayout.HUB_LINKS:
			seeds.append(i)
	var found: Array[int] = []
	while true:
		_spread(seeds, found)
		var next := -1
		for i in count:
			if _layout.hub_of[i] < 0 and (next < 0 or links[i].size() > links[next].size()):
				next = i
		if next < 0:
			break
		seeds = [next]
	_layout.hubs = PackedInt32Array(found)
	found_routers.sort_custom(func(a: int, b: int) -> bool: return _state.before(a, b, 0))
	_layout.routers = PackedInt32Array(found_routers)


# Breadth-first from `seeds` at once over the nodes of their region in no group yet.
func _spread(seeds: Array[int], found: Array[int]) -> void:
	var queue: Array[int] = []
	for start in seeds:
		_layout.hub_of[start] = start
		found.append(start)
		queue.append(start)
	var head := 0
	while head < queue.size():
		var node := queue[head]
		head += 1
		for other in _state.links[node]:
			if _layout.hub_of[other] >= 0 or _layout.region_of[other] != _layout.region_of[node]:
				continue
			_layout.hub_of[other] = _layout.hub_of[node]
			_layout.parent[other] = node
			_state.depth[other] = _state.depth[node] + 1
			_state.children[node].append(other)
			queue.append(other)


# The comb of `hub` in group coordinates: the hub's box top-centre at the origin.
func _place_group(hub: int) -> void:
	var sizes := _state.sizes
	_layout.rects[hub] = Rect2(Vector2(-sizes[hub].x * 0.5, 0.0), sizes[hub])
	var hub_width := _state.rounded(sizes[hub].x)
	_state.slots[hub] = Rect2(Vector2(-hub_width * 0.5, 0.0), Vector2(hub_width, sizes[hub].y))
	var members: Array[int] = []
	members.assign(_state.children[hub])
	members.sort_custom(func(a: int, b: int) -> bool: return _state.before(a, b, 0))
	var half := floori(members.size() * 0.5)
	var left: Array[int] = []
	left.assign(members.slice(0, half))
	var right: Array[int] = []
	right.assign(members.slice(half))
	var top := sizes[hub].y + NetworkLayout.HUB_GAP
	for side: int in [-1, 1]:
		var column: Array[int] = left if side < 0 else right
		column.sort_custom(func(a: int, b: int) -> bool: return _state.before(a, b, 2))
		var widths: Dictionary[int, float] = {}
		for member in column:
			_measure(member, widths)
		var edges: Dictionary[int, float] = {1: NetworkLayout.STUB}
		for depth in range(2, widths.size() + 2):
			edges[depth] = edges[depth - 1] + widths.get(depth - 1, 0.0) + NetworkLayout.COLUMN_GAP
		var y := top
		for member in column:
			y = _place_subtree(member, side, y, edges, widths) + NetworkLayout.ROW_GAP
	# From the columns' rounded widths: a status change within a step does not move the group.
	var group := _state.slots[hub]
	for i in _layout.rects.size():
		if _layout.hub_of[i] == hub:
			group = group.merge(_state.slots[i])
	_state.group_bounds[hub] = group


# The widest box (rounded up) at each depth of `node`'s subtree.
func _measure(node: int, widths: Dictionary[int, float]) -> void:
	var width := _state.rounded(_state.sizes[node].x)
	var depth := _state.depth[node]
	widths[depth] = maxf(widths.get(depth, 0.0), width)
	for child: int in _state.children[node]:
		_measure(child, widths)


# Places `node` at row `y` on `side` and its subtree beside and below it; returns the bottom.
func _place_subtree(
	node: int, side: int, y: float, edges: Dictionary[int, float], widths: Dictionary[int, float]
) -> float:
	var node_size := _state.sizes[node]
	var depth := _state.depth[node]
	var edge: float = edges[depth]
	var x := edge if side > 0 else -edge - node_size.x
	_layout.rects[node] = Rect2(Vector2(x, y), node_size)
	var slot_width: float = widths.get(depth, 0.0)
	_state.slots[node] = Rect2(Vector2(edge if side > 0 else -edge - slot_width, y), Vector2(slot_width, node_size.y))
	_layout.sides[node] = side
	_state.child_bus[node] = side * (edge + widths.get(depth, 0.0) + NetworkLayout.COLUMN_GAP * 0.5)
	var bottom := y + node_size.y
	var row := y
	var kids: Array[int] = []
	kids.assign(_state.children[node])
	kids.sort_custom(func(a: int, b: int) -> bool: return _state.before(a, b, 2))
	for child in kids:
		var end := _place_subtree(child, side, row, edges, widths)
		bottom = maxf(bottom, end)
		row = end + NetworkLayout.ROW_GAP
	return bottom
