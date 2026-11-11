extends RefCounted
## Test helper (not a suite, ADR 0099): the readability checks of the terminal's network map, run on
## a network as the terminal shows it (Terminal.devices() rows and Terminal.cables()) in a graph of
## the terminal screen's size. Asserts: no two node boxes (name and status line) closer than
## MIN_GAP, no cable crossing another, no cable under a box other than its two ends', the fitted view
## shows every node inside the panel, and the same network gives the same placement.

## The Network tab's graph on the terminal screen.
const GRAPH_SIZE := Vector2(1050, TerminalScreen.TAB_HEIGHT)
## Smallest gap between two boxes (px, edge to edge, at zoom 1).
const MIN_GAP := 8.0


## Shows the network in a fresh graph under `suite` and asserts the checks; returns
## {"zoom": the fitted zoom, "layout": the NetworkLayout} (the graph is freed).
static func check(
	suite: GdUnitTestSuite, rows: Array[Terminal.Row], cables: Array[Vector2i], config: TerminalConfig = null
) -> Dictionary:
	var graph := _graph(suite, rows, cables, config)
	var rects := graph.node_rects()
	suite.assert_int(rects.size()).is_equal(rows.size())
	suite.assert_bool(NetworkLayout.rects_overlap(rects, MIN_GAP)).override_failure_message("boxes overlap").is_false()
	var routes := graph.layout.routes
	suite.assert_int(NetworkLayout.crossings(routes)).override_failure_message("cables cross").is_equal(0)
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
	var result := {"zoom": graph.view.zoom, "layout": graph.layout}
	# Deterministic: the same network again, the same picture.
	var again := _graph(suite, rows, cables, config)
	suite.assert_array(again.node_rects()).is_equal(rects)
	suite.assert_array(again.layout.routes).is_equal(routes)
	graph.free()
	again.free()
	return result


static func _graph(
	suite: GdUnitTestSuite, rows: Array[Terminal.Row], cables: Array[Vector2i], config: TerminalConfig
) -> NetworkGraph:
	var graph := NetworkGraph.new()
	suite.add_child(graph)
	graph.size = GRAPH_SIZE
	graph.request_fit()
	graph.show_network(rows, cables, config)
	return graph
