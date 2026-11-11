extends GdUnitTestSuite
## Unit (ADR 0113): the Icebreaker's pure logic with the shipped tuning (deck_config.tres: base
## Weak 10 s, Medium 24 s, Strong 50 s) and the Computer skill table (skill_table.tres). Measured
## crack times per tier (hacking.md's table), what each tier cracks, letters locking in one by one,
## determinism, and the trace a crack adds.

const CONFIG: DeckConfig = preload("res://items/deck/deck_config.tres")
const TABLE: SkillTable = preload("res://actors/common/abilities/skill_table.tres")
const STEP := 1.0 / 60.0
## hacking.md: crack times per tier (Untrained .. Master) and strength (Weak, Medium, Strong);
## 0: cannot crack.
const TIMES := [[10.0, 0.0, 0.0], [7.5, 18.0, 0.0], [5.0, 12.0, 25.0], [3.0, 7.2, 15.0]]


# The Computer skill's attribute values at `tier`, from the shipped skill table.
func _skill(tier: int) -> Dictionary:
	var values := {}
	for skill in TABLE.skills:
		if skill.id != &"computer":
			continue
		for effect in skill.effects:
			values[effect.attribute] = effect.magnitude_at(tier)
	return values


# Frames until a fresh job of `strength` finishes at crack multiplier `mult`.
func _frames_to_crack(strength: int, mult: float) -> int:
	var job := Icebreaker.make("k", "u", "h", "abcdefgh", strength, CONFIG.base_time(strength))
	var frames := 0
	while not job.advance(STEP, mult):
		frames += 1
		if frames > 60 * 120:
			break
	return frames + 1


func test_the_skill_table_carries_the_computer_attributes() -> void:
	var trained := _skill(1)
	assert_float(float(trained[Icebreaker.CRACK_TIME_ATTRIBUTE])).is_equal(0.75)
	assert_float(float(trained[Tracer.TRACE_GAIN_ATTRIBUTE])).is_equal(0.8)
	assert_float(float(trained[Icebreaker.MAX_STRENGTH_ATTRIBUTE])).is_equal(1.0)
	assert_float(float(trained[Icebreaker.ASSIST_ATTRIBUTE])).is_equal(1.0)
	var master := _skill(3)
	assert_float(float(master[Icebreaker.CRACK_TIME_ATTRIBUTE])).is_equal(0.3)
	assert_float(float(master[Tracer.TRACE_GAIN_ATTRIBUTE])).is_equal(0.4)
	assert_float(float(master[Icebreaker.MAX_STRENGTH_ATTRIBUTE])).is_equal(2.0)


func test_measured_crack_times_per_tier_match_the_design_table() -> void:
	for tier in 4:
		var skill := _skill(tier)
		var mult := float(skill.get(Icebreaker.CRACK_TIME_ATTRIBUTE, 1.0))
		var strongest := roundi(float(skill.get(Icebreaker.MAX_STRENGTH_ATTRIBUTE, 0.0)))
		for strength in 3:
			var expected: float = TIMES[tier][strength]
			(
				assert_bool(Icebreaker.can_crack(strength, strongest))
				. override_failure_message("tier %d strength %d" % [tier, strength])
				. is_equal(expected > 0.0)
			)
			if expected > 0.0:
				var seconds := _frames_to_crack(strength, mult) * STEP
				(
					assert_float(seconds)
					. override_failure_message("tier %d strength %d: %f" % [tier, strength, seconds])
					. is_equal_approx(expected, 0.02)
				)
	# No crack takes longer than about 25 s.
	assert_float(Icebreaker.crack_time(CONFIG.base_time(DeviceAccount.Strength.STRONG), 0.5)).is_equal(25.0)


func test_letters_lock_in_one_by_one() -> void:
	var job := Icebreaker.make("k", "u", "h", "ferry19", DeviceAccount.Strength.WEAK, 10.0)
	assert_int(job.locked_letters()).is_equal(0)
	var counts: Array[int] = []
	for i in 600:
		job.advance(STEP, 1.0)
		if counts.is_empty() or counts[-1] != job.locked_letters():
			counts.append(job.locked_letters())
	assert_array(counts).is_equal([0, 1, 2, 3, 4, 5, 6, 7])
	assert_bool(job.is_done()).is_true()
	assert_bool(job.advance(STEP, 1.0)).is_false()


func test_it_is_deterministic() -> void:
	var a := Icebreaker.make("k", "u", "h", "Gh7vQx2e", DeviceAccount.Strength.MEDIUM, 24.0)
	var b := Icebreaker.make("k", "u", "h", "Gh7vQx2e", DeviceAccount.Strength.MEDIUM, 24.0)
	var trace_a: Array[int] = []
	var trace_b: Array[int] = []
	for i in 900:
		a.advance(STEP, 0.75)
		b.advance(STEP, 0.75)
		trace_a.append(a.locked_letters())
		trace_b.append(b.locked_letters())
	assert_array(trace_a).is_equal(trace_b)
	assert_float(a.progress).is_equal(b.progress)
	assert_int(Icebreaker.password_hash("Gh7vQx2e")).is_equal(Icebreaker.password_hash("Gh7vQx2e"))
	assert_int(Icebreaker.password_hash("Gh7vQx2e")).is_not_equal(Icebreaker.password_hash("Gh7vQx2f"))


func test_time_left_and_trace_to_finish() -> void:
	# Trained, Medium: 18 s at 4 %/s x 0.8 = 57.6 % in all; half done: half of each.
	var job := Icebreaker.make("k", "u", "h", "harbor77", DeviceAccount.Strength.MEDIUM, 24.0)
	assert_float(job.trace_to_finish(4.0, 0.75, 0.8)).is_equal_approx(57.6, 0.001)
	job.progress = 0.5
	assert_float(job.time_left(0.75)).is_equal_approx(9.0, 0.001)
	assert_float(job.trace_to_finish(4.0, 0.75, 0.8)).is_equal_approx(28.8, 0.001)
	# The sensitive tracer (7 %/s): a Trained Medium crack fills it.
	job.progress = 0.0
	assert_float(job.trace_to_finish(7.0, 0.75, 0.8)).is_greater(100.0)
