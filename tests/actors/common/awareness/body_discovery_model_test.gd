extends GdUnitTestSuite
## Unit: BodyDiscoveryModel (ADR 0071): discovery builds up at the vision gain while a body is seen,
## decays while it is not, finds each body once and forgets it when it stands up again.

const CONFIG: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const TICK := 1.0 / 60.0

var _model: BodyDiscoveryModel


func before_test() -> void:
	_model = BodyDiscoveryModel.new(CONFIG.body_discovery_threshold, CONFIG.body_discovery_decay)


func test_a_lit_body_at_4_m_is_found_in_about_0_8_s() -> void:
	# Lit, in focus, within 5 m: gain 1.25 per second (VisionRules).
	assert_float(_seconds_to_find({"Body": 1.25})).is_equal_approx(0.8, 0.05)


func test_a_dark_body_close_up_takes_longer() -> void:
	# Dark at 1.5 m: the close override gives light 0.5, gain 0.625 per second.
	assert_float(_seconds_to_find({"Body": 0.625})).is_equal_approx(1.6, 0.05)


func test_progress_decays_while_unseen() -> void:
	for i in 30:
		_model.step(TICK, {"Body": 1.25})
	assert_float(_model.progress["Body"]).is_equal_approx(0.625, 0.02)
	var nothing: Dictionary[String, float] = {}
	for i in 120:
		_model.step(TICK, nothing)
	assert_bool(_model.progress.has("Body")).is_false()
	assert_bool(_model.is_found("Body")).is_false()


func test_found_once_until_forgotten() -> void:
	_seconds_to_find({"Body": 1.25})
	var again: Array[String] = []
	for i in 120:
		again.append_array(_model.step(TICK, {"Body": 1.25}))
	assert_array(again).is_empty()
	_model.forget("Body")
	assert_float(_seconds_to_find({"Body": 1.25})).is_equal_approx(0.8, 0.05)


func test_saved_and_loaded() -> void:
	_seconds_to_find({"A": 1.25})
	for i in 20:
		_model.step(TICK, {"B": 1.0})
	var copy := BodyDiscoveryModel.new()
	copy.from_dict(_model.to_dict())
	assert_bool(copy.is_found("A")).is_true()
	assert_float(copy.progress["B"]).is_equal_approx(_model.progress["B"], 0.0001)


func _seconds_to_find(seen: Dictionary[String, float]) -> float:
	for i in 600:
		if not _model.step(TICK, seen).is_empty():
			return (i + 1) * TICK
	return -1.0
