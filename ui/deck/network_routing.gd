class_name NetworkRouting
extends RefCounted
## NetworkLayout's last pass (ADR 0099, 0112 amendment): every cable's route, then the bounds.
## A cable to a hanging device runs down its bus and across to its box; a cable from a hub to a
## child hub runs down the hub's bus below its group (through the spine for a lower row), along the
## line the child's row hangs from and down onto it. A router's cable enters the region beside it in
## its entry lane and drops onto a root, or runs down the box's side and in above the row of a hub
## inside a tree. Anything else is `extra`: lanes above every box, drawn last. Cables of one group
## off its tree are straight lines. Then everything moves so `bounds` starts at the origin.
## Writes the layout's `routes`, `extra` and `bounds` (and shifts its boxes and titles).

var _state: NetworkLayoutState
var _layout: NetworkLayout


func _init(state: NetworkLayoutState) -> void:
	_state = state
	_layout = state.layout


func run() -> void:
	_route()
	_finish_bounds()


func _route() -> void:
	var parent := _layout.parent
	var hub_of := _layout.hub_of
	var uplink := _state.uplink
	_layout.routes.clear()
	_layout.extra = PackedInt32Array()
	for k in _state.cables.size():
		var cable := _state.cables[k]
		var route := PackedVector2Array()
		if not _state.valid(cable):
			_layout.routes.append(route)
			continue
		var a := cable.x
		var b := cable.y
		if parent[b] == a:
			route = _tree_route(a, b)
		elif parent[a] == b:
			route = _tree_route(b, a)
		elif hub_of[a] == hub_of[b]:
			route = PackedVector2Array([_attach(a), _attach(b)])
		elif uplink.get(b, -1) == k:
			route = _uplink_route(a, b)
		elif uplink.get(a, -1) == k:
			route = _uplink_route(b, a)
		elif _entry_region(k) >= 0:
			route = _entry_route(k, _entry_region(k))
		else:
			route = _global_route(a, b, -NetworkLayout.LANE_GAP - _layout.extra.size() * NetworkLayout.LANE_STEP)
			_layout.extra.append(k)
		_layout.routes.append(_simplified(route))


# From hub `up` down its bus to the line its row of child hubs hangs from (through its spine for a
# lower row), along it and down onto hub `child`.
func _uplink_route(up: int, child: int) -> PackedVector2Array:
	var region := _layout.region_of[up]
	var plan := _state.plans[region]
	var origin := _state.origins[region]
	var bands := plan.bands[up]
	var band := bands[plan.row[child]] + origin.y
	var from := _centre(up)
	var to := _centre(child)
	var top := _layout.rects[child].position.y
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
	for region in _state.entries.size():
		if _state.entries[region].has(k):
			return region
	return -1


# From the router beside `region` into the box: along an entry lane at its top and down onto a
# root, or down the box's side and in above the row of a hub inside a tree.
func _entry_route(k: int, region: int) -> PackedVector2Array:
	const ROUTER_GAP := NetworkLayout.ROUTER_GAP
	const REGION_PAD := NetworkLayout.REGION_PAD
	var cable := _state.cables[k]
	var router := cable.x if _layout.is_router(cable.x) else cable.y
	var target := cable.y if router == cable.x else cable.x
	var plan := _state.plans[region]
	var lane_y := plan.lane_y[k] + _state.origins[region].y
	var box := _layout.region_rects[region]
	var start := _centre(router)
	var from_left := start.x < box.position.x
	var turn := box.position.x - ROUTER_GAP * 0.5 if from_left else box.end.x + ROUTER_GAP * 0.5
	if plan.gutter.has(k):
		turn = box.position.x + REGION_PAD * 0.5 if from_left else box.end.x - REGION_PAD * 0.5
	var route := PackedVector2Array([start, Vector2(turn, start.y), Vector2(turn, lane_y)])
	var target_x := _layout.rects[target].get_center().x if _state.is_hub(target) else _placed_gutter_x(target)
	var back := _rise(target, target_x, lane_y)
	back.reverse()
	route.append_array(back)
	return route


