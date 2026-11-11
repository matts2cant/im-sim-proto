extends GdUnitTestSuite
## Unit (ADR 0099): NetworkLayout, the terminal's network map. Devices with 3+ cables are hubs; the
## others join the nearest hub and hang in two columns on its bus (west half left, east half right,
## north first), a device hanging on another one column further out on its parent's row; groups
## stand GROUP_GAP apart; routes never cross and never pass under a box; the same inputs give the
## same placement. Boxes are 100 x 40 px unless a test says otherwise; the cable meets a box 14 px
## below its top.

const BOX := Vector2(100, 40)
const ANCHOR := 14.0


func _sizes(count: int) -> Array[Vector2]:
	var sizes: Array[Vector2] = []
	for i in count:
		sizes.append(BOX)
	return sizes


func _cables(pairs: Array) -> Array[Vector2i]:
	var cables: Array[Vector2i] = []
	for pair: Array in pairs:
		cables.append(Vector2i(pair[0], pair[1]))
	return cables


# A star: hub 0 at the origin, members 1..4 at the given world points.
func _star(points: Array[Vector3]) -> NetworkLayout:
	var positions: Array[Vector3] = [Vector3.ZERO]
	positions.append_array(points)
	var pairs: Array = []
	for i in points.size():
		pairs.append([0, i + 1])
	return NetworkLayout.arrange(positions, _cables(pairs), _sizes(positions.size()), ANCHOR)


func test_a_star_hangs_west_devices_left_and_east_devices_right_north_first() -> void:
	# 1 north-west, 2 south-west, 3 north-east, 4 south-east.
	var layout := _star([Vector3(-5, 0, -3), Vector3(-4, 0, 6), Vector3(5, 0, -2), Vector3(6, 0, 4)])
	assert_array(Array(layout.hubs)).is_equal([0])
	assert_array(Array(layout.sides)).is_equal([0, -1, -1, 1, 1])
	assert_array(Array(layout.hub_of)).is_equal([0, 0, 0, 0, 0])
	var hub := layout.rects[0]
	# The hub on top, centred on the bus; boxes aligned STUB px from it.
	var bus := hub.get_center().x
	assert_float(layout.rects[1].end.x).is_equal_approx(bus - NetworkLayout.STUB, 0.001)
	assert_float(layout.rects[3].position.x).is_equal_approx(bus + NetworkLayout.STUB, 0.001)
	# North first: 1 above 2, 3 above 4; the first row HUB_GAP below the hub, rows ROW_GAP apart.
	assert_float(layout.rects[1].position.y).is_equal_approx(hub.end.y + NetworkLayout.HUB_GAP, 0.001)
	assert_float(layout.rects[2].position.y).is_equal_approx(layout.rects[1].end.y + NetworkLayout.ROW_GAP, 0.001)
	assert_float(layout.rects[3].position.y).is_equal_approx(layout.rects[1].position.y, 0.001)
	assert_float(layout.rects[4].position.y).is_greater(layout.rects[3].position.y)
	assert_bool(NetworkLayout.rects_overlap(layout.rects, 8.0)).is_false()


func test_cables_run_down_the_bus_and_across_without_crossing() -> void:
	var layout := _star([Vector3(-5, 0, -3), Vector3(-4, 0, 6), Vector3(5, 0, -2), Vector3(6, 0, 4)])
	# Hub 0 to device 2 (left, second row): down the bus, then across to its box's right edge.
	var route := layout.routes[1]
	var bus := layout.rects[0].get_center().x
	var y := layout.rects[2].position.y + ANCHOR
	assert_array(Array(route)).is_equal(
		[Vector2(bus, layout.rects[0].position.y + ANCHOR), Vector2(bus, y), Vector2(layout.rects[2].end.x, y)]
	)
	assert_int(NetworkLayout.crossings(layout.routes)).is_equal(0)
	var cables := _cables([[0, 1], [0, 2], [0, 3], [0, 4]])
	assert_int(NetworkLayout.routes_through_boxes(layout.routes, cables, layout.rects)).is_equal(0)
	assert_bool(layout.bounds.encloses(layout.rects[2])).is_true()


