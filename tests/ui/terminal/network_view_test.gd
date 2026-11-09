extends GdUnitTestSuite
## Unit (ADR 0099): NetworkView, the network map's pan and zoom. A content point shows at
## `point * zoom + offset`; fit() centres the content and shows all of it (never zoomed in past
## FIT_MAX_ZOOM); zoom_at() keeps the point under the cursor still within min_zoom..MAX_ZOOM; pan()
## and zooming keep at least KEEP_VISIBLE px of the content in the panel.

const PANEL := Vector2(1000, 400)


func _fitted(content: Rect2, margin: float = 20.0) -> NetworkView:
	var view := NetworkView.new()
	view.fit(content, PANEL, margin)
	return view


func test_screen_and_content_points_are_inverse() -> void:
	var view := NetworkView.new()
	view.zoom = 1.6
	view.offset = Vector2(-30, 75)
	var point := Vector2(123.5, -42.25)
	assert_vector(view.to_screen(point)).is_equal_approx(point * 1.6 + Vector2(-30, 75), Vector2.ONE * 0.001)
	assert_vector(view.to_content(view.to_screen(point))).is_equal_approx(point, Vector2.ONE * 0.001)
	var rect := view.rect_to_screen(Rect2(10, 20, 30, 40))
	assert_vector(rect.size).is_equal_approx(Vector2(48, 64), Vector2.ONE * 0.001)


func test_fit_shows_everything_centred() -> void:
	# 1920 x 480 content in 960 x 360 of room: zoom 0.5 (the width decides), centred.
	var content := Rect2(-200, -50, 1920, 480)
	var view := _fitted(content)
	assert_float(view.zoom).is_equal_approx(0.5, 0.0001)
	var shown := view.rect_to_screen(content)
	assert_vector(shown.get_center()).is_equal_approx(PANEL * 0.5, Vector2.ONE * 0.001)
	assert_bool(Rect2(Vector2.ONE * 20.0, PANEL - Vector2.ONE * 40.0).grow(0.01).encloses(shown)).is_true()


func test_fit_never_zooms_a_small_network_in() -> void:
	var view := _fitted(Rect2(0, 0, 200, 100))
	assert_float(view.zoom).is_equal(NetworkView.FIT_MAX_ZOOM)
	assert_vector(view.rect_to_screen(Rect2(0, 0, 200, 100)).get_center()).is_equal_approx(
		PANEL * 0.5, Vector2.ONE * 0.001
	)


func test_zooming_keeps_the_point_under_the_cursor() -> void:
	var view := _fitted(Rect2(0, 0, 1500, 600))
	var cursor := Vector2(300, 150)
	var under := view.to_content(cursor)
	view.zoom_at(cursor, 1.15)
	assert_vector(view.to_content(cursor)).is_equal_approx(under, Vector2.ONE * 0.001)
	view.zoom_at(cursor, 1.0 / 1.15)
	view.zoom_at(cursor, 1.0 / 1.15)
	assert_vector(view.to_content(cursor)).is_equal_approx(under, Vector2.ONE * 0.001)


func test_zoom_stays_within_its_limits() -> void:
	var view := _fitted(Rect2(0, 0, 900, 300))
	for i in 40:
		view.zoom_at(PANEL * 0.5, 1.15)
	assert_float(view.zoom).is_equal(NetworkView.MAX_ZOOM)
	for i in 80:
		view.zoom_at(PANEL * 0.5, 1.0 / 1.15)
	assert_float(view.zoom).is_equal(NetworkView.MIN_ZOOM)
	# A network that needs less than MIN_ZOOM to fit can still be zoomed out to its fit.
	var big := _fitted(Rect2(0, 0, 9600, 400))
	assert_float(big.zoom).is_less(NetworkView.MIN_ZOOM)
	var fitted := big.zoom
	big.zoom_at(PANEL * 0.5, 1.5)
	for i in 20:
		big.zoom_at(PANEL * 0.5, 1.0 / 1.15)
	assert_float(big.zoom).is_equal_approx(fitted, 0.0001)


func test_panning_moves_the_view_but_never_loses_the_network() -> void:
	var content := Rect2(0, 0, 1500, 600)
	var view := _fitted(content)
	view.zoom_at(PANEL * 0.5, 2.0)
	var before := view.offset
	view.pan(Vector2(40, -25))
	assert_vector(view.offset).is_equal_approx(before + Vector2(40, -25), Vector2.ONE * 0.001)
	# Dragged far off in every direction: KEEP_VISIBLE px stay in the panel.
	for push: Vector2 in [Vector2(5000, 0), Vector2(-5000, 0), Vector2(0, 5000), Vector2(0, -5000)]:
		view.pan(push)
		var shown := view.rect_to_screen(content)
		var overlap := shown.intersection(Rect2(Vector2.ZERO, PANEL))
		assert_float(minf(overlap.size.x, overlap.size.y)).override_failure_message(str(push)).is_greater_equal(
			NetworkView.KEEP_VISIBLE - 0.01
		)


func test_resizing_the_panel_keeps_its_centre() -> void:
	var view := _fitted(Rect2(0, 0, 1500, 600))
	view.zoom_at(Vector2(200, 100), 1.5)
	var middle := view.to_content(PANEL * 0.5)
	view.resize(Vector2(800, 500))
	assert_vector(view.to_content(Vector2(400, 250))).is_equal_approx(middle, Vector2.ONE * 0.001)
