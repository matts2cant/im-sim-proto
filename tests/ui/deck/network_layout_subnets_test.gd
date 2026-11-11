extends GdUnitTestSuite
## Unit (ADR 0099, 0112 amendment): NetworkLayout by subnet on synthetic topologies. Each region (a
## subnet) is a box holding its devices, its switches as a tidy tree (child switches below their
## parent, subtrees side by side); routers stand between the boxes of the regions they join, outside
## every box; a tree network has no crossing and nothing `extra`; only a link off the tree (a loop)
## is extra. Boxes are 100 x 40 px; titles 150 x 16 px; the cable meets a box 14 px below its top.

const BOX := Vector2(100, 40)
const TITLE := Vector2(150, 16)
const ANCHOR := 14.0
const R := NetworkLayout.ROUTER


# A layout of `regions.size()` nodes (positions west to east by index) with these cables.
func _arrange(regions: Array[int], pairs: Array, aspect: float = 2.4) -> NetworkLayout:
	var positions: Array[Vector3] = []
	var sizes: Array[Vector2] = []
	var titles: Array[Vector2] = []
	for i in regions.size():
		positions.append(Vector3(i * 2.0, 0, (i % 3) * 1.0))
		sizes.append(BOX)
		while titles.size() <= regions[i]:
			titles.append(TITLE)
	return NetworkLayout.arrange(positions, _cables(pairs), sizes, ANCHOR, aspect, PackedInt32Array(regions), titles)


func _cables(pairs: Array) -> Array[Vector2i]:
	var cables: Array[Vector2i] = []
	for pair: Array in pairs:
		cables.append(Vector2i(pair[0], pair[1]))
	return cables


# Readable and tidy: no crossing, nothing extra, no cable under a box, boxes apart, every device in
# its region's box, every router outside every box, no device under a title.
func _assert_tidy(layout: NetworkLayout, regions: Array[int], pairs: Array) -> void:
	assert_int(NetworkGeometry.crossings(layout.routes)).is_equal(0)
	assert_array(Array(layout.extra)).is_empty()
	assert_int(NetworkGeometry.routes_through_boxes(layout.routes, _cables(pairs), layout.rects)).is_equal(0)
	assert_bool(NetworkGeometry.rects_overlap(layout.rects, 8.0)).is_false()
	for i in regions.size():
		for r in layout.region_rects.size():
			var inside := layout.region_rects[r].encloses(layout.rects[i])
			assert_bool(inside).override_failure_message("node %d in region %d: %s" % [i, r, inside]).is_equal(
				regions[i] == r
			)
		for r in layout.title_positions.size():
			assert_bool(Rect2(layout.title_positions[r], TITLE).intersects(layout.rects[i])).is_false()
	for route in layout.routes:
		for point in route:
			assert_bool(layout.bounds.grow(0.01).has_point(point)).is_true()


func test_a_chain_of_three_subnets_with_routers_between_their_boxes() -> void:
	# Office: SW-O 0 (jack 1, PCs 2 3). Router 4: SW-O and SW-S. Security: SW-S 5 (camera 6, console
	# 7, area switch SW-A 8), SW-A (9 10 11, nested area switch SW-N 12), SW-N (13 14). Router 15:
	# SW-N (inside the tree) and SW-V 16. Servers: SW-V (server 17).
	var regions: Array[int] = [0, 0, 0, 0, R, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, R, 2, 2]
	var pairs := [
		[0, 1],
		[0, 2],
		[0, 3],
		[4, 0],
		[4, 5],
		[5, 6],
		[5, 7],
		[5, 8],
		[8, 9],
		[8, 10],
		[8, 11],
		[8, 12],
		[12, 13],
		[12, 14],
		[15, 12],
		[15, 16],
		[16, 17],
	]
	var layout := _arrange(regions, pairs)
	_assert_tidy(layout, regions, pairs)
	assert_bool(layout.boxed).is_true()
	assert_array(Array(layout.routers)).is_equal([4, 15])
	assert_array(Array(layout.hubs)).is_equal([0, 5, 8, 12, 16])
	# Left to right: Office, router 4, Security, router 15, Servers.
	var boxes := layout.region_rects
	assert_float(layout.rects[4].position.x).is_greater(boxes[0].end.x)
	assert_float(layout.rects[4].end.x).is_less(boxes[1].position.x)
	assert_float(layout.rects[15].position.x).is_greater(boxes[1].end.x)
	assert_float(layout.rects[15].end.x).is_less(boxes[2].position.x)
	assert_float(boxes[0].position.y).is_equal_approx(boxes[1].position.y, 0.001)
	# The switch tree top-down: SW-A below SW-S, SW-N below SW-A.
	assert_float(layout.rects[8].position.y).is_greater(layout.rects[7].end.y)
	assert_float(layout.rects[12].position.y).is_greater(layout.rects[11].end.y)
	# Titles at each box's top-left.
	for r in boxes.size():
		assert_bool(boxes[r].encloses(Rect2(layout.title_positions[r], TITLE))).is_true()
	# Same topology, same picture.
	var again := _arrange(regions, pairs)
	assert_array(again.rects).is_equal(layout.rects)
	assert_array(again.routes).is_equal(layout.routes)


