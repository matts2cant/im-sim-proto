extends GdUnitTestSuite
## Integration (ADR 0127): a pistol guard (actors/guard/guard_pistol.tscn, its HitReaction tuned by
## guard_hit_reaction.tres) in the combat yard. A hit right after a shot (a 5-damage
## `damage.ballistic` RAY at its torso from 3 m in front, centre to centre) flinches it: its next
## shot comes the flinch time later than the pause it had drawn. A leg hit staggers it: slower for
## the stagger time, its model tipped back by the CharacterAnimator.

const Combat := preload("res://tests/actors/guard/combat_helpers.gd")
const REACTION: HitReactionConfig = preload("res://actors/guard/guard_hit_reaction.tres")
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


func test_a_hit_delays_the_next_shot_by_the_flinch() -> void:
	_c.intruder(FRONT)
	var first := await _c.wait_for(&"weapon.fired", 5.0)
	assert_object(first).is_not_null()
	var pause := _c.combat.model.shot_wait
	_hit(BodyDamageModel.TORSO)
	var second: EventLogEntry = null
	for tick in 120:
		await _c.frames(1)
		var shots := Combat.guard_entries(&"weapon.fired")
		if shots.size() > 1:
			second = shots[1]
			break
	assert_object(second).is_not_null()
	assert_array(EventLog.find(&"actor.hit_reacted")).has_size(1)
	# The pause it drew plus the flinch (the hit lands two ticks after it is emitted); one tick of slack.
	var expected := (pause + REACTION.flinch_time) * 60.0
	assert_int(second.tick - first.tick).is_between(roundi(expected), roundi(expected) + 4)


func test_a_leg_hit_staggers_the_guard() -> void:
	var model := _c.guard.get_node("Model") as Node3D
	await _c.frames(2)
	var rest := model.basis
	_hit(BodyDamageModel.LEG_L)
	await _c.frames(8)
	var reaction := HitReaction.of(_c.guard)
	assert_bool(reaction.is_staggered()).is_true()
	assert_float(Attributes.read(_c.guard, &"move_speed_mult", 1.0)).is_less(0.5)
	# Shot from the front (the guard faces -Z): the model's top tips back towards +Z.
	var tipped := (model.basis * rest.inverse()) * Vector3.UP
	assert_float(tipped.z).is_greater(sin(deg_to_rad(REACTION.stagger_lean_deg)) * 0.5)
	await _c.seconds(REACTION.stagger_time)
	assert_bool(reaction.is_staggered()).is_false()
	assert_float(Attributes.read(_c.guard, &"move_speed_mult", 1.0)).is_equal_approx(1.0, 0.0001)
	assert_bool(model.basis.is_equal_approx(rest)).is_true()


# A 5-damage ballistic ray at the guard's hitbox `part` from 3 m in front of it.
func _hit(part: StringName) -> void:
	var target := Hitboxes.of(_c.guard).box(part).global_position
	var origin := target + Vector3(0, 0, -3)
	var ray := Stimulus.make_ray(&"damage.ballistic", 5.0, origin, (target - origin).normalized(), 5.0)
	ray.collision_mask = PhysicsLayers.WEAPON_MASK
	StimulusSystem.emit(ray)
