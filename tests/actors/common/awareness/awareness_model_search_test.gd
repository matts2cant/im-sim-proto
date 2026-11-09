extends GdUnitTestSuite
## Unit: AwarenessModel Searching (ADR 0068): a lost target starts a search of random points around
## the last known position (run, then walk), which ends in Unaware and wary.

const CONFIG: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")
const TICK := 1.0 / 60.0
const LAST_KNOWN := Vector3(5, 0, -5)

var _model: AwarenessModel


func before_test() -> void:
	_model = AwarenessModel.new(CONFIG, 3)
	_model.harm(LAST_KNOWN)
	_unseen(4.1)


func test_lost_target_starts_a_search_at_run_pace() -> void:
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_str(_model.reason).is_equal("lost")
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_int(_model.pace).is_equal(AwarenessModel.Pace.RUN)
	assert_int(_model.search_index).is_equal(1)
	_assert_near_last_known(_model.destination)


func test_visits_the_search_points_walking_after_the_first_then_gives_up_wary() -> void:
	var destinations: Array[Vector3] = [_model.destination]
	for visit in CONFIG.search_points:
		_model.arrived()
		assert_int(_model.phase).is_equal(AwarenessModel.Phase.LOOK_AROUND)
		_unseen(CONFIG.search_look_time + 0.1)
		if visit < CONFIG.search_points - 1:
			assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
			assert_int(_model.pace).is_equal(AwarenessModel.Pace.WALK)
			_assert_near_last_known(_model.destination)
			destinations.append(_model.destination)
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_str(_model.reason).is_equal("search_over")
	assert_bool(_model.is_wary()).is_true()
	assert_int(destinations.size()).is_equal(CONFIG.search_points)
	# Random points, not the same one again.
	assert_vector(destinations[0]).is_not_equal(destinations[1])


func test_search_gives_up_after_its_duration() -> void:
	_unseen(CONFIG.search_duration - 1.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	_unseen(1.2)
	assert_int(_model.state).is_equal(AwarenessModel.State.UNAWARE)
	assert_str(_model.reason).is_equal("search_over")


func test_seeing_the_target_while_searching_alerts() -> void:
	_model.step(TICK, true, 0.2, Vector3(1, 0, 1))
	assert_int(_model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_vector(_model.point).is_equal(Vector3(1, 0, 1))


func test_a_noise_while_searching_sends_it_there() -> void:
	_model.hear(Vector3(-3, 0, 2), 4.0)
	assert_int(_model.state).is_equal(AwarenessModel.State.SEARCHING)
	assert_int(_model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_vector(_model.destination).is_equal(Vector3(-3, 0, 2))


func test_a_searcher_needs_the_meter_at_0_2_to_alert() -> void:
	# ADR 0095: a glimpse of a target moving in the dark (about 0.2/s with the wary gain) is not
	# enough at once; a lit one (about 1.9/s) still alerts within a fraction of a second.
	var model := AwarenessModel.new(CONFIG, 5)
	model.search_at(LAST_KNOWN, "alarm")
	assert_float(model.meter).is_equal(0.0)
	for i in 30:
		model.step(TICK, true, 0.2, LAST_KNOWN)
	assert_int(model.state).is_equal(AwarenessModel.State.SEARCHING)
	for i in 42:
		model.step(TICK, true, 0.2, LAST_KNOWN)
	assert_int(model.state).is_equal(AwarenessModel.State.ALERTED)
	assert_str(model.reason).is_equal("sight")

	var lit := AwarenessModel.new(CONFIG, 6)
	lit.search_at(LAST_KNOWN, "alarm")
	for i in 9:
		lit.step(TICK, true, 1.9, LAST_KNOWN)
	assert_int(lit.state).is_equal(AwarenessModel.State.ALERTED)


func _assert_near_last_known(point: Vector3) -> void:
	assert_float(Vector2(point.x - LAST_KNOWN.x, point.z - LAST_KNOWN.z).length()).is_less_equal(CONFIG.search_radius)


func _unseen(seconds: float) -> void:
	for i in roundi(seconds / TICK):
		_model.step(TICK, false, 0.0, Vector3.ZERO)
