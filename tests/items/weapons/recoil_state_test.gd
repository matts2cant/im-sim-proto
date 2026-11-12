extends GdUnitTestSuite
## Unit: RecoilState and RecoilConfig (ADR 0123): a pattern repeats shot for shot with the noise off,
## size and noise scale independently, an automatic weapon's climb holds during a spray and returns
## in 0.3-0.5 s after it, a semi-automatic kick returns in about 0.2 s, the pattern loops and resumes
## part-way after a short pause; WeaponData's damage falloff.

const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SMG: WeaponData = preload("res://items/weapons/smg/smg.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const STEP := 1.0 / 60.0


func test_pattern_repeats_shot_for_shot_without_noise() -> void:
	var config := _quiet(RIFLE.recoil)
	var first := RecoilState.new(11)
	var second := RecoilState.new(99)
	for shot in 12:
		first.add_shot(config)
		second.add_shot(config)
		assert_vector(first.offset).is_equal(second.offset)
	assert_vector(first.offset).is_equal_approx(RecoilState.pattern_climb(config, 12), Vector2.ONE * 0.0001)
	# The rifle climbs mostly up; the submachine gun drifts more sideways than up.
	var rifle := RecoilState.pattern_climb(config, 10)
	assert_float(rifle.y).is_greater(absf(rifle.x) * 3.0)
	var smg_side := 0.0
	var smg_up := 0.0
	for shot in 10:
		smg_side += absf(SMG.recoil.pattern_step(shot).x)
		smg_up += SMG.recoil.pattern_step(shot).y
	assert_float(smg_side).is_greater(smg_up)


func test_size_and_noise_scale_independently() -> void:
	var untrained := RecoilState.new(5)
	var master := RecoilState.new(5)
	var pattern := RIFLE.recoil.pattern_step(0) * RIFLE.recoil.pattern_scale
	# The skill table's Untrained and Master multipliers: size x1.5 / x1, noise x2 / x0.5.
	untrained.add_shot(RIFLE.recoil, 1.5, 2.0)
	master.add_shot(RIFLE.recoil, 1.0, 0.5)
	var untrained_noise := untrained.offset - pattern * 1.5
	var master_noise := master.offset - pattern
	assert_vector(untrained_noise).is_equal_approx(master_noise * 4.0, Vector2.ONE * 0.0001)
	assert_float(absf(master_noise.x)).is_less_equal(RIFLE.recoil.noise_deg * 0.5)


func test_automatic_climb_holds_during_a_spray_and_returns_after_it() -> void:
	for data: WeaponData in [RIFLE, SMG]:
		var recoil := RecoilState.new(3)
		var ticks_per_shot := roundi(data.cycle_time / STEP)
		for shot in 10:
			if shot > 0:
				# The return waits for the delay: nothing comes back between two shots of a spray.
				var held := recoil.offset
				for tick in ticks_per_shot:
					recoil.step(STEP, data.recoil)
				assert_vector(recoil.offset).is_equal(held)
			recoil.add_shot(data.recoil)
		var climbed := recoil.offset.length()
		assert_float(climbed).override_failure_message(String(data.id)).is_greater(1.0)
		# 90 % back after the last shot: the return delay plus 2.3 time constants, 0.3 to 0.5 s.
		var ticks := 0
		while recoil.offset.length() > climbed * 0.1 and ticks < 120:
			recoil.step(STEP, data.recoil)
			ticks += 1
		assert_float(ticks * STEP).override_failure_message(String(data.id)).is_between(0.3, 0.5)
		for tick in 60:
			recoil.step(STEP, data.recoil)
		assert_vector(recoil.offset).is_equal(Vector2.ZERO)


func test_semi_automatic_kick_returns_in_about_0_2_s() -> void:
	var recoil := RecoilState.new(3)
	recoil.add_shot(PISTOL.recoil, 1.5, 2.0)
	var kicked := recoil.offset.length()
	assert_float(recoil.offset.y).is_greater(PISTOL.recoil.kick_up_deg)
	var ticks := 0
	while recoil.offset.length() > kicked * 0.05 and ticks < 60:
		recoil.step(STEP, PISTOL.recoil)
		ticks += 1
	assert_float(ticks * STEP).is_between(0.12, 0.25)
	# Back long before the next shot (the pistol's 0.35 s cycle): tapping needs no correction.
	while ticks * STEP < PISTOL.cycle_time:
		recoil.step(STEP, PISTOL.recoil)
		ticks += 1
	assert_float(recoil.offset.length()).is_less(kicked * 0.02)


func test_pattern_loops_and_resumes_part_way_after_a_short_pause() -> void:
	var config := _quiet(RIFLE.recoil)
	var size := config.pattern.size()
	assert_vector(config.pattern_step(size)).is_equal(config.pattern[config.loop_from])
	assert_vector(config.pattern_step(size + 1)).is_equal(config.pattern[config.loop_from + 1])
	var recoil := RecoilState.new(3)
	for shot in 10:
		recoil.add_shot(config)
	# One time constant after the delay: about 37 % of the heat is left, the next burst starts at
	# step 3 of the pattern.
	for tick in roundi((config.recover_delay + config.recover_time) / STEP):
		recoil.step(STEP, config)
	assert_float(recoil.heat).is_between(3.0, 4.5)
	var before := recoil.offset
	recoil.add_shot(config)
	assert_vector(recoil.offset - before).is_equal_approx(config.pattern[floori(3.0)], Vector2.ONE * 0.0001)


func test_damage_falls_off_past_its_start() -> void:
	assert_float(SMG.damage_scale_at(5.0)).is_equal(1.0)
	# Full to 8 m, then down to 0.25 x at 22 m: at 15 m 1 - 7 / 14 x 0.75.
	assert_float(SMG.damage_scale_at(15.0)).is_equal_approx(0.625, 0.0001)
	assert_float(SMG.damage_scale_at(30.0)).is_equal_approx(SMG.falloff_min, 0.0001)
	assert_float(RIFLE.damage_scale_at(70.0)).is_equal(1.0)


# A copy of `config` without noise.
func _quiet(config: RecoilConfig) -> RecoilConfig:
	var copy := config.duplicate() as RecoilConfig
	copy.noise_deg = 0.0
	return copy
