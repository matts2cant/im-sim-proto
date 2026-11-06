extends GdUnitTestSuite
## Integration: a pistol guard (actors/guard/guard_pistol.tscn) in the combat yard against a
## stand-in target with hitboxes (tag `actor.player`, no light component: fully lit). The guard
## stands at the origin facing -Z; the target 8 m in front (inside the 6-12 m band) unless a test
## says otherwise. Reaction delay, rate of fire, line of fire (allies), awareness gating, reload,
## preferred range and being downed (ADR 0070).

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const CONFIG: CombatConfig = preload("res://actors/guard/guard_combat.tres")
const FRONT := Vector3(0, 0, -8)

var _c: Combat


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_c = Combat.new()
	await _c.setup(scene_runner(Combat.YARD), Combat.PISTOL_GUARD)


func after_test() -> void:
	_c.teardown()
	StimulusSystem.clear()


func test_unarmed_guard_scene_has_no_loadout_and_the_variants_only_set_one() -> void:
	var unarmed := auto_free((load("res://actors/guard/guard.tscn") as PackedScene).instantiate()) as Node
	var holder := unarmed.get_node("Aim/WeaponHolder") as WeaponHolder
	assert_array(holder.weapons).is_empty()
	assert_object(CombatBehaviour.of(unarmed)).is_not_null()
	assert_str(String(_c.holder.weapons[0].id)).is_equal("pistol_unsilenced")
	# The guards' pistol is the loud variant: same damage, louder than the silenced one (6 m).
	assert_float(_c.holder.weapons[0].fire_noise).is_greater(20.0)
	assert_float(_c.holder.weapons[0].damage[&"damage.ballistic"]).is_equal(25.0)


func test_shoots_after_the_reaction_delay_then_at_the_interval() -> void:
	var target := _c.intruder(FRONT)
	var first := await _c.wait_for(&"weapon.fired", 5.0)
	assert_object(first).is_not_null()
	var engaged := Combat.guard_entries(&"actor.engaged")[0]
	var alerted := Combat.guard_entries(&"actor.awareness").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["to"] == "alerted"
	)
	assert_int(engaged.tick - alerted[0].tick).is_between(0, 1)
	# 0.5 s reaction (30 ticks) from the engagement, then the guard is already stopped and facing.
	assert_int(first.tick - engaged.tick).is_between(30, 34)
	await _c.seconds(2.5)
	var shots := Combat.guard_entries(&"weapon.fired")
	assert_int(shots.size()).is_greater_equal(3)
	for i in range(1, shots.size()):
		# 0.6-0.9 s between shots (36-54 ticks, one tick of slack).
		assert_int(shots[i].tick - shots[i - 1].tick).is_between(36, 55)
	# Its shots are the same damage stimuli as the player's: the target was hurt.
	assert_float(Combat.total_health(target)).is_less(_full_health())


