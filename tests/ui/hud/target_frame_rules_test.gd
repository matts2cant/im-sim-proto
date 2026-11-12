extends GdUnitTestSuite
## Unit: the interaction frame's pure rules (ADR 0129): framed kinds, near-plane clipping, the
## screen rectangle (padding, clamping), bracket sizes and the name tag's place.

const SCREEN := Vector2(1920, 1080)


func test_frames_what_can_be_picked_up_used_or_carried() -> void:
	for kind: Interactor.Kind in [
		Interactor.Kind.PICK_UP, Interactor.Kind.USE, Interactor.Kind.CARRY, Interactor.Kind.TOO_HEAVY
	]:
		assert_bool(TargetFrameRules.frames(kind)).is_true()
	for kind: Interactor.Kind in [Interactor.Kind.NONE, Interactor.Kind.PUT_DOWN, Interactor.Kind.NO_ROOM]:
		assert_bool(TargetFrameRules.frames(kind)).is_false()


func test_a_box_in_front_keeps_its_corners() -> void:
	var front := TargetFrameRules.clip_to_front(_corners(AABB(Vector3(-0.5, -0.5, -3.0), Vector3.ONE)), 0.05)

	assert_int(front.size()).is_equal(8)


func test_a_box_behind_the_camera_has_nothing_in_front() -> void:
	var front := TargetFrameRules.clip_to_front(_corners(AABB(Vector3(-0.5, -0.5, 1.0), Vector3.ONE)), 0.05)

	assert_bool(front.is_empty()).is_true()


func test_a_box_across_the_near_plane_is_cut_at_it() -> void:
	# From 0.5 m behind the eye to 1.5 m in front: 4 corners in front, 4 edges cut at z = -0.05.
	var front := TargetFrameRules.clip_to_front(_corners(AABB(Vector3(-1, -1, -1.5), Vector3(2, 2, 2))), 0.05)

	assert_int(front.size()).is_equal(8)
	var cut := 0
	for point in front:
		assert_float(point.z).is_less_equal(-0.05 + 0.0001)
		if is_equal_approx(point.z, -0.05):
			cut += 1
	assert_int(cut).is_equal(4)


func test_rect_of_points() -> void:
	var rect := TargetFrameRules.rect_of(PackedVector2Array([Vector2(10, 40), Vector2(30, 20), Vector2(20, 60)]))

	assert_vector(rect.position).is_equal(Vector2(10, 20))
	assert_vector(rect.size).is_equal(Vector2(20, 40))
	assert_bool(TargetFrameRules.rect_of(PackedVector2Array()).has_area()).is_false()


func test_frame_is_padded() -> void:
	var frame := TargetFrameRules.frame_rect(Rect2(900, 500, 100, 60), SCREEN, 1.0)

	var pad := TargetFrameRules.PADDING
	assert_vector(frame.position).is_equal(Vector2(900 - pad, 500 - pad))
	assert_vector(frame.size).is_equal(Vector2(100 + 2 * pad, 60 + 2 * pad))


func test_a_frame_bigger_than_the_screen_is_clamped_inside_its_margin() -> void:
	# A door up close: its outline runs far off every edge.
	var frame := TargetFrameRules.frame_rect(Rect2(-500, -300, 3000, 2000), SCREEN, 1.0)

	var margin := TargetFrameRules.SCREEN_MARGIN
	assert_vector(frame.position).is_equal(Vector2(margin, margin))
	assert_vector(frame.end).is_equal(SCREEN - Vector2(margin, margin))


func test_a_frame_wholly_off_the_screen_is_hidden() -> void:
	var frame := TargetFrameRules.frame_rect(Rect2(2500, 300, 100, 100), SCREEN, 1.0)

	assert_bool(frame.has_area()).is_false()


func test_sizes_scale_with_the_canvas_height() -> void:
	assert_float(TargetFrameRules.unit(648.0)).is_equal_approx(0.6, 0.0001)
	var padded := TargetFrameRules.frame_rect(Rect2(500, 300, 50, 50), Vector2(1152, 648), 0.6)
	assert_float(padded.size.x).is_equal_approx(50 + 2 * TargetFrameRules.PADDING * 0.6, 0.0001)