func test_nested_area_switches_stay_tidy_in_any_panel() -> void:
	# Main switch 0 (devices 1 2) with four area switches 3, 7, 11, 15, each with three devices; area
	# switch 3 has a nested switch 19 with three devices.
	var regions: Array[int] = []
	var pairs: Array = [[0, 1], [0, 2]]
	for i in 23:
		regions.append(0)
	for area: int in [3, 7, 11, 15]:
		pairs.append([0, area])
		for d in 3:
			pairs.append([area, area + 1 + d])
	pairs.append([3, 19])
	for d in 3:
		pairs.append([19, 20 + d])
	var wide := _arrange(regions, pairs, 6.0)
	var tall := _arrange(regions, pairs, 0.6)
	for layout: NetworkLayout in [wide, tall]:
		_assert_tidy(layout, regions, pairs)
		assert_int(layout.hubs[0]).is_equal(0)
	assert_float(wide.bounds.size.x / wide.bounds.size.y).is_greater(tall.bounds.size.x / tall.bounds.size.y)
	# The nested switch hangs below its area switch.
	assert_float(tall.rects[19].position.y).is_greater(tall.rects[3].position.y)
	# One region and no title: no box padding (the network as ADR 0099 drew it).
	var plain := NetworkLayout.arrange(
		[Vector3.ZERO, Vector3.ONE], _cables([[0, 1]]), [BOX, BOX] as Array[Vector2], ANCHOR
	)
	assert_bool(plain.boxed).is_false()


func test_devices_cabled_straight_to_a_router() -> void:
	# Office: SW-O 0 (1 2 3). Router 4: SW-O, a camera 5 and a switch 6 (7 8) in Security; the camera
	# has no other cable.
	var regions: Array[int] = [0, 0, 0, 0, R, 1, 1, 1, 1]
	var pairs := [[0, 1], [0, 2], [0, 3], [4, 0], [4, 5], [4, 6], [6, 7], [6, 8]]
	var layout := _arrange(regions, pairs)
	_assert_tidy(layout, regions, pairs)
	assert_array(Array(layout.hubs)).contains_exactly_in_any_order([0, 5, 6])
	assert_float(layout.rects[4].end.x).is_less(layout.region_rects[1].position.x)


func test_a_hidden_subnet_leaves_its_router_beside_the_one_box() -> void:
	# Office only (the router's other side is not on the map yet).
	var regions: Array[int] = [0, 0, 0, 0, R]
	var pairs := [[0, 1], [0, 2], [0, 3], [4, 0]]
	var layout := _arrange(regions, pairs)
	_assert_tidy(layout, regions, pairs)
	assert_int(layout.region_rects.size()).is_equal(1)
	assert_float(layout.rects[4].position.x).is_greater(layout.region_rects[0].end.x)


func test_a_loop_off_the_tree_is_extra_and_reported() -> void:
	# Main switch 0 (device 9) with area switches 1 and 5 (three devices each), also cabled to each other.
	var regions: Array[int] = []
	for i in 10:
		regions.append(0)
	var pairs := [[0, 1], [0, 5], [1, 2], [1, 3], [1, 4], [5, 6], [5, 7], [5, 8], [1, 5], [0, 9]]
	var layout := _arrange(regions, pairs)
	assert_array(Array(layout.extra)).is_equal([8])
	# Its lane runs above every box.
	var top := layout.rects[0].position.y
	for i in layout.rects.size():
		top = minf(top, layout.rects[i].position.y)
	var lowest := INF
	for point in layout.routes[8]:
		lowest = minf(lowest, point.y)
	assert_float(lowest).is_less(top)
