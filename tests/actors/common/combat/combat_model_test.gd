extends GdUnitTestSuite
## Unit: CombatModel (ADR 0070), pure: reaction, shot intervals, losing the target, the AI aim
## cone (range, fast targets, settling on a still target) and the preferred-range moves. Tuning: the
## guard's combat config (guard_combat.tres); test points sit away from the thresholds.

const CONFIG: CombatConfig = preload("res://actors/guard/guard_combat.tres")
const DT := 1.0 / 60.0

var _model: CombatModel


func before_test() -> void:
	_model = CombatModel.new(CONFIG, 5)
	_model.begin()


func test_reaction_needs_half_a_second_of_sight() -> void:
	_steps(20, true, 0.0)
	assert_bool(_model.ready_to_fire()).is_false()
	# Unseen for a moment (within the grace) keeps what was spent.
	_steps(10, false, 0.0)
	assert_bool(_model.lost()).is_false()
	_steps(12, true, 0.0)
	assert_bool(_model.ready_to_fire()).is_true()


func test_shots_are_spaced_by_the_configured_interval() -> void:
	_steps(40, true, 0.0)
	for i in 50:
		assert_bool(_model.ready_to_fire()).is_true()
		_model.fired()
		assert_float(_model.shot_wait).is_between(CONFIG.shot_interval_min, CONFIG.shot_interval_max)
		_steps(roundi(_model.shot_wait / DT) - 2, true, 0.0)
		assert_bool(_model.ready_to_fire()).is_false()
		_steps(3, true, 0.0)


func test_lost_after_the_grace_and_begin_resets() -> void:
	_steps(40, true, 0.0)
	_steps(25, false, 0.0)
	assert_bool(_model.lost()).is_false()
	_steps(10, false, 0.0)
	assert_bool(_model.lost()).is_true()
	_model.begin()
	assert_bool(_model.lost()).is_false()
	assert_bool(_model.reacted()).is_false()


func test_spread_grows_with_range_beyond_the_near_distance() -> void:
	assert_float(CombatModel.spread_deg(CONFIG, 2.0, 0.0, 0.0)).is_equal_approx(2.0, 0.0001)
	assert_float(CombatModel.spread_deg(CONFIG, 10.0, 0.0, 0.0)).is_equal_approx(2.9, 0.0001)
	assert_float(CombatModel.spread_deg(CONFIG, 15.0, 0.0, 0.0)).is_equal_approx(3.65, 0.0001)
	# Wider than a player's settled cone (0.5 untrained, 0.2 at Master) even point blank.
	assert_float(CombatModel.spread_deg(CONFIG, 1.0, 0.0, 10.0)).is_greater(0.5)


func test_fast_targets_widen_and_still_targets_settle() -> void:
	assert_float(CombatModel.spread_deg(CONFIG, 10.0, 5.0, 0.0)).is_equal_approx(4.9, 0.0001)
	# Not fast below 3 m/s (a crouch-walk at 2 m/s).
	assert_float(CombatModel.spread_deg(CONFIG, 10.0, 2.0, 0.0)).is_equal_approx(2.9, 0.0001)
	# Halfway through the 2 s settle: x0.875; settled: x0.75.
	assert_float(CombatModel.spread_deg(CONFIG, 10.0, 0.0, 1.0)).is_equal_approx(2.9 * 0.875, 0.0001)
	assert_float(CombatModel.spread_deg(CONFIG, 10.0, 0.0, 5.0)).is_equal_approx(2.9 * 0.75, 0.0001)


func test_settle_runs_only_while_the_target_is_still_and_seen() -> void:
	_steps(60, true, 0.0)
	assert_float(_model.settle).is_equal_approx(1.0, 0.02)
	var settled := _model.spread(10.0)
	assert_float(settled).is_less(CombatModel.spread_deg(CONFIG, 10.0, 0.0, 0.0))
	# Running at 5 m/s: the smoothed speed passes 0.5 m/s within a few ticks and the settle is gone.
	_steps(10, true, 5.0)
	assert_float(_model.settle).is_equal(0.0)
	assert_float(_model.target_speed).is_greater(CONFIG.fast_target_speed)
	assert_float(_model.spread(10.0)).is_greater(4.0)
	_steps(30, true, 0.0)
	_steps(5, false, 0.0)
	assert_float(_model.settle).is_equal(0.0)


func test_range_moves_keep_to_the_band_with_a_margin() -> void:
	var hold := CombatModel.Move.HOLD
	var advance := CombatModel.Move.ADVANCE
	var retreat := CombatModel.Move.RETREAT
	assert_int(CombatModel.range_move(CONFIG, 9.0, hold)).is_equal(hold)
	assert_int(CombatModel.range_move(CONFIG, 14.0, hold)).is_equal(advance)
	assert_int(CombatModel.range_move(CONFIG, 11.5, advance)).is_equal(advance)
	assert_int(CombatModel.range_move(CONFIG, 10.5, advance)).is_equal(hold)
	assert_int(CombatModel.range_move(CONFIG, 11.5, hold)).is_equal(hold)
	assert_int(CombatModel.range_move(CONFIG, 4.0, hold)).is_equal(retreat)
	assert_int(CombatModel.range_move(CONFIG, 6.5, retreat)).is_equal(retreat)
	assert_int(CombatModel.range_move(CONFIG, 7.5, retreat)).is_equal(hold)
	assert_int(CombatModel.range_move(CONFIG, 6.5, hold)).is_equal(hold)


func _steps(count: int, seen: bool, speed: float) -> void:
	for i in count:
		_model.step(DT, seen, speed)