# Up to a lane above every box at `lane_y` (before the shift to the origin) and down.
func _global_route(a: int, b: int, lane_y: float) -> PackedVector2Array:
	var xa := _centre(a).x if _layout.sides[a] == 0 else _placed_gutter_x(a)
	var xb := _centre(b).x if _layout.sides[b] == 0 else _placed_gutter_x(b)
	var route := _rise(a, xa, lane_y)
	var back := _rise(b, xb, lane_y)
	back.reverse()
	route.append_array(back)
	return route


func _placed_gutter_x(node: int) -> float:
	var group := _state.group_bounds[_layout.hub_of[node]]
	if _layout.sides[node] >= 0:
		return group.end.x + NetworkLayout.LANE_GAP
	return group.position.x - NetworkLayout.LANE_GAP


# From `node` to a lane at `lane_y` met at `lane_x`: a hub or router straight up from its top when
# the lane is met above it, else out of its far side (a hub: its centre) across to `lane_x` and
# along it up or down.
func _rise(node: int, lane_x: float, lane_y: float) -> PackedVector2Array:
	var centre := _centre(node)
	var top := _layout.rects[node].position.y
	if _layout.sides[node] == 0 and absf(lane_x - centre.x) < 0.01 and lane_y < top:
		return PackedVector2Array([centre, Vector2(centre.x, top), Vector2(centre.x, lane_y)])
	var start := centre if _layout.sides[node] == 0 else _attach(node, true)
	return PackedVector2Array([start, Vector2(lane_x, start.y), Vector2(lane_x, lane_y)])


# From `from` (the node `to` hangs on) down its bus and across to `to`'s box.
func _tree_route(from: int, to: int) -> PackedVector2Array:
	var rects := _layout.rects
	var y := rects[to].position.y + _state.anchor
	var inner := _inner_x(to)
	if _layout.sides[from] == 0:
		var bus := rects[from].get_center().x
		return PackedVector2Array([_centre(from), Vector2(bus, y), Vector2(inner, y)])
	var start := Vector2(_outer_x(from), rects[from].position.y + _state.anchor)
	var bus_x := _state.child_bus[from]
	return PackedVector2Array([start, Vector2(bus_x, start.y), Vector2(bus_x, y), Vector2(inner, y)])


# Everything (boxes, slots, routes) moved so the bounds start at the origin.
func _finish_bounds() -> void:
	var layout := _layout
	var bounds := Rect2()
	var first := true
	for region in _state.region_count:
		if layout.region_rects[region].has_area():
			bounds = layout.region_rects[region] if first else bounds.merge(layout.region_rects[region])
			first = false
	for i in layout.rects.size():
		bounds = _state.slots[i] if first else bounds.merge(_state.slots[i])
		first = false
	for route in layout.routes:
		for point in route:
			bounds = bounds.expand(point)
	var shift := -bounds.position
	for i in layout.rects.size():
		layout.rects[i].position += shift
	for k in layout.routes.size():
		for p in layout.routes[k].size():
			layout.routes[k][p] += shift
	for region in _state.region_count:
		if layout.region_rects[region].has_area():
			layout.region_rects[region].position += shift
			layout.title_positions[region] += shift
	bounds.position = Vector2.ZERO
	layout.bounds = bounds


# Where a cable meets `node`'s box: its bus side (`outer`: the far side), `anchor` below its top.
func _attach(node: int, outer: bool = false) -> Vector2:
	if _layout.sides[node] == 0:
		return _centre(node)
	return Vector2(_outer_x(node) if outer else _inner_x(node), _layout.rects[node].position.y + _state.anchor)


func _centre(node: int) -> Vector2:
	var rect := _layout.rects[node]
	return Vector2(rect.get_center().x, rect.position.y + _state.anchor)


func _inner_x(node: int) -> float:
	var rect := _layout.rects[node]
	return rect.position.x if _layout.sides[node] >= 0 else rect.end.x


func _outer_x(node: int) -> float:
	var rect := _layout.rects[node]
	return rect.end.x if _layout.sides[node] >= 0 else rect.position.x


# Without repeated points.
static func _simplified(route: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in route:
		if result.is_empty() or not result[result.size() - 1].is_equal_approx(point):
			result.append(point)
	return result
