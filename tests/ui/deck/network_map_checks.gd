extends RefCounted
## Test helper (not a suite, ADR 0099, 0113): the readability checks of a network map (NetworkGraph,
## the deck's Map) run on a whole cabled network: rows_from() gives every device the cables join an
## entity to, up or down (its own row first, outlined), online when it reaches them, with their
## status words and the commands of the deck's table they accept; cables() the links between them.
## Asserts: no two node boxes (name and status line) closer than MIN_GAP, no cable crossing another,
## no cable under a box other than its two ends', the fitted view shows every node inside the panel,
## and the same network gives the same placement.

## The size the old terminal gave its map (the deck's content area is larger).
const GRAPH_SIZE := Vector2(1050, 440)
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
	suite.assert_bool(NetworkLayout.rects_overlap(rects, MIN_GAP)).override_failure_message("boxes overlap").is_false()
	var routes := graph.layout.routes
	var crossings := NetworkLayout.crossings(routes)
	suite.assert_int(crossings).override_failure_message("cables cross %d times" % crossings).is_less_equal(
		max_crossings
	)
	(
		suite
		. assert_int(NetworkLayout.routes_through_boxes(routes, cables, rects))
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
	var result := {"zoom": graph.view.zoom, "layout": graph.layout, "crossings": crossings}
	# Deterministic: the same network again, the same picture.
	var again := _graph(suite, rows, cables, config)
	suite.assert_array(again.node_rects()).is_equal(rects)
	suite.assert_array(again.layout.routes).is_equal(routes)
	graph.free()
	again.free()
	return result


static func _graph(
	suite: GdUnitTestSuite, rows: Array[NetworkRow], cables: Array[Vector2i], config: DeckConfig
) -> NetworkGraph:
	var graph := NetworkGraph.new()
	suite.add_child(graph)
	graph.size = GRAPH_SIZE
	graph.request_fit()
	graph.show_network(rows, cables, config)
	return graph
