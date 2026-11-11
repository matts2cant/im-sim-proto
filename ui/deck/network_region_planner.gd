class_name NetworkRegionPlanner
extends RefCounted
## NetworkLayout's third pass (ADR 0099, 0112 amendment): each region's plan and every block's
## place. A region's plan stands its switch trees side by side under its entry lanes (REGION_PAD
## around them, its title at the top-left); each hub's block is its group with its child hubs'
## blocks in rows below it (one row centred under it; several rows start at its left with a spine
## beside them). children_per_row is the count that fits the whole map in a panel of `aspect` best
## (fewest rows on a tie, the regions with the most groups chosen first). Then the regions stand
## side by side, top-aligned, routers between them at their entry lane's height. Writes the shared
## state's `plans` and `origins`, and the layout's boxes, `region_rects`, `title_positions`, `hubs`
## (in group order) and `routers` (left to right).

var _state: NetworkLayoutState
var _layout: NetworkLayout


func _init(state: NetworkLayoutState) -> void:
	_state = state
	_layout = state.layout


## Chooses each region's plan for a panel of `aspect` (width / height), then places every block.
func run(aspect: float) -> void:
	_choose_plans(aspect)
	_apply()


# Each region's children per row: the count that fits the whole map in a panel of `aspect` best
# (most per row, so fewest rows, on a tie), the regions with the most groups chosen first.
func _choose_plans(aspect: float) -> void:
	var plans := _state.plans
	plans.clear()
	var widest: Array[int] = []
	for region in _state.region_count:
		var most := 1
		for hub: int in _state.kids:
			if _layout.region_of[hub] == region:
				most = maxi(most, _state.kids[hub].size())
		widest.append(most)
		plans.append(_plan(region, most))
	var by_size: Array[int] = []
	for region in _state.region_count:
		by_size.append(region)
	by_size.sort_custom(
		func(a: int, b: int) -> bool: return widest[a] > widest[b] or (widest[a] == widest[b] and a < b)
	)
	for region in by_size:
		var best := plans[region]
		var best_score := _score(aspect)
		for per_row in range(widest[region] - 1, 0, -1):
			plans[region] = _plan(region, per_row)
			var score := _score(aspect)
			if score > best_score + 0.000001:
				best_score = score
				best = plans[region]
		plans[region] = best


# The fitted zoom (up to a factor) of the whole map with the current plans.
func _score(aspect: float) -> float:
	var extent := Vector2.ZERO
	for i in _state.blocks.size():
		extent.x += _block_size(i).x + (_gap(i - 1, i) if i > 0 else 0.0)
		extent.y = maxf(extent.y, _block_size(i).y)
	return minf(aspect / maxf(extent.x, 1.0), 1.0 / maxf(extent.y, 1.0))


func _block_size(i: int) -> Vector2:
	var block := _state.blocks[i]
	if block.x == 0:
		return _state.plans[block.y].size
	return Vector2(_state.slots[block.y].size.x, _router_anchor_y(i) - _state.anchor + _state.sizes[block.y].y)


func _gap(i: int, j: int) -> float:
	if _state.blocks[i].x == 0 and _state.blocks[j].x == 0:
		return NetworkLayout.REGION_GAP
	return NetworkLayout.ROUTER_GAP


# The y of the first free line below `region`'s title (region coordinates).
func _top_free(region: int) -> float:
	if not _layout.boxed:
		return 0.0
	var title := _state.titles[region] if region < _state.titles.size() else Vector2.ZERO
	return NetworkLayout.TITLE_INSET.y + title.y + NetworkLayout.TITLE_GAP


# A router's cable end height: the entry lane it enters the region on its right by (else on its
# left), else the first free line below the titles.
func _router_anchor_y(i: int) -> float:
	var blocks := _state.blocks
	var router := blocks[i].y
	for j: int in [i + 1, i - 1]:
		if j < 0 or j >= blocks.size() or blocks[j].x != 0:
			continue
		var plan := _state.plans[blocks[j].y]
		for k in _state.entries[blocks[j].y]:
			if _state.other_end(k, router) >= 0 and plan.lane_y.has(k) and not plan.gutter.has(k):
				return plan.lane_y[k]
	var top := 0.0
	for region in _state.region_count:
		top = maxf(top, _top_free(region))
	return top


# The router cables entering `region` in lanes at its box's top, top lane first: from the left
# onto roots (the farthest root highest), then from the right onto roots (the farthest highest).
func _lane_entries(region: int) -> Array[int]:
	var roots := _state.roots[region]
	var hub_of := _layout.hub_of
	var from_left: Array[int] = []
	var from_right: Array[int] = []
	for k in _state.entries[region]:
		var hub := hub_of[_state.inside(k, region)]
		if not roots.has(hub):
			continue
		if _state.from_left[k]:
			from_left.append(k)
		else:
			from_right.append(k)
	var order := func(a: int, b: int, far_first: int) -> bool:
		var ia := roots.find(hub_of[_state.inside(a, region)]) * far_first
		var ib := roots.find(hub_of[_state.inside(b, region)]) * far_first
		return ia < ib or (ia == ib and a < b)
	from_left.sort_custom(func(a: int, b: int) -> bool: return order.call(a, b, -1))
	from_right.sort_custom(func(a: int, b: int) -> bool: return order.call(a, b, 1))
	from_left.append_array(from_right)
	return from_left


