extends GdUnitTestSuite
## Unit (ADR 0083): NetworkLayout, the terminal's network graph as a floor plan: world x right,
## world z down, fitted inside the margins and centred, each axis stretched at most `max_stretch`
## times the other, nodes on top of each other pushed `min_gap` apart and kept inside the panel.

const SIZE := Vector2(400, 200)
const MARGIN := 20.0


func _project(points: Array[Vector3], max_stretch: float = 2.0, min_gap: float = 0.0) -> Array[Vector2]:
	return NetworkLayout.project(points, SIZE, MARGIN, max_stretch, min_gap)


func test_corners_land_on_the_margins_top_down() -> void:
	# 10 m x 5 m: room 360 x 160 px, so 36 px/m across and 32 px/m down (stretch 1.125).
	var placed := _project([Vector3(0, 3, 0), Vector3(10, 0, 5), Vector3(5, 1, 2.5)])
	assert_vector(placed[0]).is_equal_approx(Vector2(20, 20), Vector2(0.01, 0.01))
	assert_vector(placed[1]).is_equal_approx(Vector2(380, 180), Vector2(0.01, 0.01))
	# Height does not matter; the middle point is the panel's centre.
	assert_vector(placed[2]).is_equal_approx(Vector2(200, 100), Vector2(0.01, 0.01))


func test_north_is_up_and_east_is_right() -> void:
	var placed := _project([Vector3(0, 0, -4), Vector3(0, 0, 4), Vector3(-3, 0, 0), Vector3(3, 0, 0)])
	assert_float(placed[0].y).is_less(placed[1].y)
	assert_float(placed[2].x).is_less(placed[3].x)


func test_an_axis_is_stretched_at_most_max_stretch_times_the_other() -> void:
	# 10 m x 10 m in a 360 x 160 room: 16 px/m down, so at most 32 px/m across (not 36).
	var placed := _project([Vector3(0, 0, 0), Vector3(10, 0, 10)], 2.0)
	assert_float(placed[1].x - placed[0].x).is_equal_approx(320.0, 0.01)
	assert_float(placed[1].y - placed[0].y).is_equal_approx(160.0, 0.01)
	# Uniform (a true floor plan) with max_stretch 1.
	var uniform := _project([Vector3(0, 0, 0), Vector3(10, 0, 10)], 1.0)
	assert_float(uniform[1].x - uniform[0].x).is_equal_approx(160.0, 0.01)
	assert_float((uniform[0] + uniform[1]).x * 0.5).is_equal_approx(200.0, 0.01)


func test_a_line_and_a_single_point_are_centred() -> void:
	var line := _project([Vector3(0, 0, 7), Vector3(8, 0, 7)])
	assert_float(line[0].y).is_equal_approx(100.0, 0.01)
	assert_float(line[1].x - line[0].x).is_equal_approx(360.0, 0.01)
	var single := _project([Vector3(4, 2, -9)])
	assert_vector(single[0]).is_equal_approx(SIZE * 0.5, Vector2(0.01, 0.01))
	assert_array(_project([])).is_empty()


func test_stacked_devices_are_pushed_apart_and_stay_inside() -> void:
	# Two devices on one wall spot (a siren above a controller), one 1 cm away, one far.
	var placed := _project([Vector3(0, 1, 0), Vector3(0, 3, 0), Vector3(0.01, 0, 0), Vector3(10, 0, 5)], 2.0, 60.0)
	var inside := Rect2(Vector2(MARGIN, MARGIN), SIZE - Vector2(MARGIN, MARGIN) * 2.0).grow(0.01)
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var gap := placed[i].distance_to(placed[j])
			assert_float(gap).override_failure_message("%d-%d: %.1f" % [i, j, gap]).is_greater_equal(59.0)
		assert_bool(inside.has_point(placed[i])).is_true()
