class_name NetworkLayoutState
extends RefCounted
## The working state NetworkLayout's passes share while they place one network (ADR 0099, 0112
## amendment): the inputs, each group's tree and column slots, the switch trees, the left-to-right
## sequence of regions and routers, the region plans, and the small queries every pass asks (world
## order, cable ends, rounded widths). The passes (NetworkGrouping, NetworkSwitchTrees,
## NetworkRegionPlanner, NetworkRouting) write their results into `layout`'s public fields.
## It lives only during NetworkLayout.arrange(): the layout does not keep it (no reference cycle).

## Where the results go.
var layout: NetworkLayout
var positions: Array[Vector3] = []
var cables: Array[Vector2i] = []
var sizes: Array[Vector2] = []
## Per region: its title's size (zero: none).
var titles: Array[Vector2] = []
## How far below its box's top a cable meets a box.
var anchor: float = 0.0
## Per node: the nodes cabled to it (sorted).
var links: Array[PackedInt32Array] = []
## Per node: its depth under its group's hub, and the nodes hanging on it.
var depth: PackedInt32Array = []
var children: Array[Array] = []
## Per node: its column's slot (the box's row at the column's rounded width).
var slots: Array[Rect2] = []
## Per node: x of the bus to its children (the gap beyond its column).
var child_bus: PackedFloat32Array = []
## Per hub: its group's bounds (group coordinates until placed).
var group_bounds: Dictionary[int, Rect2] = {}
var region_count: int = 0
## Per region: its switch trees' roots (hubs), left to right.
var roots: Array[PackedInt32Array] = []
## Hub -> its child hubs in its region's switch tree (left to right); child hub -> its uplink cable,
## and the hub it hangs on.
var kids: Dictionary[int, Array] = {}
var uplink: Dictionary[int, int] = {}
var up_hub: Dictionary[int, int] = {}
## Per region: the cables of the routers right beside it into it; cable -> it comes from the left.
var entries: Array[PackedInt32Array] = []
var from_left: Dictionary[int, bool] = {}
## Left to right: Vector2i(0, region) or Vector2i(1, router node).
var blocks: Array[Vector2i] = []
## Per region: its chosen plan, and its box's top-left corner once placed.
var plans: Array[RegionPlan] = []
var origins: Array[Vector2] = []


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


func _init(
	p_layout: NetworkLayout,
	p_positions: Array[Vector3],
	p_cables: Array[Vector2i],
	p_sizes: Array[Vector2],
	p_anchor: float,
	p_titles: Array[Vector2],
) -> void:
	layout = p_layout
	positions = p_positions
	cables = p_cables
	sizes = p_sizes
	anchor = p_anchor
	titles = p_titles
	var count := sizes.size()
	slots.resize(count)
	child_bus.resize(count)
	child_bus.fill(0.0)
	region_count = titles.size()
	for i in count:
		region_count = maxi(region_count, layout.region_of[i] + 1)


## Widths rounded up to NetworkLayout.WIDTH_STEP px, so a status change rarely moves anything.
func rounded(width: float) -> float:
	return ceilf(width / NetworkLayout.WIDTH_STEP - 0.001) * NetworkLayout.WIDTH_STEP


## True when node a comes before b along world `axis` (0: x, 2: z), then the other axis, then index.
func before(a: int, b: int, axis: int) -> bool:
	var other := 2 - axis
	var pa := positions[a] if a < positions.size() else Vector3.ZERO
	var pb := positions[b] if b < positions.size() else Vector3.ZERO
	if not is_equal_approx(pa[axis], pb[axis]):
		return pa[axis] < pb[axis]
	if not is_equal_approx(pa[other], pb[other]):
		return pa[other] < pb[other]
	return a < b


## True when `cable` joins two different nodes of the inputs.
func valid(cable: Vector2i) -> bool:
	var count := sizes.size()
	return cable.x != cable.y and cable.x >= 0 and cable.y >= 0 and cable.x < count and cable.y < count


## True when `node` is its group's hub (not a router).
func is_hub(node: int) -> bool:
	return layout.hub_of[node] == node and not layout.is_router(node)


## The other end of cable `k` when one end is `node`, else -1.
func other_end(k: int, node: int) -> int:
	var cable := cables[k]
	if not valid(cable):
		return -1
	if cable.x == node:
		return cable.y
	if cable.y == node:
		return cable.x
	return -1


## The cable `k`'s end inside `region`, or -1.
func inside(k: int, region: int) -> int:
	var cable := cables[k]
	if layout.region_of[cable.x] == region:
		return cable.x
	return cable.y if layout.region_of[cable.y] == region else -1
