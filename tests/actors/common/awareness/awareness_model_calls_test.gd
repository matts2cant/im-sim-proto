extends GdUnitTestSuite
## Unit: AwarenessModel inputs of bodies and calls (ADR 0071, ADR 0072): discover_body() (Searching
## around a body, tending an unconscious one), search_at() (shouts, radio, alarm, being woken),
## make_wary() and the longer wariness after a body.

const CONFIG: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const TICK := 1.0 / 60.0
const BODY := Vector3(4, 0, -6)
const BESIDE := Vector3(4, 0, -5)

var _model: AwarenessModel


func before_test() -> void:
	_model = AwarenessModel.new(CONFIG, 5)


func test_a_found_body_starts_a_search_that_runs_to_it_first() -> void:
	assert_bool(_model.discover_body(BODY, BESIDE, false)).is_true()
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_str(_model.reason).is_equal("body")
	assert_vector(_model.point).is_equal(BODY)
	assert_vector(_model.destination).is_equal(BESIDE)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.RUN)
	assert_float(_model.wary_time).is_equal(CONFIG.body_wary_duration)
	# Dead body: arriving looks around, as at any search point.
	_model.arrived()
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK_AROUND)


func test_an_unconscious_body_is_tended_until_end_tend() -> void:
	_model.discover_body(BODY, BESIDE, true)
	assert_bool(_model.tending).is_true()
	_model.arrived()
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.TEND)
	_step(CONFIG.wake_time + 0.5)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.TEND)
	_model.end_tend()
	assert_bool(_model.tending).is_false()
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK_AROUND)
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)


func test_a_tend_that_never_wakes_gives_up_after_the_timeout() -> void:
	_model.discover_body(BODY, BESIDE, true)
	_model.arrived()
	_step(CONFIG.tend_timeout + 0.5)
	assert_bool(_model.tending).is_false()
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_int(_model.phase).is_not_equal(AwarenessModel.Phase.TEND)


func test_an_alerted_character_keeps_fighting_but_turns_wary() -> void:
	_model.alert(Vector3(0, 0, -10))
	assert_bool(_model.discover_body(BODY, BESIDE, true)).is_false()
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_bool(_model.tending).is_false()
	assert_float(_model.wary_time).is_equal(CONFIG.body_wary_duration)


func test_sight_ends_a_tend() -> void:
	_model.discover_body(BODY, BESIDE, true)
	_model.arrived()
	for i in 60:
		_model.step(TICK, true, 2.0, Vector3(0, 0, -8))
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_bool(_model.tending).is_false()


func test_a_call_starts_a_search_at_the_caller() -> void:
	var caller := Vector3(-3, 0, 2)
	assert_bool(_model.search_at(caller, "shout")).is_true()
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_str(_model.reason).is_equal("shout")
	assert_vector(_model.destination).is_equal(caller)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.RUN)
	# Then random points, walking.
	_model.arrived()
	_step(CONFIG.search_look_time + 0.1)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.WALK)
	assert_float(_model.destination.distance_to(caller)).is_less_equal(CONFIG.search_radius + 0.01)


func test_calls_do_not_interrupt_an_alert_or_a_tend() -> void:
	_model.alert(Vector3(0, 0, -10))
	assert_bool(_model.search_at(Vector3(5, 0, 5), "radio")).is_false()
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	var tender := AwarenessModel.new(CONFIG, 6)
	tender.discover_body(BODY, BESIDE, true)
	assert_bool(tender.search_at(Vector3(5, 0, 5), "shout")).is_false()
	assert_vector(tender.destination).is_equal(BESIDE)


func test_after_a_body_the_search_ends_still_wary_for_longer_than_usual() -> void:
	_model.discover_body(BODY, BESIDE, false)
	_step(CONFIG.search_duration + 0.5)
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_model.wary_time).is_greater(CONFIG.wary_duration + 60.0)


func test_tending_is_saved() -> void:
	_model.discover_body(BODY, BESIDE, true)
	var copy := AwarenessModel.new(CONFIG, 5)
	copy.from_dict(_model.to_dict())
	assert_bool(copy.tending).is_true()


func _step(seconds: float) -> void:
	for i in roundi(seconds / TICK):
		_model.step(TICK, false, 0.0, Vector3.ZERO)
