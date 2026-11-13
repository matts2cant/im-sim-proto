extends GdUnitTestSuite
## Integration: the Overlays tab's Stimuli checkbox and the StimulusOverlay it drives, fed by the
## real StimulusSystem.

const Wait := preload("res://tests/helpers/wait.gd")

var _overlay: StimulusOverlay


func before_test() -> void:
	StimulusSystem.clear()
	_overlay = DebugPanel.stimulus_overlay
	_overlay.enabled = false


func after_test() -> void:
	_set_checkbox(false)
	_overlay.enabled = false


func test_overlays_tab_is_registered() -> void:
	assert_object(_overlays_tab()).is_not_null()


func test_checkbox_toggles_the_overlay() -> void:
	_set_checkbox(true)
	assert_bool(_overlay.enabled).is_true()

	_set_checkbox(false)
	assert_bool(_overlay.enabled).is_false()


func test_draws_processed_stimuli_while_enabled() -> void:
	_set_checkbox(true)

	StimulusSystem.emit(Stimulus.make_noise(6.0, Vector3(1, 0, 1)))
	await Wait.frames(get_tree(), 2)

	assert_int(_overlay.active_count()).is_equal(1)
	var mesh := _overlay.mesh as ImmediateMesh
	assert_int(mesh.get_surface_count()).is_equal(1)
	# Three circles of CIRCLE_SEGMENTS line segments, two vertices each.
	assert_int(_overlay.vertex_count()).is_equal(3 * StimulusOverlay.CIRCLE_SEGMENTS * 2)


func test_drawings_expire_after_lifetime() -> void:
	_set_checkbox(true)
	StimulusSystem.emit(Stimulus.make_noise(6.0, Vector3.ZERO))
	await Wait.frames(get_tree(), 2)

	_overlay.advance(_overlay.lifetime)

	assert_int(_overlay.active_count()).is_equal(0)
	assert_int((_overlay.mesh as ImmediateMesh).get_surface_count()).is_equal(0)


func test_nothing_is_drawn_while_disabled() -> void:
	StimulusSystem.emit(Stimulus.make_noise(6.0, Vector3.ZERO))
	await Wait.frames(get_tree(), 2)

	assert_int(_overlay.active_count()).is_equal(0)


func test_ray_and_path_polylines_are_drawn_as_lines() -> void:
	var paths: Array[PackedVector3Array] = [PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -2), Vector3(2, 0, -2)])]

	_overlay.track(Stimulus.make_ray(&"damage.ballistic", 1.0, Vector3.ZERO, Vector3.FORWARD, 5.0), paths)

	assert_int(_overlay.vertex_count()).is_equal(4)


func test_contact_stimulus_draws_nothing() -> void:
	_overlay.track(Stimulus.make_contact(&"damage.blunt", 1.0, null), [] as Array[PackedVector3Array])

	assert_int(_overlay.active_count()).is_equal(0)


func test_colour_per_type_family() -> void:
	assert_object(StimulusOverlay.color_for(&"noise")).is_equal(StimulusOverlay.TYPE_COLORS[&"noise"])
	assert_object(StimulusOverlay.color_for(&"damage.fire")).is_equal(StimulusOverlay.TYPE_COLORS[&"damage"])
	assert_object(StimulusOverlay.color_for(&"fire")).is_not_equal(StimulusOverlay.color_for(&"noise"))
	assert_object(StimulusOverlay.color_for(&"custom")).is_equal(StimulusOverlay.color_for(&"custom"))


func _overlays_tab() -> OverlaysTab:
	var tabs: TabContainer = DebugPanel.get_node("TabContainer")
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Overlays":
			return tabs.get_tab_control(i) as OverlaysTab
	return null


func _set_checkbox(pressed: bool) -> void:
	var checkbox: CheckBox = _overlays_tab().get_node("Stimuli")
	checkbox.button_pressed = pressed
