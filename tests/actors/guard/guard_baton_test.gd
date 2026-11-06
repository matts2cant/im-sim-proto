extends GdUnitTestSuite
## Integration: a baton guard (actors/guard/guard_baton.tscn) in the combat yard runs in on a
## stand-in target with hitboxes (tag `actor.player`) and swings at the baton's reach and rate
## (items/weapons/baton/baton.tres: reach 1.8 m from the eye, 0.6 s per swing). Its hits are the
## baton's own stimuli: 20 stun per hit on an aware target, never the sneak x10 (ADR 0049, 0070).

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const TARGET := Vector3(0, 0, -6)

var _c: Combat


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_c = Combat.new()
	await _c.setup(scene_runner(Combat.YARD), Combat.BATON_GUARD)


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()


func test_closes_in_and_hits_at_the_batons_rate() -> void:
	var target := _c.intruder(TARGET)
	var hit := await _wait_for_hit(5.0)
	assert_object(hit).is_not_null()
	# Within reach: the guard stopped about 1.2 m short (centre to centre), not on top of it.
	var distance := VisionRules.flat_distance(_c.guard.global_position, target.global_position)
	assert_float(distance).is_between(0.8, BATON.max_range)
	await _c.seconds(1.5)
	var swings := Combat.guard_entries(&"weapon.swung")
	assert_int(swings.size()).is_greater_equal(3)
	for i in range(1, swings.size()):
		# The baton's 0.6 s cycle (36 ticks).
		assert_int(swings[i].tick - swings[i - 1].tick).is_between(36, 38)
	assert_float(BodyParts.of(target).stun).is_greater(0.0)


func test_hits_from_behind_count_as_an_aware_attack() -> void:
	# The target faces away from the guard (yaw 0: -Z): the hits land from behind. It has no Awareness
	# component, so it counts as aware: 20 stun a hit, not the sneak x10 (one-hit knockout).
	var target := _c.intruder(TARGET, 0.0)
	assert_object(await _wait_for_hit(5.0)).is_not_null()
	await _c.frames(3)

	var stunned := EventLog.find(&"actor.stunned").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Intruder"
	)
	assert_array(stunned).is_not_empty()
	assert_bool(stunned[0].data["behind"]).is_true()
	assert_bool(stunned[0].data["aware"]).is_true()
	assert_float(stunned[0].data["amount"]).is_equal_approx(20.0, 0.001)
	assert_bool(ActorState.has(target, ActorState.UNCONSCIOUS)).is_false()


func test_a_knocked_out_target_is_left_alone() -> void:
	var target := _c.intruder(TARGET)
	assert_object(await _wait_for_hit(5.0)).is_not_null()
	ActorState.set_tag(target, ActorState.UNCONSCIOUS, true)
	await _c.frames(2)
	var down_tick := Engine.get_physics_frames()
	await _c.seconds(1.5)

	var later := Combat.guard_entries(&"weapon.swung").filter(
		func(entry: EventLogEntry) -> bool: return entry.tick > down_tick
	)
	assert_array(later).is_empty()
	var reasons := Combat.guard_entries(&"actor.disengaged").map(
		func(entry: EventLogEntry) -> String: return String(entry.data["reason"])
	)
	assert_array(reasons).contains(["target_down"])


# The first swing of the guard that hit something, or null after `limit` seconds.
func _wait_for_hit(limit: float) -> EventLogEntry:
	for tick in roundi(limit * 60.0):
		for entry in Combat.guard_entries(&"weapon.swung"):
			if not String(entry.data["hit"]).is_empty():
				return entry
		await _c.frames(1)
	return null
