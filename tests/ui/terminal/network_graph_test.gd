extends GdUnitTestSuite
## Integration (ADR 0099): NetworkGraph, the terminal's network map, on the synthetic 60-device
## network (fixtures/synthetic_network.gd: 4 switches) at the terminal screen's graph size, placed
## away from the window's corner. Readable (network_map_checks.gd); real mouse events pushed through
## the viewport: a click after panning and zooming opens the clicked node's menu, a drag moves the
## map without opening one, the wheel zooms around the cursor; the menu stays inside the panel
## wherever its node is; Fit shows the whole network again.

const Synthetic := preload("res://tests/ui/terminal/fixtures/synthetic_network.gd")
const MapChecks := preload("res://tests/ui/terminal/network_map_checks.gd")
const GRAPH_AT := Vector2(40, 60)

var _network: Synthetic
var _root: Node3D
var _graph: NetworkGraph
var _mouse_before: Input.MouseMode


func before_test() -> void:
	DebugPanel.set_open(false)
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Node3D.new()
	_root.position = Vector3(-300, 0, 500)
	add_child(_root)
	_network = Synthetic.new()
	_network.build(_root)
	_graph = NetworkGraph.new()
	add_child(_graph)
	_graph.position = GRAPH_AT
	_graph.size = MapChecks.GRAPH_SIZE
	_graph.request_fit()
	_graph.show_network(_network.rows, _network.cables, null)


func after_test() -> void:
	_graph.free()
	_network.release()
	_root.free()
	Input.mouse_mode = _mouse_before


func test_the_synthetic_network_is_readable() -> void:
	assert_int(_network.rows.size()).is_equal(60)
	var result := MapChecks.check(self, _network.rows, _network.cables)
	assert_int((result["layout"] as NetworkLayout).hubs.size()).is_equal(4)
	# Sixty wide labels do not fit the panel at full size: fitted, the view zooms out, within limits.
	var zoom: float = result["zoom"]
	assert_float(zoom).is_greater(0.3)
	assert_float(zoom).is_less(1.0)


func test_a_click_after_panning_and_zooming_opens_the_clicked_node() -> void:
	_graph.zoom_at(Vector2(300, 200), 2.2)
	_graph.pan(Vector2(-140, 60))
	var target := _visible_node()
	assert_str(target).is_not_empty()
	var button := _graph.node_button(target)
	var local := _to_graph(button.get_global_transform_with_canvas() * (button.size * 0.5))
	assert_str(_graph.node_name_at(local)).is_equal(target)
	_click(local)
	assert_bool(_graph.menu.visible).is_true()
	assert_str(_graph.menu_title.text).is_equal(target)
	# A click on the background closes it.
	_click(_background_point())
	assert_bool(_graph.menu.visible).is_false()


func test_a_drag_moves_the_map_and_opens_no_menu() -> void:
	var target := _visible_node()
	var start := _graph.node_screen_rect(target).get_center()
	var before := _graph.view.offset
	_press(start, true)
	_move(start + Vector2(30, 10))
	_move(start + Vector2(90, 40))
	_press(start + Vector2(90, 40), false)
	assert_vector(_graph.view.offset).is_equal_approx(before + Vector2(90, 40), Vector2.ONE * 0.01)
	assert_bool(_graph.menu.visible).is_false()


func test_the_wheel_zooms_around_the_cursor() -> void:
	var cursor := Vector2(700, 150)
	var under := _graph.view.to_content(cursor)
	var zoom := _graph.view.zoom
	_wheel(cursor, MOUSE_BUTTON_WHEEL_UP)
	assert_float(_graph.view.zoom).is_equal_approx(zoom * NetworkGraph.ZOOM_STEP, 0.0001)
	assert_vector(_graph.view.to_content(cursor)).is_equal_approx(under, Vector2.ONE * 0.01)
	_wheel(cursor, MOUSE_BUTTON_WHEEL_DOWN)
	assert_float(_graph.view.zoom).is_equal_approx(zoom, 0.0001)


