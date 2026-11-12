extends GdUnitTestSuite
## Unit (ADR 0085, amended 2026-11-12): the scope view draws the HUD crosshair at the centre of its
## lens. The aim offset (sway, recoil) moves the lens and the crosshair together: their centres are
## the same for any offset; the arms keep the minimum gap at a cone of 0; the duplex lines stop short
## of the arms' outer ends (none when the arms reach past the lens).


func _overlay() -> ScopeOverlay:
	var overlay := auto_free(ScopeOverlay.new()) as ScopeOverlay
	overlay.size = Vector2(1920, 1080)
	return overlay


func test_the_crosshair_is_always_at_the_lens_centre() -> void:
	var overlay := _overlay()
	for offset: Vector2 in [Vector2.ZERO, Vector2(13.4, -7.2), Vector2(-40.0, 25.6), Vector2(3.7, 61.1)]:
		overlay.show_cone(12.0, offset)
		var centre := overlay.lens_centre()
		# The lens moved with the offset (on a pixel centre).
		assert_float(centre.distance_to(overlay.size * 0.5 + offset)).is_less(0.71)
		assert_vector(overlay.crosshair_centre()).is_equal(centre)
		for arm in overlay.arm_segments():
			assert_float(arm[0].distance_to(centre)).is_equal_approx(12.0, 0.001)


func test_the_arms_draw_at_a_cone_of_0() -> void:
	var overlay := _overlay()
	overlay.show_cone(0.0, Vector2(5.0, -2.0))
	var arms := overlay.arm_segments()
	assert_int(arms.size()).is_equal(4)
	for arm in arms:
		assert_float(arm[0].distance_to(overlay.crosshair_centre())).is_equal_approx(7.0, 0.001)


func test_the_duplex_lines_stop_short_of_the_arms() -> void:
	var overlay := _overlay()
	overlay.show_cone(30.0, Vector2(-9.0, 4.0))
	var centre := overlay.crosshair_centre()
	var outer := 30.0 + Reticle.ARM_LENGTH_1080
	var lines := overlay.line_segments()
	assert_int(lines.size()).is_equal(4)
	for line in lines:
		assert_float(line[0].distance_to(centre)).is_equal_approx(overlay.lens_radius(), 0.001)
		assert_float(line[1].distance_to(centre)).is_greater(outer + 4.0)
	# A cone as wide as the lens: no lines.
	overlay.show_cone(overlay.lens_radius(), Vector2.ZERO)
	assert_array(overlay.line_segments()).is_empty()
