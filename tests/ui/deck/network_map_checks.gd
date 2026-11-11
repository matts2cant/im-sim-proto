extends RefCounted
## Test helper (not a suite, ADR 0099, 0113): the readability checks of a network map (NetworkGraph,
## the deck's Map) run on a whole cabled network: rows_from() gives every device the cables join an
## entity to, up or down (its own row first, outlined), online when it reaches them, with their
## status words and the commands of the deck's table they accept; cables() the links between them.
## Asserts: no two node boxes (name and status line) closer than MIN_GAP, no cable crossing another,
## no cable under a box other than its two ends', the fitted view shows every node inside the panel,
## and the same network gives the same placement.

## The size the old terminal gave its map (graph tests; the readability checks use DECK_MAP_SIZE).
const GRAPH_SIZE := Vector2(1050, 440)
## The deck's Map panel in the game's 1152 x 648 window (deck_screen_test.gd measures it).
const DECK_MAP_SIZE := Vector2(829, 507)
## Smallest gap between two boxes (px, edge to edge, at zoom 1).
const MIN_GAP := 8.0
const DECK_CONFIG: DeckConfig = preload("res://items/deck/deck_config.tres")


## The map rows of the network `entity` (a device's entity) is cabled into: its own row first, then
## every device the cables join it to (DeviceGraph.component()), breadth-first.
static func rows_from(entity: Node) -> Array[NetworkRow]:
	var rows: Array[NetworkRow] = []
	var own := Device.of(entity)
	if own == null or not own.is_up():
		return rows
	var graph := Device.graph(own.get_tree())
	var own_id := own.get_instance_id()
	var ids := PackedInt64Array([own_id])
	ids.append_array(graph.component(own_id))
	var reached := graph.reachable(own_id)
	for id in ids:
		var other := instance_from_id(id) as Device
		if other == null or not is_instance_valid(other.entity):
			continue
		var row := NetworkRow.new()
		row.device = other
		row.name = NetworkSource.display_name(other)
		row.is_self = id == own_id
		row.online = row.is_self or reached.has(id)
		row.status = DeviceStatus.of(other.entity, row.online)
		row.disabled = row.online and DeviceStatus.is_disabled(other.entity)
		row.has_view = DeviceStatus.has_view(other.entity)
		DeckScreen.place_in_network(row, other)
		if row.online and not row.is_self:
			for command: StringName in DECK_CONFIG.command_labels:
				if other.accepts(command, entity):
					row.commands.append(command)
		rows.append(row)
	return rows


## The cables between `rows`, as index pairs (lower first), each once.
static func cables(rows: Array[NetworkRow]) -> Array[Vector2i]:
	return DeckScreen.cables_of(rows)


## Shows the network in a fresh graph under `suite` and asserts the checks; returns
## {"zoom": the fitted zoom, "layout": the NetworkLayout, "crossings": cable crossings} (the graph
## is freed). `max_crossings`: crossings tolerated (a known layout limit, see the caller).
static func check(
	suite: GdUnitTestSuite,
	rows: Array[NetworkRow],
	cables: Array[Vector2i],
	config: DeckConfig = DECK_CONFIG,
	max_crossings: int = 0,
) -> Dictionary:
	var graph := _graph(suite, rows, cables, config)
	var rects := graph.node_rects()
	suite.assert_int(rects.size()).is_equal(rows.size())
	(
		suite
		. assert_bool(NetworkGeometry.rects_overlap(rects, MIN_GAP))
		. override_failure_message("boxes overlap")
		. is_false()
	)
	var routes := graph.layout.routes
	var crossings := NetworkGeometry.crossings(routes)
	suite.assert_int(crossings).override_failure_message("cables cross %d times" % crossings).is_less_equal(
		max_crossings
	)
	(
		suite
		. assert_int(NetworkGeometry.routes_through_boxes(routes, cables, rects))
		. override_failure_message("cables under boxes")
		. is_equal(0)
	)
	# The layout's boxes are the nodes' boxes.
	for i in rects.size():
		suite.assert_bool(rects[i].is_equal_approx(graph.layout.rects[i])).is_true()
	# The content's rect holds every box and cable (a Control is culled by its rect: zoomed in, cables
	# outside it would vanish).
	var drawn := Rect2(Vector2.ZERO, graph.content.size).grow(0.01)
	for rect in rects:
		suite.assert_bool(drawn.encloses(rect)).override_failure_message("box outside the content").is_true()
	for route in routes:
		for point in route:
			suite.assert_bool(drawn.has_point(point)).override_failure_message("cable outside the content").is_true()
	# Fitted: every node inside the panel.
	var inside := Rect2(Vector2.ZERO, graph.size).grow(0.01)
	for row in rows:
		var shown := graph.node_screen_rect(row.name)
		(
			suite
			. assert_bool(inside.encloses(shown))
			. override_failure_message("%s outside: %s" % [row.name, shown])
			. is_true()
		)
	_check_subnets(suite, graph, rows)
	var result := {
		"zoom": graph.view.zoom,
		"layout": graph.layout,
		"crossings": crossings,
		"extra": graph.layout.extra.size(),
		"boxes": graph.subnet_boxes.duplicate(true),
	}
	# Deterministic: the same network again, the same picture.
	var again := _graph(suite, rows, cables, config)
	suite.assert_array(again.node_rects()).is_equal(rects)
	suite.assert_array(again.layout.routes).is_equal(routes)
	graph.free()
	again.free()
	return result


# Subnet boxes: apart from each other, each holds its subnet's devices, no router inside any, and
# no device box under a title.
static func _check_subnets(suite: GdUnitTestSuite, graph: NetworkGraph, rows: Array[NetworkRow]) -> void:
	var boxes: Dictionary[StringName, Rect2] = {}
	for id: StringName in graph.subnet_boxes:
		boxes[id] = graph.subnet_boxes[id]["rect"]
	var box_list: Array[Rect2] = []
	box_list.assign(boxes.values())
	(
		suite
		. assert_bool(NetworkGeometry.rects_overlap(box_list, MIN_GAP))
		. override_failure_message("subnet boxes overlap")
		. is_false()
	)
	var rects := graph.node_rects()
	for i in rows.size():
		for id: StringName in boxes:
			var inside := boxes[id].encloses(rects[i])
			var expected := not rows[i].is_between() and rows[i].subnet == id
			if rows[i].is_between() or expected:
				(
					suite
					. assert_bool(inside)
					. override_failure_message("%s inside %s: %s" % [rows[i].name, id, inside])
					. is_equal(expected)
				)
	for id: StringName in boxes:
		var title: Rect2 = graph.subnet_boxes[id]["title_rect"]
		suite.assert_bool(boxes[id].encloses(title)).override_failure_message("%s title outside" % id).is_true()
		for i in rects.size():
			(
				suite
				. assert_bool(title.intersects(rects[i]))
				. override_failure_message("%s under a title" % rows[i].name)
				. is_false()
			)


static func _graph(
	suite: GdUnitTestSuite, rows: Array[NetworkRow], cables: Array[Vector2i], config: DeckConfig
) -> NetworkGraph:
	var graph := NetworkGraph.new()
	suite.add_child(graph)
	graph.size = DECK_MAP_SIZE
	graph.subnets = Router.subnet_info(suite.get_tree())
	graph.request_fit()
	graph.show_network(rows, cables, config)
	return graph