func test_the_menu_stays_inside_the_panel_wherever_its_node_is() -> void:
	var panel := Rect2(Vector2.ZERO, _graph.size).grow(0.01)
	_graph.zoom_at(_graph.size * 0.5, 2.0)
	# Each node in turn at a corner or an edge of the panel, its menu open.
	for target: String in ["Switch 1", "Terminal", _network.rows[30].name, _network.rows[59].name]:
		for corner: Vector2 in [
			Vector2(5, 5), Vector2(1040, 5), Vector2(5, 430), Vector2(1040, 430), Vector2(520, 220)
		]:
			_graph.pan(corner - _graph.node_screen_rect(target).get_center())
			_graph.select(target)
			var menu := Rect2(_graph.menu.position, _graph.menu.size)
			(
				assert_bool(panel.encloses(menu))
				. override_failure_message("%s at %s: %s" % [target, corner, menu])
				. is_true()
			)
	# In the open, it covers neither its node nor scrolls with the map: it follows its node, clamped.
	_graph.pan(Vector2(520, 220) - _graph.node_screen_rect("Switch 1").get_center())
	_graph.select("Switch 1")
	var shown := _graph.node_screen_rect("Switch 1")
	assert_bool(Rect2(_graph.menu.position, _graph.menu.size).intersects(shown)).is_false()
	_graph.pan(Vector2(5000, 5000))
	assert_bool(panel.encloses(Rect2(_graph.menu.position, _graph.menu.size))).is_true()


func test_fit_shows_the_whole_network_again() -> void:
	var fitted_zoom := _graph.view.zoom
	var fitted_offset := _graph.view.offset
	_graph.zoom_at(Vector2(100, 100), 3.0)
	_graph.pan(Vector2(-300, 120))
	_graph.fit_button.pressed.emit()
	assert_float(_graph.view.zoom).is_equal_approx(fitted_zoom, 0.0001)
	assert_vector(_graph.view.offset).is_equal_approx(fitted_offset, Vector2.ONE * 0.01)
	var panel := Rect2(Vector2.ZERO, _graph.size).grow(0.01)
	for row in _network.rows:
		assert_bool(panel.encloses(_graph.node_screen_rect(row.name))).override_failure_message(row.name).is_true()


# A node whose box is well inside the panel (not the first: the menu tests use it).
func _visible_node() -> String:
	var inner := Rect2(Vector2(80, 60), _graph.size - Vector2(160, 120))
	for i in range(5, _network.rows.size()):
		var name := _network.rows[i].name
		if inner.encloses(_graph.node_screen_rect(name)):
			return name
	return ""


# A point of the panel on no node (scanning a grid).
func _background_point() -> Vector2:
	for y in range(20, int(_graph.size.y), 20):
		for x in range(20, int(_graph.size.x), 20):
			var point := Vector2(x, y)
			if (
				_graph.node_name_at(point).is_empty()
				and not Rect2(_graph.menu.position, _graph.menu.size).has_point(point)
			):
				if not Rect2(_graph.fit_button.position, _graph.fit_button.size).has_point(point):
					return point
	return Vector2(5, 5)


func _to_graph(canvas_point: Vector2) -> Vector2:
	return _graph.get_global_transform_with_canvas().affine_inverse() * canvas_point


func _to_canvas(local: Vector2) -> Vector2:
	return _graph.get_global_transform_with_canvas() * local


func _click(local: Vector2) -> void:
	_press(local, true)
	_press(local, false)


func _press(local: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = _to_canvas(local)
	event.global_position = event.position
	get_viewport().push_input(event, true)


func _move(local: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = _to_canvas(local)
	event.global_position = event.position
	get_viewport().push_input(event, true)


func _wheel(local: Vector2, button: MouseButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.factor = 1.0
		event.position = _to_canvas(local)
		event.global_position = event.position
		get_viewport().push_input(event, true)
