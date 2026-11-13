class_name NetworkSwitchTrees
extends RefCounted
## NetworkLayout's second pass (ADR 0099, 0112 amendment): the order of the regions and routers
## left to right, and each region's switch trees. Regions and routers: region 0 (else the first
## present) spreads both ways, its first router on its right and the next on its left, each region
## behind a router further out on that side; a router whose other region is hidden stands beside
## its one region. The router cables into the regions right beside them are the regions' entries.
## Switch trees: the cables between two hubs of a region make a tree (breadth first from each root,
## west first); its roots are the hubs the routers on its left enter by, then the hubs cabled to the
## most other hubs; a router on the right puts its branch last. Writes the shared state's `blocks`,
## `entries`, `from_left`, `roots`, `kids`, `uplink` and `up_hub`.

var _state: NetworkLayoutState
var _layout: NetworkLayout


func _init(state: NetworkLayoutState) -> void:
	_state = state
	_layout = state.layout


func run() -> void:
	_sequence()
	_build_trees()


# The regions (present: with a hub) a router is cabled into, in its cable order.
func _router_regions(router: int) -> Array[int]:
	var found: Array[int] = []
	for other in _state.links[router]:
		var region := _layout.region_of[other]
		if region >= 0 and not found.has(region) and _has_hub(region):
			found.append(region)
	return found


func _has_hub(region: int) -> bool:
	for hub in _layout.hubs:
		if _layout.region_of[hub] == region:
			return true
	return false


# Regions and routers left to right: region 0 (else the first present), its first router to the
# right and the next to the left, each region behind a router further out on that side.
func _sequence() -> void:
	var blocks := _state.blocks
	blocks.clear()
	var placed_regions: Dictionary[int, bool] = {}
	var placed_routers: Dictionary[int, bool] = {}
	for region in _state.region_count:
		if placed_regions.has(region) or not _has_hub(region):
			continue
		# The first region spreads both ways; a region no router joins to it goes on the right.
		var side := 0 if blocks.is_empty() else 1
		blocks.append(Vector2i(0, region))
		placed_regions[region] = true
		_expand(region, side, placed_regions, placed_routers)
	for router in _layout.routers:
		if not placed_routers.has(router):
			blocks.append(Vector2i(1, router))
	# Entries: a router's cables into the regions right beside it (from the left first).
	_state.entries.clear()
	_state.from_left.clear()
	for region in _state.region_count:
		_state.entries.append(PackedInt32Array())
	for from_left: bool in [true, false]:
		for i in blocks.size():
			if blocks[i].x != 1:
				continue
			var j := i + 1 if from_left else i - 1
			if j < 0 or j >= blocks.size() or blocks[j].x != 0:
				continue
			for k in _state.cables.size():
				var other := _state.other_end(k, blocks[i].y)
				if other >= 0 and _layout.region_of[other] == blocks[j].y:
					_state.entries[blocks[j].y].append(k)
					_state.from_left[k] = from_left


# Places `region`'s routers not placed yet on `side` (0: the first right, the next left, ...) and
# the regions behind them further out, depth first.
func _expand(
	region: int, side: int, placed_regions: Dictionary[int, bool], placed_routers: Dictionary[int, bool]
) -> void:
	var toggle := 1
	for router in _layout.routers:
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
		_state.blocks.push_front(block)
	else:
		_state.blocks.append(block)


# Each region's switch trees: roots first the groups the routers on its left enter by, then the
# groups nothing reaches yet (west first); each hub's child hubs breadth first over the cables between
# two hubs, west first. A router on the right entering a root puts that root last; entering a hub
# inside a tree, it puts that hub's branch last at every level, so its cable comes down the box's
# right side and in above that hub's row without crossing anything.
func _build_trees() -> void:
	var kids := _state.kids
	_state.roots.clear()
	kids.clear()
	_state.uplink.clear()
	_state.up_hub.clear()
	var between := _hub_links()
	var seen: Dictionary[int, bool] = {}
	for region in _state.region_count:
		_state.roots.append(PackedInt32Array(_region_roots(region, between, seen)))


# Region `region`'s roots, in order: the hubs its entries reach (from the left first), then the
# hubs cabled to the most other hubs; each root's tree grown (_grow()).
func _region_roots(region: int, between: Dictionary[int, Array], seen: Dictionary[int, bool]) -> Array[int]:
	var region_of := _layout.region_of
	var hub_of := _layout.hub_of
	var kids := _state.kids
	var entries := _state.entries[region]
	var candidates: Array[int] = []
	var right_targets: Array[int] = []
	for k in entries:
		var hub := hub_of[_state.inside(k, region)]
		if _state.from_left[k]:
			candidates.append(hub)
		elif not right_targets.has(hub):
			right_targets.append(hub)
	candidates.append_array(right_targets)
	# Then the hubs cabled to the most other hubs (a building's main switch), west first.
	var members: Array[int] = []
	for hub in _layout.hubs:
		if region_of[hub] == region:
			members.append(hub)
	var fan := func(hub: int) -> int: return between.get(hub, []).size()
	members.sort_custom(
		func(a: int, b: int) -> bool:
			return fan.call(a) > fan.call(b) or (fan.call(a) == fan.call(b) and _state.before(a, b, 0))
	)
	candidates.append_array(members)
	var roots: Array[int] = []
	for root in candidates:
		if not seen.has(root):
			roots.append(root)
			_grow(root, between, seen)
	for target in right_targets:
		var node := target
		while _state.up_hub.has(node):
			var up := _state.up_hub[node]
			kids[up].erase(node)
			kids[up].append(node)
			node = up
		var lead_by_left := false
		for k in entries:
			lead_by_left = lead_by_left or (_state.from_left[k] and hub_of[_state.inside(k, region)] == node)
		if not lead_by_left:
			roots.erase(node)
			roots.append(node)
	return roots


# Hub -> the hubs it is cabled to in its region, [hub, cable index] each, in order.
func _hub_links() -> Dictionary[int, Array]:
	var region_of := _layout.region_of
	var hub_of := _layout.hub_of
	var between: Dictionary[int, Array] = {}
	for k in _state.cables.size():
		var cable := _state.cables[k]
		if not _state.valid(cable) or region_of[cable.x] < 0 or region_of[cable.x] != region_of[cable.y]:
			continue
		if not _state.is_hub(cable.x) or not _state.is_hub(cable.y) or hub_of[cable.x] == hub_of[cable.y]:
			continue
		for pair: Vector2i in [Vector2i(cable.x, cable.y), Vector2i(cable.y, cable.x)]:
			var list: Array = between.get(pair.x, [])
			list.append(Vector2i(pair.y, k))
			between[pair.x] = list
	for hub: int in between:
		between[hub].sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _state.before(a.x, b.x, 0))
	return between


# The tree from `root`, breadth first (each hub under the hub fewest cables from the root).
func _grow(root: int, between: Dictionary[int, Array], seen: Dictionary[int, bool]) -> void:
	var kids := _state.kids
	seen[root] = true
	kids[root] = []
	var queue: Array[int] = [root]
	var head := 0
	while head < queue.size():
		var hub := queue[head]
		head += 1
		for pair: Vector2i in between.get(hub, []):
			if seen.has(pair.x):
				continue
			seen[pair.x] = true
			kids[pair.x] = []
			kids[hub].append(pair.x)
			_state.uplink[pair.x] = pair.y
			_state.up_hub[pair.x] = hub
			queue.append(pair.x)
