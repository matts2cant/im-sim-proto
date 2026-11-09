extends GdUnitTestSuite
## Unit: sustained-fire bloom (ADR 0085) on the assault rifle's AimConfig: each shot widens the cone by
## shot_bloom_deg up to shot_bloom_cap_deg, a stance floor wider than the cap is never narrowed by a
## shot, and the cone recovers to its floor when firing stops (settle time constant).

const RIFLE_AIM: AimConfig = preload("res://items/weapons/assault_rifle/assault_rifle_aim.tres")


func test_each_shot_blooms_by_its_step() -> void:
	var aim := AimModel.new(RIFLE_AIM, 1)
	aim.add_shot()
	aim.add_shot()
	assert_float(aim.spread).is_equal_approx(RIFLE_AIM.base_min_deg + 2.0 * RIFLE_AIM.shot_bloom_deg, 0.0001)


func test_bloom_stops_at_the_cap() -> void:
	var aim := AimModel.new(RIFLE_AIM, 1)
	for i in 100:
		aim.add_shot()
	assert_float(aim.spread).is_equal_approx(RIFLE_AIM.shot_bloom_cap_deg, 0.0001)


func test_a_wider_stance_floor_is_not_narrowed_by_the_cap() -> void:
	var aim := AimModel.new(RIFLE_AIM, 1)
	var sprint := aim.floor_for(AimModel.Stance.SPRINT)
	assert_float(sprint).is_greater(RIFLE_AIM.shot_bloom_cap_deg)
	aim.step(1.0 / 60.0, sprint)
	aim.add_shot()
	assert_float(aim.spread).is_equal_approx(sprint, 0.0001)


func test_sustained_fire_at_ten_shots_a_second_stays_under_the_cap_and_recovers() -> void:
	var aim := AimModel.new(RIFLE_AIM, 1)
	var floor_deg := aim.floor_for(AimModel.Stance.STILL)
	for shot in 30:
		aim.add_shot()
		for tick in 6:
			aim.step(1.0 / 60.0, floor_deg)
	var sustained := aim.spread
	assert_float(sustained).is_between(floor_deg + 0.5, RIFLE_AIM.shot_bloom_cap_deg)
	# Released: back within 0.1 degrees of the floor after about 3 settle times.
	for tick in ceili(RIFLE_AIM.settle_time * 3.0 * 60.0):
		aim.step(1.0 / 60.0, floor_deg)
	assert_float(aim.spread - floor_deg).is_less(0.1)


func test_without_a_cap_shots_bloom_to_max() -> void:
	var config := AimConfig.new()
	config.shot_bloom_cap_deg = 0.0
	var aim := AimModel.new(config, 1)
	for i in 100:
		aim.add_shot()
	assert_float(aim.spread).is_equal(config.max_spread_deg)
