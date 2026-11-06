extends GdUnitTestSuite
## Unit: AwarenessModel (ADR 0068): meter, Unaware -> Suspicious -> Unaware (wary), noises, harm,
## external alerts, reset and saving. Searching: awareness_model_search_test.gd.

const CONFIG: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const TICK := 1.0 / 60.0
const POINT := Vector3(3, 0, -4)

var _model: AwarenessModel
var _changes: Array[Dictionary] = []


func before_test() -> void:
	_model = AwarenessModel.new(CONFIG, 7)
	_changes = []
	_model.state_changed.connect(
		func(from: AwarenessModel.State, to: AwarenessModel.State, reason: String) -> void:
			_changes.append({"from": from, "to": to, "reason": reason})
	)


func test_sight_raises_the_meter_to_suspicious_then_alerted() -> void:
	_see(1.25, 0.2)
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_model.meter).is_equal_approx(0.25, 0.01)
	_see(1.25, 0.1)
	assert_int(_model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK)
	assert_vector(_model.point).is_equal(POINT)
	_see(1.25, 0.8)
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.CHASE)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.RUN)
	assert_array(_changes.map(func(c: Dictionary) -> String: return c["reason"])).is_equal(["sight", "sight"])


func test_meter_decays_when_unseen() -> void:
	_see(1.25, 0.2)
	_unseen(0.5)
	assert_float(_model.meter).is_equal_approx(0.25 - 0.125, 0.01)
	_unseen(2.0)
	assert_float(_model.meter).is_equal(0.0)


func test_suspicious_looks_then_walks_to_the_point_then_looks_around_then_calms_down_wary() -> void:
	_model.hear(POINT, 3.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK)
	_unseen(1.9)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK)
	_unseen(0.2)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.INVESTIGATE)
	assert_vector(_model.destination).is_equal(POINT)
	_model.arrived()
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK_AROUND)
	_unseen(3.8)
	assert_int(_model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	_unseen(0.3)
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_str(_model.reason).is_equal("nothing_found")
	assert_bool(_model.is_wary()).is_true()
	assert_float(_model.wary_time).is_equal_approx(60.0, 0.1)


func test_loud_noise_skips_the_look_and_runs() -> void:
	_model.hear(POINT, 12.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.RUN)


func test_new_evidence_moves_the_point() -> void:
	_model.hear(POINT, 3.0)
	_unseen(2.1)
	var other := Vector3(-2, 0, 5)
	_model.hear(other, 3.0)
	assert_vector(_model.destination).is_equal(other)
	_model.arrived()
	# Far evidence while looking around: walk there again.
	_model.step(TICK, true, 0.1, Vector3(4, 0, 5))
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_vector(_model.destination).is_equal(Vector3(4, 0, 5))


func test_wary_lowers_the_suspicious_threshold() -> void:
	_model.wary_time = 30.0
	_see(1.25, 0.18)
	assert_int(_model.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_float(_model.meter).is_less(0.3)


func test_wariness_runs_out() -> void:
	_model.hear(POINT, 3.0)
	_model.arrived()
	_model.reset()
	_model.wary_time = 1.0
	_unseen(1.1)
	assert_bool(_model.is_wary()).is_false()


func test_harm_and_external_alerts_alert_at_once() -> void:
	_model.harm(POINT)
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_str(_model.reason).is_equal("harm")
	assert_vector(_model.destination).is_equal(POINT)
	var other := AwarenessModel.new(CONFIG, 1)
	other.alert(POINT)
	assert_int(other.state).is_equal(AwarenessModel.State.ALERTED)
	assert_str(other.reason).is_equal("alert")


func test_aware_only_while_alerted_or_searching() -> void:
	assert_bool(_model.is_aware()).is_false()
	_model.hear(POINT, 3.0)
	assert_bool(_model.is_aware()).is_false()
	_model.harm(POINT)
	assert_bool(_model.is_aware()).is_true()
	_unseen(4.1)
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_bool(_model.is_aware()).is_true()


func test_alerted_follows_the_target_and_keeps_the_meter_full() -> void:
	_model.harm(POINT)
	_model.step(TICK, true, 1.0, Vector3(1, 0, 1))
	assert_vector(_model.point).is_equal(Vector3(1, 0, 1))
	_unseen(3.0)
	assert_float(_model.meter).is_equal(1.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	# Seen again: the unseen clock restarts.
	_model.step(TICK, true, 1.0, Vector3(2, 0, 1))
	_unseen(3.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)


func test_reset_forgets_everything_without_a_bark_reason() -> void:
	_model.harm(POINT)
	_model.wary_time = 10.0
	_model.reset()
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_model.meter).is_equal(0.0)
	assert_bool(_model.is_wary()).is_false()
	assert_str(_changes.back()["reason"]).is_equal("reset")


func test_round_trips_through_a_dictionary() -> void:
	_model.hear(POINT, 3.0)
	_unseen(2.5)
	var copy := AwarenessModel.new(CONFIG, 99)
	copy.from_dict(_model.to_dict())
	assert_dict(copy.to_dict()).is_equal(_model.to_dict())
	assert_int(copy.state).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_int(copy.phase).is_equal(AwarenessModel.Phase.MOVE)


func _see(gain: float, seconds: float) -> void:
	for i in roundi(seconds / TICK):
		_model.step(TICK, true, gain, POINT)


func _unseen(seconds: float) -> void:
	for i in roundi(seconds / TICK):
		_model.step(TICK, false, 0.0, Vector3.ZERO)