func test_does_not_shoot_while_unaware_or_alerted_without_sight() -> void:
	var target := _c.intruder(FRONT)
	ActorState.set_tag(target, ActorState.CLOAKED, true)
	await _c.seconds(1.5)
	assert_int(_c.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	# Alerted from outside (an alarm), the cloaked target still unseen: no engagement.
	_c.awareness.alert_at(target.global_position)
	await _c.seconds(1.5)

	assert_array(Combat.guard_entries(&"weapon.fired")).is_empty()
	assert_array(Combat.guard_entries(&"actor.engaged")).is_empty()
	assert_float(Combat.total_health(target)).is_equal(_full_health())


func test_never_fires_through_an_ally_and_steps_aside() -> void:
	var target := _c.intruder(FRONT)
	var ally := _c.ally(Vector3(0, 0, -4))
	await _c.frames(2)
	var eye := _c.holder.eye.global_position
	var space := _c.guard.get_world_3d().direct_space_state
	var own: Array[RID] = [_c.guard.get_rid()]
	own.append_array(Hitboxes.rids_of(_c.guard))
	for point in CombatBehaviour.aim_points(target):
		assert_bool(CombatBehaviour.line_of_fire_clear(space, eye, point, target, own)).is_false()

	var engaged := await _c.wait_for(&"actor.engaged", 4.0)
	assert_object(engaged).is_not_null()
	var first := await _c.wait_for(&"weapon.fired", 4.0)
	assert_object(first).is_not_null()
	# Blocked from the start: it steps aside after 1 s, then fires from off the line.
	assert_int(first.tick - engaged.tick).is_greater(60)
	assert_float(absf(_c.guard.global_position.x)).is_greater(1.0)
	await _c.seconds(1.5)
	assert_float(Combat.total_health(ally)).is_equal(_full_health())
	for shot in Combat.guard_entries(&"weapon.fired"):
		assert_str(String(shot.data["hit"])).is_not_equal("Ally")


func test_reloads_an_empty_magazine_from_the_reserve() -> void:
	var state := _c.holder.states[0]
	state.magazine = 2
	_c.intruder(FRONT)
	var started := await _c.wait_for(&"weapon.reload_started", 6.0)
	assert_object(started).is_not_null()
	assert_array(Combat.guard_entries(&"weapon.fired")).has_size(2)
	assert_array(Combat.guard_entries(&"weapon.dry_fire")).is_empty()
	var reloaded := await _c.wait_for(&"weapon.reloaded", 3.0)
	assert_object(reloaded).is_not_null()
	# 1.6 s (96 ticks) from the weapon's data.
	assert_int(reloaded.tick - started.tick).is_between(95, 97)
	assert_int(int(reloaded.data["magazine"])).is_equal(10)
	assert_int(state.reserve).is_equal(20)
	await _c.seconds(1.0)
	var after := Combat.guard_entries(&"weapon.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.tick > reloaded.tick
	)
	assert_array(after).is_not_empty()


func test_stops_attacking_when_knocked_out() -> void:
	_c.intruder(FRONT)
	assert_object(await _c.wait_for(&"weapon.fired", 5.0)).is_not_null()
	ActorState.set_tag(_c.guard, ActorState.UNCONSCIOUS, true)
	await _c.frames(2)
	var down_tick := Engine.get_physics_frames()
	await _c.seconds(2.0)

	var later := EventLog.find(&"weapon.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.tick > down_tick
	)
	assert_array(later).is_empty()
	assert_bool(_c.combat.is_engaged()).is_false()
	assert_object(_c.guard.controller()).is_null()
	assert_bool(_c.holder.is_armed()).is_false()
	var reasons := Combat.guard_entries(&"actor.disengaged").map(
		func(entry: EventLogEntry) -> String: return String(entry.data["reason"])
	)
	assert_array(reasons).contains(["incapacitated"])


func test_backs_away_from_a_close_target_before_shooting() -> void:
	# 3 m away, under the 6 m minimum: it backs off (facing the target) to 7 m, then fires.
	_c.intruder(Vector3(0, 0, -3))
	var first := await _c.wait_for(&"weapon.fired", 6.0)
	assert_object(first).is_not_null()
	var distance := VisionRules.flat_distance(_c.guard.global_position, Vector3(0, 0, -3))
	assert_float(distance).is_greater(CONFIG.min_distance)
	# It kept facing the target while it walked backwards.
	var angle := VisionRules.angle_off(_c.guard.facing(), _c.guard.global_position, Vector3(0, 0, -3))
	assert_float(angle).is_less(CONFIG.fire_max_angle)


func test_advances_on_a_far_target_and_shoots_within_range() -> void:
	# The guard holds a post at z 5; the target 16 m away in front of the cover wall (seen in the
	# focus cone, 20 m): it walks to 11 m before shooting.
	_c.guard.global_position = Vector3(0, 0, 5)
	(_c.guard.get_node("Behaviour") as AwarenessBehaviour).post = Vector3(0, 0, 5)
	var feet := Vector3(0, 0, -11)
	_c.intruder(feet)
	var first := await _c.wait_for(&"weapon.fired", 8.0)
	assert_object(first).is_not_null()
	var distance := VisionRules.flat_distance(_c.guard.global_position, feet)
	assert_float(distance).is_less(CONFIG.max_distance)


func test_hands_the_walker_back_when_the_target_is_lost() -> void:
	var target := _c.intruder(FRONT)
	assert_object(await _c.wait_for(&"weapon.fired", 5.0)).is_not_null()
	assert_object(_c.guard.controller()).is_same(_c.combat)
	# Behind the cover wall (z -12), out of sight from the guard.
	target.global_position = Vector3(0, 0, -14)
	var hidden_tick := Engine.get_physics_frames()
	await _c.seconds(1.0)

	var reasons := Combat.guard_entries(&"actor.disengaged").map(
		func(entry: EventLogEntry) -> String: return String(entry.data["reason"])
	)
	assert_array(reasons).contains(["lost"])
	assert_object(_c.guard.controller()).is_null()
	var later := Combat.guard_entries(&"weapon.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.tick > hidden_tick + 1
	)
	assert_array(later).is_empty()
	# Still Alerted: the awareness behaviour runs to the last known position.
	assert_int(_c.awareness.state()).is_equal(AwarenessModel.State.ALERTED)
	assert_bool(_c.guard.is_moving()).is_true()


func _full_health() -> float:
	var profile: BodyProfile = Combat.Characters.BODY_PROFILE
	return profile.head_health + profile.torso_health + 2.0 * profile.arm_health + 2.0 * profile.leg_health
