extends GdUnitTestSuite
## Integration: the guard scene (actors/guard/guard.tscn) in the guard fixture: composition, hearing
## (path distance from the floor, allies ignored), harm, external alerts, the knockout from behind
## and lying down, saving. Stand-in entities with tags make the noises and hits: the rules are about
## tags, not the player.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const GUARD_SCENE := "res://actors/guard/guard.tscn"

var _g: Guards


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST))


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()


func test_is_composed_from_the_generic_components() -> void:
	var guard := _g.guard
	assert_int(guard.collision_layer).is_equal(PhysicsLayers.ACTORS)
	var mask := PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ACTORS | PhysicsLayers.OBJECTS
	assert_int(guard.collision_mask).is_equal(mask)
	assert_bool(ActorState.has(guard, &"actor.guard")).is_true()
	assert_object(StepClimber.of(guard)).is_not_null()
	assert_object(BodyPusher.of(guard)).is_not_null()
	assert_object(BodyParts.of(guard)).is_not_null()
	assert_object(PerceptionSensor.of(guard)).is_not_null()
	assert_object(_g.awareness).is_not_null()
	assert_bool(_g.awareness.is_aware()).is_false()
	# Props pass through guards (ADR 0054): the impact sensor reports their hits.
	assert_bool((guard.get_node("ImpactSensor") as ImpactSensor).active).is_true()
	var crate := _g.scene.get_node("Crate") as RigidBody3D
	assert_int(crate.collision_mask & PhysicsLayers.ACTORS).is_equal(0)
	assert_float(PerceptionSensor.of(guard).eye_position().y - guard.global_position.y).is_equal_approx(1.6, 0.001)


func test_hears_walking_at_3_5m_path_distance_but_not_at_6_5m() -> void:
	# Walking on concrete: loudness 6. Distances are path lengths from the guard's feet (the Ears
	# receiver at floor level), not from its head.
	var near := _g.tagged("Walker", Vector3(3.5, 0, 0), [&"actor.player"])
	StimulusSystem.emit(Stimulus.make_noise(6.0, near.global_position, near))
	await _g.frames(3)

	var heard := Guards.guard_entries(&"actor.heard")
	assert_array(heard).has_size(1)
	assert_float(heard[0].data["perceived"]).is_between(2.0, 2.5)
	assert_array(Guards.states()).is_equal(["suspicious"])
	var received := EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Guard"
	)
	assert_str(received[0].data["propagation"]).is_equal("path")

	EventLog.clear()
	var far := _g.tagged("FarWalker", Vector3(-6.5, 0, 0), [&"actor.player"])
	StimulusSystem.emit(Stimulus.make_noise(6.0, far.global_position, far))
	await _g.frames(3)
	assert_array(Guards.guard_entries(&"actor.heard")).is_empty()


func test_ignores_noise_from_allies() -> void:
	var other := _g.tagged("OtherGuard", Vector3(3, 0, 0), [&"actor.guard"])
	StimulusSystem.emit(Stimulus.make_noise(12.0, other.global_position, other))
	await _g.frames(3)

	assert_array(Guards.guard_entries(&"actor.heard")).is_empty()
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)


func test_hears_props_and_runs_to_loud_ones() -> void:
	# A breaking crate (15) 4 m away: 11 >= 10 skips the look.
	var crate := _g.tagged("Crate", Vector3(-4, 0, 0), [&"material.wood"])
	StimulusSystem.emit(Stimulus.make_noise(15.0, crate.global_position, crate))
	await _g.frames(3)

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.SUSPICIOUS)
	assert_int(_g.awareness.model.phase).is_equal(AwarenessModel.Phase.MOVE)
	assert_int(_g.awareness.model.pace).is_equal(AwarenessModel.Pace.RUN)


func test_hit_by_a_hostile_from_the_front_alerts() -> void:
	var attacker := _g.tagged("Attacker", Vector3(0, 0, -1.5), [&"actor.player"])
	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 5.0, _g.guard, attacker))
	await _g.frames(3)

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.ALERTED)
	assert_str(_g.awareness.model.reason).is_equal("harm")
	assert_bool(_g.awareness.is_aware()).is_true()