func test_a_device_hanging_on_another_sits_one_column_out_on_its_row() -> void:
	# 0 hub (3 cables), 1 2 3 on it (east), 4 hangs on 1, 5 on 4.
	var positions: Array[Vector3] = [
		Vector3.ZERO, Vector3(5, 0, 0), Vector3(-5, 0, 1), Vector3(6, 0, 3), Vector3(8, 0, 0), Vector3(9, 0, 0)
	]
	var cables := _cables([[0, 1], [0, 2], [0, 3], [1, 4], [4, 5]])
	var layout := NetworkLayout.arrange(positions, cables, _sizes(6), ANCHOR)
	assert_array(Array(layout.parent)).is_equal([-1, 0, 0, 0, 1, 4])
	assert_float(layout.rects[4].position.y).is_equal_approx(layout.rects[1].position.y, 0.001)
	# 100 px boxes make 120 px columns (WIDTH_STEP 24).
	assert_float(layout.rects[4].position.x).is_equal_approx(
		layout.rects[1].position.x + 120.0 + NetworkLayout.COLUMN_GAP, 0.001
	)
	assert_float(layout.rects[5].position.x).is_greater(layout.rects[4].end.x)
	# 3 (the next device on the bus) comes below 1's subtree.
	assert_float(layout.rects[3].position.y).is_greater_equal(layout.rects[1].end.y + NetworkLayout.ROW_GAP - 0.001)
	assert_int(NetworkLayout.crossings(layout.routes)).is_equal(0)
	assert_int(NetworkLayout.routes_through_boxes(layout.routes, cables, layout.rects)).is_equal(0)
	assert_bool(NetworkLayout.rects_overlap(layout.rects, 8.0)).is_false()


func test_a_network_without_hubs_hangs_on_its_most_cabled_device() -> void:
	# Two PCs on a wall jack (the office network), and a lone device.
	var positions: Array[Vector3] = [Vector3(0, 0, 4), Vector3(5, 0, -4), Vector3(3, 0, 4), Vector3(20, 0, 0)]
	var layout := NetworkLayout.arrange(positions, _cables([[0, 1], [1, 2]]), _sizes(4), ANCHOR)
	assert_array(Array(layout.hubs)).contains_exactly_in_any_order([1, 3])
	assert_array(Array(layout.hub_of)).is_equal([1, 1, 1, 3])
	assert_bool(NetworkLayout.rects_overlap(layout.rects, 8.0)).is_false()
	assert_array(NetworkLayout.arrange([], [], [], ANCHOR).rects).is_empty()
	var single := NetworkLayout.arrange([Vector3(4, 0, 4)], [], [BOX], ANCHOR)
	assert_array(Array(single.hubs)).is_equal([0])
	# The bounds hold its slot: its width rounded up to WIDTH_STEP (100 -> 120 px).
	assert_vector(single.bounds.size).is_equal(Vector2(120, 40))
	assert_bool(single.bounds.encloses(single.rects[0])).is_true()


func test_groups_stand_apart_west_to_east_and_neighbouring_hubs_join_straight() -> void:
	# Hub 0 east with 3 devices, hub 4 west with 3 devices, cabled to each other.
	var positions: Array[Vector3] = [Vector3(20, 0, 0)]
	var pairs: Array = []
	for i in 3:
		positions.append(Vector3(20 + i, 0, 3))
		pairs.append([0, 1 + i])
	positions.append(Vector3(-20, 0, 0))
	for i in 3:
		positions.append(Vector3(-20 + i, 0, 3))
		pairs.append([4, 5 + i])
	pairs.append([0, 4])
	var cables := _cables(pairs)
	var layout := NetworkLayout.arrange(positions, cables, _sizes(8), ANCHOR)
	assert_array(Array(layout.hubs)).is_equal([4, 0])
	var west := _group_rect(layout, 4)
	var east := _group_rect(layout, 0)
	assert_float(east.position.x - west.end.x).is_greater_equal(NetworkLayout.GROUP_GAP - 0.001)
	# Hubs top-aligned, the cable between them one straight line.
	assert_float(layout.rects[0].position.y).is_equal_approx(layout.rects[4].position.y, 0.001)
	assert_int(layout.routes[6].size()).is_equal(2)
	assert_int(NetworkLayout.crossings(layout.routes)).is_equal(0)
	assert_int(NetworkLayout.routes_through_boxes(layout.routes, cables, layout.rects)).is_equal(0)


func test_cables_between_distant_groups_run_in_lanes_above_them() -> void:
	# Three hubs west to east (0, 4, 8), each with three devices; 0 cabled to 4 and to 8.
	var positions: Array[Vector3] = []
	var pairs: Array = []
	for g in 3:
		positions.append(Vector3(g * 30, 0, 0))
		for i in 3:
			positions.append(Vector3(g * 30 + i, 0, 3))
			pairs.append([g * 4, g * 4 + 1 + i])
	pairs.append([0, 4])
	pairs.append([0, 8])
	var cables := _cables(pairs)
	var layout := NetworkLayout.arrange(positions, cables, _sizes(12), ANCHOR, 10.0)
	assert_array(Array(layout.hubs)).is_equal([0, 4, 8])
	var lane := layout.routes[10]
	# Up from hub 0's top, along a lane above every box, down into hub 8's top.
	var top := layout.rects[0].position.y
	assert_float(lane[1].y).is_equal_approx(top, 0.001)
	assert_float(lane[2].y).is_less(top - NetworkLayout.LANE_GAP + 0.001)
	assert_float(lane[lane.size() - 1].x).is_equal_approx(layout.rects[8].get_center().x, 0.001)
	assert_int(NetworkLayout.crossings(layout.routes)).is_equal(0)
	assert_int(NetworkLayout.routes_through_boxes(layout.routes, cables, layout.rects)).is_equal(0)


