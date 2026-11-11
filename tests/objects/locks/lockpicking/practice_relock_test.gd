extends GdUnitTestSuite
## Unit (ADR 0107): a practice lock's re-lock cycle: due `delay` s after opening, a new seed and the
## layout counter + 1 each time; saved and loaded.


func test_it_relocks_after_the_delay_with_a_new_seed_and_counter() -> void:
	var relock := PracticeRelock.new(3.0, 4127)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	assert_bool(relock.advance(10.0, rng)).is_false()
	relock.opened()
	assert_bool(relock.pending()).is_true()
	assert_bool(relock.advance(2.9, rng)).is_false()
	assert_bool(relock.advance(0.2, rng)).is_true()
	assert_int(relock.layout).is_equal(2)
	assert_int(relock.pin_seed).is_not_equal(4127)
	assert_bool(relock.pending()).is_false()
	var second := relock.pin_seed
	relock.opened()
	assert_bool(relock.advance(3.1, rng)).is_true()
	assert_int(relock.layout).is_equal(3)
	assert_int(relock.pin_seed).is_not_equal(second)


func test_its_state_saves_and_loads() -> void:
	var relock := PracticeRelock.new(3.0, 11)
	relock.layout = 4
	relock.opened()
	var copy := PracticeRelock.new(3.0, 99)
	copy.load_state(relock.save_state())
	assert_int(copy.layout).is_equal(4)
	assert_int(copy.pin_seed).is_equal(11)
	assert_bool(copy.pending()).is_true()
