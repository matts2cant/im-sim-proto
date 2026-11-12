extends GdUnitTestSuite
## Unit: ShotStats (the range's stats board logic, ADR 0125): hit share and group size (extreme
## spread of the hits) over the last `window` projectiles per target.


func test_hit_share_counts_hits_over_shots() -> void:
	var stats := ShotStats.new(10)
	for i in 3:
		stats.record(&"a", true, Vector3(0, 1, 0))
	stats.record(&"a", false)

	assert_int(stats.shots(&"a")).is_equal(4)
	assert_int(stats.hits(&"a")).is_equal(3)
	assert_float(stats.hit_share(&"a")).is_equal_approx(0.75, 0.0001)
	# Targets are kept apart; an unknown one has nothing.
	assert_int(stats.shots(&"b")).is_equal(0)
	assert_float(stats.hit_share(&"b")).is_equal(0.0)


func test_group_size_is_the_widest_pair_of_hits() -> void:
	var stats := ShotStats.new(10)
	stats.record(&"a", true, Vector3(-0.1, 1.1, 0))
	stats.record(&"a", true, Vector3(0.1, 1.3, 0))
	stats.record(&"a", true, Vector3(0.0, 1.2, 0))
	stats.record(&"a", false)

	# (-0.1, 1.1) to (0.1, 1.3): 0.283 m; misses do not count.
	assert_float(stats.group_size(&"a")).is_equal_approx(sqrt(0.08), 0.0001)


func test_one_hit_has_no_group() -> void:
	var stats := ShotStats.new(10)
	stats.record(&"a", true, Vector3.ONE)

	assert_float(stats.group_size(&"a")).is_equal(0.0)


func test_only_the_last_window_shots_count() -> void:
	var stats := ShotStats.new(4)
	# A far hit, then four misses push it out of the window.
	stats.record(&"a", true, Vector3(5, 0, 0))
	for i in 4:
		stats.record(&"a", false)

	assert_int(stats.shots(&"a")).is_equal(4)
	assert_int(stats.hits(&"a")).is_equal(0)


func test_clear_forgets_everything() -> void:
	var stats := ShotStats.new(10)
	stats.record(&"a", true, Vector3.ZERO)
	stats.clear()

	assert_int(stats.shots(&"a")).is_equal(0)
