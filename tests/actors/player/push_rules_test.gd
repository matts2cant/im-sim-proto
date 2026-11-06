extends GdUnitTestSuite
## Unit: PushRules (ADR 0053).

const DELTA := 1.0 / 60.0


func test_push_brings_light_body_up_to_target_speed() -> void:
	# 2 kg at rest, target 2 m/s: needs 4 N s; the 250 N budget allows 4.17 N s this tick.
	assert_float(PushRules.push_impulse(2.0, 0.0, 2.0, 250.0, DELTA)).is_equal_approx(4.0, 0.0001)


func test_push_is_capped_by_force_budget() -> void:
	# 10 kg at rest would need 20 N s; capped at 250 N x 1/60 s.
	assert_float(PushRules.push_impulse(10.0, 0.0, 2.0, 250.0, DELTA)).is_equal_approx(250.0 / 60.0, 0.0001)


func test_push_budget_is_shared_between_bodies() -> void:
	var one := PushRules.push_impulse(10.0, 0.0, 2.0, 250.0, DELTA, 1)
	var each_of_two := PushRules.push_impulse(10.0, 0.0, 2.0, 250.0, DELTA, 2)
	assert_float(each_of_two).is_equal_approx(one * 0.5, 0.0001)


func test_push_never_pulls_or_overspeeds() -> void:
	assert_float(PushRules.push_impulse(10.0, 2.5, 2.0, 250.0, DELTA)).is_equal(0.0)
	assert_float(PushRules.push_impulse(10.0, 2.0, 2.0, 250.0, DELTA)).is_equal(0.0)
	assert_float(PushRules.push_impulse(10.0, 0.0, -1.0, 250.0, DELTA)).is_equal(0.0)


func test_push_ignores_invalid_input() -> void:
	assert_float(PushRules.push_impulse(0.0, 0.0, 2.0, 250.0, DELTA)).is_equal(0.0)
	assert_float(PushRules.push_impulse(10.0, 0.0, 2.0, 250.0, DELTA, 0)).is_equal(0.0)


func test_weight_is_shared_between_bodies_stood_on() -> void:
	assert_float(PushRules.weight_share(80.0, 9.8, 1)).is_equal_approx(784.0, 0.001)
	assert_float(PushRules.weight_share(80.0, 9.8, 2)).is_equal_approx(392.0, 0.001)
	assert_float(PushRules.weight_share(80.0, 9.8, 0)).is_equal(0.0)


func test_weight_on_a_light_body_is_capped_by_its_own_weight() -> void:
	# 784 N on a 10 kg crate, ratio 4: at most 392 N; on a 0.5 kg bottle 19.6 N; a 200 kg body takes all.
	assert_float(PushRules.capped_weight(784.0, 10.0, 9.8, 4.0)).is_equal_approx(392.0, 0.001)
	assert_float(PushRules.capped_weight(784.0, 0.5, 9.8, 4.0)).is_equal_approx(19.6, 0.001)
	assert_float(PushRules.capped_weight(784.0, 200.0, 9.8, 4.0)).is_equal_approx(784.0, 0.001)