# `region`'s switch trees side by side under its entry lanes, each hub's child hubs in rows of
# `per_row` below its group.
func _plan(region: int, per_row: int) -> NetworkLayoutState.RegionPlan:
	var plan := NetworkLayoutState.RegionPlan.new()
	plan.children_per_row = maxi(per_row, 1)
	var roots := _state.roots[region]
	if roots.is_empty():
		return plan
	var boxed := _layout.boxed
	var left := NetworkLayout.REGION_PAD if boxed else 0.0
	var top := _top_free(region)
	var lanes := _lane_entries(region)
	for i in lanes.size():
		plan.lane_y[lanes[i]] = top + i * NetworkLayout.LANE_STEP
	if not lanes.is_empty():
		top += (lanes.size() - 1) * NetworkLayout.LANE_STEP + NetworkLayout.LANE_GAP
	var x := left
	var bottom := top
	for root in roots:
		var block := _block(root, plan)
		plan.at[root] = Vector2(x - block.position.x, top - block.position.y)
		_place_tree(root, plan)
		x += block.size.x + NetworkLayout.GROUP_GAP
		bottom = maxf(bottom, top + block.size.y)
	# Router cables onto a hub inside a tree: down the box's side, in above that hub's row.
	for k in _state.entries[region]:
		var hub := _layout.hub_of[_state.inside(k, region)]
		if plan.lane_y.has(k) or not _state.up_hub.has(hub):
			continue
		plan.lane_y[k] = plan.bands[_state.up_hub[hub]][plan.row[hub]]
		plan.gutter[k] = true
	var pad := NetworkLayout.REGION_PAD if boxed else 0.0
	plan.size = Vector2(x - NetworkLayout.GROUP_GAP + pad, bottom + pad)
	if boxed and region < _state.titles.size():
		plan.size.x = maxf(plan.size.x, _state.titles[region].x + NetworkLayout.TITLE_INSET.x * 2.0)
	return plan


# `hub`'s block in its group's coordinates (its box's top-centre at the origin): its group, then
# each row of its child hubs' blocks below it, GROUP_GAP apart; one row is centred under the hub,
# several rows start at its group's left with a spine beside them.
func _block(hub: int, plan: NetworkLayoutState.RegionPlan) -> Rect2:
	const LANE_GAP := NetworkLayout.LANE_GAP
	const GROUP_GAP := NetworkLayout.GROUP_GAP
	var comb := _state.group_bounds[hub]
	var kids: Array = _state.kids.get(hub, [])
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
		# One row: its first and last child hubs centred on the hub's bus (one child right under it).
		var x := comb.position.x + LANE_GAP * 0.5
		if rows == 1:
			var first := -blocks[row[0]].position.x
			var last := first
			var cursor := 0.0
			for child: int in row:
				last = cursor - blocks[child].position.x
				cursor += blocks[child].size.x + GROUP_GAP
			x = -(first + last) * 0.5
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
func _place_tree(hub: int, plan: NetworkLayoutState.RegionPlan) -> void:
	var at := plan.at[hub]
	if not is_nan(plan.spine[hub]):
		plan.spine[hub] += at.x
	var bands := plan.bands[hub]
	for r in bands.size():
		bands[r] += at.y
	plan.bands[hub] = bands
	for child: int in _state.kids.get(hub, []):
		plan.at[child] = at + plan.local[child]
		_place_tree(child, plan)


# Every block at its place: regions top-aligned left to right, routers between them.
func _apply() -> void:
	var origins := _state.origins
	origins.clear()
	origins.resize(_state.region_count)
	origins.fill(Vector2.ZERO)
	var placed: Array[int] = []
	var x := 0.0
	var blocks := _state.blocks
	for i in blocks.size():
		if i > 0:
			x += _gap(i - 1, i)
		var block := blocks[i]
		if block.x == 0:
			var plan := _state.plans[block.y]
			origins[block.y] = Vector2(x, 0.0)
			_layout.region_rects[block.y] = Rect2(Vector2(x, 0.0), plan.size)
			_layout.title_positions[block.y] = Vector2(x, 0.0) + NetworkLayout.TITLE_INSET
			for root in _state.roots[block.y]:
				_apply_tree(root, plan, Vector2(x, 0.0), placed)
			x += plan.size.x
		else:
			var router := block.y
			var slot := _state.slots[router]
			var at := Vector2(x - slot.position.x, _router_anchor_y(i) - _state.anchor)
			_layout.rects[router].position += at
			_state.slots[router].position += at
			x += slot.size.x
	_layout.hubs = PackedInt32Array(placed)
	var ordered: Array[int] = []
	for block in blocks:
		if block.x == 1:
			ordered.append(block.y)
	_layout.routers = PackedInt32Array(ordered)


func _apply_tree(hub: int, plan: NetworkLayoutState.RegionPlan, origin: Vector2, placed: Array[int]) -> void:
	placed.append(hub)
	_shift_group(hub, plan.at[hub] + origin)
	for child: int in _state.kids.get(hub, []):
		_apply_tree(child, plan, origin, placed)


func _shift_group(hub: int, shift: Vector2) -> void:
	for i in _layout.rects.size():
		if _layout.hub_of[i] == hub and not _layout.is_router(i):
			_layout.rects[i].position += shift
			_state.slots[i].position += shift
			_state.child_bus[i] += shift.x
	var group := _state.group_bounds[hub]
	_state.group_bounds[hub] = Rect2(group.position + shift, group.size)