func test_many_groups_wrap_into_rows_for_a_narrow_panel() -> void:
	var positions: Array[Vector3] = []
	var pairs: Array = []
	for g in 4:
		positions.append(Vector3(g * 30, 0, 0))
		for i in 3:
			positions.append(Vector3(g * 30 + i, 0, 3))
			pairs.append([g * 4, g * 4 + 1 + i])
		if g > 0:
			pairs.append([0, g * 4])
	var cables := _cables(pairs)
	var wide := NetworkLayout.arrange(positions, cables, _sizes(16), ANCHOR, 6.0)
	var tall := NetworkLayout.arrange(positions, cables, _sizes(16), ANCHOR, 0.8)
	assert_float(wide.bounds.size.x / wide.bounds.size.y).is_greater(tall.bounds.size.x / tall.bounds.size.y)
	var rows_of_hubs := {}
	for hub in tall.hubs:
		rows_of_hubs[tall.rects[hub].position.y] = true
	assert_int(rows_of_hubs.size()).is_greater(1)
	for layout: NetworkLayout in [wide, tall]:
		assert_bool(NetworkLayout.rects_overlap(layout.rects, 8.0)).is_false()
		assert_int(NetworkLayout.routes_through_boxes(layout.routes, cables, layout.rects)).is_equal(0)


func test_the_same_network_gives_the_same_placement() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var positions: Array[Vector3] = []
	var sizes: Array[Vector2] = []
	var pairs: Array = []
	for i in 30:
		positions.append(Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)))
		sizes.append(Vector2(rng.randf_range(60, 200), 44))
		if i > 0:
			pairs.append([0 if i < 15 else 1, i] if i != 1 else [0, 1])
	var cables := _cables(pairs)
	var first := NetworkLayout.arrange(positions, cables, sizes, ANCHOR)
	var second := NetworkLayout.arrange(positions.duplicate(), cables.duplicate(), sizes.duplicate(), ANCHOR)
	assert_array(second.rects).is_equal(first.rects)
	assert_array(second.routes).is_equal(first.routes)
	assert_bool(NetworkLayout.rects_overlap(first.rects, 8.0)).is_false()
	assert_int(NetworkLayout.crossings(first.routes)).is_equal(0)


func test_a_wider_status_within_the_column_step_moves_nothing_else() -> void:
	var points: Array[Vector3] = [Vector3(-5, 0, -3), Vector3(-4, 0, 6), Vector3(5, 0, -2), Vector3(6, 0, 4)]
	var before := _star(points)
	var positions: Array[Vector3] = [Vector3.ZERO]
	positions.append_array(points)
	var sizes := _sizes(5)
	# 100 -> 110 px: still one 24 px step (the column is 120 wide either way).
	sizes[1] = Vector2(110, 40)
	var after := NetworkLayout.arrange(positions, _cables([[0, 1], [0, 2], [0, 3], [0, 4]]), sizes, ANCHOR)
	for i: int in [0, 2, 3, 4]:
		assert_vector(after.rects[i].position).is_equal(before.rects[i].position)
	# The left box keeps its bus-side edge.
	assert_float(after.rects[1].end.x).is_equal_approx(before.rects[1].end.x, 0.001)


func test_crossings_and_boxes_count_only_real_ones() -> void:
	var cross: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0), Vector2(10, 10)]), PackedVector2Array([Vector2(0, 10), Vector2(10, 0)])
	]
	assert_int(NetworkLayout.crossings(cross)).is_equal(1)
	# Touching ends, a T and a shared collinear bus do not count.
	var touching: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0), Vector2(0, 20), Vector2(10, 20)]),
		PackedVector2Array([Vector2(0, 0), Vector2(0, 10), Vector2(-10, 10)]),
		PackedVector2Array([Vector2(0, 10), Vector2(10, 10)]),
	]
	assert_int(NetworkLayout.crossings(touching)).is_equal(0)
	var rects: Array[Rect2] = [Rect2(-5, -5, 10, 10), Rect2(20, 20, 10, 10), Rect2(40, -5, 10, 10)]
	var routes: Array[PackedVector2Array] = [PackedVector2Array([Vector2(0, 0), Vector2(45, 0)])]
	assert_int(NetworkLayout.routes_through_boxes(routes, [Vector2i(0, 2)], rects)).is_equal(0)
	routes[0] = PackedVector2Array([Vector2(0, 0), Vector2(25, 25)])
	assert_int(NetworkLayout.routes_through_boxes(routes, [Vector2i(0, 2)], rects)).is_equal(1)


func _group_rect(layout: NetworkLayout, hub: int) -> Rect2:
	var rect := layout.rects[hub]
	for i in layout.rects.size():
		if layout.hub_of[i] == hub:
			rect = rect.merge(layout.rects[i])
	return rect
