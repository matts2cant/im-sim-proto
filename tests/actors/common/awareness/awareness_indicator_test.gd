extends GdUnitTestSuite
## Integration: AwarenessIndicator on the guard (icons per state, barks with their log entries,
## the debug-panel toggles) and the Overlays tab's AwarenessToggles.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const BARKS: BarkLines = preload("res://actors/guard/guard_barks.tres")
const TOGGLES := "res://ui/debug_panel/tabs/awareness_toggles.tscn"

var _g: Guards
var _indicator: AwarenessIndicator


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	AwarenessIndicator.show_icons = true
	AwarenessIndicator.show_state = false
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST))
	_indicator = _g.guard.get_node("Indicator") as AwarenessIndicator


func after_test() -> void:
	_g.teardown()
	AwarenessIndicator.show_icons = true
	AwarenessIndicator.show_state = false


func test_no_icon_while_unaware() -> void:
	await _g.frames(1)
	assert_bool(_indicator.icon.visible).is_false()
	assert_str(_indicator.icon_text()).is_empty()


func test_question_mark_while_suspicious_and_exclamation_while_alerted() -> void:
	_g.awareness.notice_noise(Vector3(3, 0, 0), 3.0, null)
	await _g.frames(2)
	assert_bool(_indicator.icon.visible).is_true()
	assert_str(_indicator.icon.text).is_equal("?")
	assert_that(_indicator.icon.modulate).is_equal(AwarenessIndicator.SUSPICIOUS_COLOR)

	_g.awareness.alert_at(Vector3(3, 0, 0))
	await _g.frames(2)
	assert_str(_indicator.icon.text).is_equal("!")
	assert_that(_indicator.icon.modulate).is_equal(AwarenessIndicator.ALERTED_COLOR)


func test_state_change_barks_a_line_for_two_seconds_and_logs_it() -> void:
	_g.awareness.notice_noise(Vector3(3, 0, 0), 3.0, null)
	await _g.frames(2)

	var barks := EventLog.find(&"actor.bark")
	assert_array(barks).has_size(1)
	assert_array(BARKS.suspicious).contains([barks[0].data["line"]])
	assert_str(barks[0].data["to"]).is_equal("suspicious")
	assert_bool(_indicator.bark.visible).is_true()
	assert_str(_indicator.bark.text).is_equal(barks[0].data["line"])
	assert_object(_indicator.audio.stream).is_not_null()
	_indicator.advance(2.1)
	assert_bool(_indicator.bark.visible).is_false()


func test_knocked_out_guard_shows_nothing_and_does_not_bark() -> void:
	_g.awareness.alert_at(Vector3(3, 0, 0))
	await _g.frames(2)
	EventLog.clear()
	ActorState.set_tag(_g.guard, ActorState.UNCONSCIOUS, true)
	await _g.frames(2)
	_indicator.refresh()

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	assert_array(EventLog.find(&"actor.bark")).is_empty()
	assert_bool(_indicator.icon.visible).is_false()


func test_toggles_hide_icons_and_show_state_text() -> void:
	_g.awareness.alert_at(Vector3(3, 0, 0))
	await _g.frames(2)
	AwarenessIndicator.show_icons = false
	AwarenessIndicator.show_state = true
	_indicator.refresh()

	assert_bool(_indicator.icon.visible).is_false()
	assert_bool(_indicator.status.visible).is_true()
	assert_str(_indicator.status.text).starts_with("alerted 1.00")


func test_overlays_tab_checkboxes_drive_the_toggles() -> void:
	var toggles := auto_free(load(TOGGLES).instantiate()) as AwarenessToggles
	add_child(toggles)
	assert_bool(toggles.icons.button_pressed).is_true()
	assert_bool(toggles.state_text.button_pressed).is_false()

	toggles.icons.button_pressed = false
	toggles.state_text.button_pressed = true

	assert_bool(AwarenessIndicator.show_icons).is_false()
	assert_bool(AwarenessIndicator.show_state).is_true()
