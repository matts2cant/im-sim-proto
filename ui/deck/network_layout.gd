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
## This class keeps the inputs' and results' shape; the passes live beside it, in order: NetworkGrouping
## (groups and combs), NetworkSwitchTrees (regions' order, switch trees), NetworkRegionPlanner
## (region plans, every block's place), NetworkRouting (routes, bounds), sharing a NetworkLayoutState.

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
	layout.region_of.resize(sizes.size())
	layout.region_of.fill(0)
	for i in mini(regions.size(), sizes.size()):
		layout.region_of[i] = regions[i] if regions[i] >= 0 else ROUTER
	# The passes share a working state that refers to the layout; the layout never keeps it.
	var state := NetworkLayoutState.new(layout, positions, cables, sizes, anchor, titles)
	layout._run(state, aspect)
	return layout


## True when `node` is a router (between regions).
func is_router(node: int) -> bool:
	return node >= 0 and node < region_of.size() and region_of[node] == ROUTER


# The passes in order: groups and their combs, the regions' order and switch trees, the region plans
# and every block's place, then the routes and the bounds.
func _run(state: NetworkLayoutState, aspect: float) -> void:
	var count := state.sizes.size()
	rects.resize(count)
	sides.resize(count)
	sides.fill(0)
	region_rects.resize(state.region_count)
	region_rects.fill(Rect2())
	title_positions.resize(state.region_count)
	title_positions.fill(Vector2.ZERO)
	if count == 0:
		return
	NetworkGrouping.new(state).run()
	boxed = not routers.is_empty() or state.region_count > 1
	for title in state.titles:
		boxed = boxed or title != Vector2.ZERO
	NetworkSwitchTrees.new(state).run()
	NetworkRegionPlanner.new(state).run(aspect)
	NetworkRouting.new(state).run()