func test_harm_from_a_non_hostile_does_not_alert() -> void:
	var prop := _g.tagged("Crate", Vector3(0, 0, -1.5), [&"material.wood"])
	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 5.0, _g.guard, prop))
	await _g.frames(3)

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)


func test_external_alert_alerts() -> void:
	_g.awareness.alert_at(Vector3(5, 0, 5))
	await _g.frames(2)

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.ALERTED)
	assert_array(Guards.states()).is_equal(["alerted"])
	assert_str(Guards.guard_entries(&"actor.awareness")[0].data["reason"]).is_equal("alert")


func test_baton_from_behind_knocks_an_unaware_guard_out_and_it_lies_down_deaf_and_blind() -> void:
	var attacker := _g.tagged("Attacker", Vector3(0, 0, 1.2), [&"actor.player"])
	StimulusSystem.emit(Stimulus.make_contact(&"damage.stun", 10.0, _g.guard, attacker))
	await _g.frames(3)

	var stunned := EventLog.find(&"actor.stunned")
	assert_array(stunned).has_size(1)
	assert_bool(stunned[0].data["behind"]).is_true()
	assert_bool(stunned[0].data["aware"]).is_false()
	assert_array(EventLog.find(&"actor.knocked_out")).has_size(1)
	assert_bool(ActorState.can_act(_g.guard)).is_false()
	# Knocked out: no alert, no state.
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	await _g.seconds(0.7)
	var pose := _g.guard.get_node("DownedPose") as DownedPose
	assert_bool(pose.is_down).is_true()
	var collision := _g.guard.get_node("Collision") as CollisionShape3D
	assert_float(collision.position.y).is_less(0.5)
	assert_float((_g.guard.get_node("Pose") as Node3D).rotation.x).is_equal_approx(PI * 0.5, 0.01)
	# Sees and hears nothing.
	attacker.global_position = Vector3(0, 0, -3)
	assert_object(PerceptionSensor.of(_g.guard).look()).is_null()
	StimulusSystem.emit(Stimulus.make_noise(15.0, Vector3(2, 0, 0), attacker))
	await _g.frames(3)
	assert_array(Guards.guard_entries(&"actor.heard")).is_empty()
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)


func test_aware_guard_is_not_knocked_out_by_one_hit_from_behind() -> void:
	_g.awareness.alert_at(Vector3(0, 0, 5))
	await _g.frames(2)
	_g.guard.rotation.y = 0.0
	var attacker := _g.tagged("Attacker", _g.guard.global_position + _g.guard.global_basis.z * 1.2, [&"actor.player"])
	StimulusSystem.emit(Stimulus.make_contact(&"damage.stun", 10.0, _g.guard, attacker))
	await _g.frames(3)

	assert_bool(EventLog.find(&"actor.stunned")[0].data["aware"]).is_true()
	assert_array(EventLog.find(&"actor.knocked_out")).is_empty()


func test_saves_and_restores_awareness_and_patrol_state() -> void:
	_g.awareness.alert_at(Vector3(3, 0, -2))
	await _g.seconds(0.5)
	_g.behaviour.patrol_index = 2
	var walker_state := _g.guard.save_state()
	var awareness_state := _g.awareness.save_state()
	var behaviour_state := _g.behaviour.save_state()

	var copy := auto_free(load(GUARD_SCENE).instantiate()) as NavWalker
	_g.scene.add_child(copy)
	await _g.frames(1)
	copy.load_state(walker_state)
	GradedAwareness.of_node(copy).load_state(awareness_state)
	(copy.get_node("Behaviour") as AwarenessBehaviour).load_state(behaviour_state)

	assert_vector(copy.global_position).is_equal_approx(walker_state["position"], Vector3.ONE * 0.001)
	assert_float(copy.rotation.y).is_equal_approx(walker_state["yaw"], 0.001)
	assert_int(GradedAwareness.of_node(copy).state()).is_equal(AwarenessModel.State.ALERTED)
	assert_float(GradedAwareness.of_node(copy).model.meter).is_equal(1.0)
	assert_int((copy.get_node("Behaviour") as AwarenessBehaviour).patrol_index).is_equal(2)
	assert_dict(GradedAwareness.of_node(copy).save_state()).is_equal(awareness_state)