func test_line_is_one_pixel_at_1080p_and_never_thinner_than_a_pixel() -> void:
	# A 1080 p window on a 648-unit canvas: 1/1.667 units = one pixel.
	assert_float(TargetFrameRules.line_width(0.6, 1080.0 / 648.0)).is_equal_approx(0.6, 0.0001)
	# A 648 p window: still one pixel, not 0.6.
	assert_float(TargetFrameRules.line_width(0.6, 1.0)).is_equal_approx(1.0, 0.0001)
	# A 2160 p window: two pixels.
	assert_float(TargetFrameRules.line_width(0.6, 2160.0 / 648.0) * 2160.0 / 648.0).is_equal_approx(2.0, 0.0001)


func test_arm_is_a_share_of_the_shorter_side_within_limits() -> void:
	# 100 x 200: 15 % of 100 = 15.
	assert_float(TargetFrameRules.arm_length(Rect2(0, 0, 100, 200), 1.0)).is_equal_approx(15.0, 0.0001)
	# Large: capped at 24.
	assert_float(TargetFrameRules.arm_length(Rect2(0, 0, 600, 400), 1.0)).is_equal_approx(24.0, 0.0001)
	# Small (40 px): raised to 8.
	assert_float(TargetFrameRules.arm_length(Rect2(0, 0, 40, 40), 1.0)).is_equal_approx(8.0, 0.0001)
	# Tiny (10 px): never past half the side.
	assert_float(TargetFrameRules.arm_length(Rect2(0, 0, 10, 30), 1.0)).is_equal_approx(5.0, 0.0001)
	# Scaled limits on a 648-unit canvas.
	assert_float(TargetFrameRules.arm_length(Rect2(0, 0, 600, 400), 0.6)).is_equal_approx(14.4, 0.0001)


func test_brackets_sit_in_the_frame_corners() -> void:
	var frame := Rect2(100, 50, 200, 100)
	var bars := TargetFrameRules.bracket_rects(frame, 20.0, 1.0)

	assert_int(bars.size()).is_equal(8)
	for bar in bars:
		assert_bool(frame.encloses(bar)).is_true()
	# Top-left: a bar along the top and one down the left side.
	assert_object(bars[0]).is_equal(Rect2(100, 50, 20, 1))
	assert_object(bars[1]).is_equal(Rect2(100, 50, 1, 20))
	# Bottom-right: along the bottom, up the right side.
	assert_object(bars[6]).is_equal(Rect2(280, 149, 20, 1))
	assert_object(bars[7]).is_equal(Rect2(299, 130, 1, 20))


func test_tag_sits_inside_a_frame_that_holds_it() -> void:
	var frame := Rect2(100, 100, 300, 200)

	var at := TargetFrameRules.tag_position(frame, Vector2(80, 20), SCREEN, 1.0, 1.0)

	var inset := 1.0 + TargetFrameRules.TAG_INSET
	assert_vector(at).is_equal(frame.position + Vector2(inset, inset))


func test_tag_goes_above_a_small_frame() -> void:
	var frame := Rect2(900, 500, 40, 30)

	var at := TargetFrameRules.tag_position(frame, Vector2(80, 20), SCREEN, 1.0, 1.0)

	assert_vector(at).is_equal(Vector2(900, 500 - 20 - TargetFrameRules.TAG_GAP))


func test_tag_goes_below_a_small_frame_at_the_top_edge() -> void:
	var frame := Rect2(1880, 20, 20, 20)

	var at := TargetFrameRules.tag_position(frame, Vector2(80, 20), SCREEN, 1.0, 1.0)

	assert_float(at.y).is_equal(40 + TargetFrameRules.TAG_GAP)
	assert_float(at.x).is_equal(SCREEN.x - 80 - TargetFrameRules.SCREEN_MARGIN)


func _corners(box: AABB) -> PackedVector3Array:
	var corners := PackedVector3Array()
	for i in 8:
		corners.append(box.get_endpoint(i))
	return corners
