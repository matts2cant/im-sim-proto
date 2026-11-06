extends GdUnitTestSuite
## Scenario (EventLog): a guard finds downed allies and wakes the unconscious ones (ADR 0071), in
## the guard post fixture (tests/scenarios/fixtures/guard_post.tscn: lit floor, the guard at the
## origin facing -Z, no route). Bodies lie across the guard's view (along +X), their middle 5 m
## ahead on the floor: lit, in focus, found in about 0.8 s.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const GUARD_SCENE: PackedScene = preload("res://actors/guard/guard.tscn")
const REVIVE: Receptron = preload("res://actors/common/body/receptrons/revive.tres")
const UNCONSCIOUS: Array[StringName] = [&"actor.guard", &"equipment.radio", &"state.unconscious"]
const DEAD: Array[StringName] = [&"actor.guard", &"equipment.radio", &"state.dead"]
## Feet of a body lying along +X with its middle at (0, 0, -5).
const BODY_FEET := Vector3(-0.9, 0, -5)

var _g: Guards


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	await Guards.let_old_scenes_go(get_tree())
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST))


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()


## A guard.tscn lying down with `tags`, turned so it lies along +X from `feet`.
func _downed_guard(body_name: String, feet: Vector3, tags: Array[StringName]) -> NavWalker:
	var body := GUARD_SCENE.instantiate() as NavWalker
	body.name = body_name
	(body.get_node("Tags") as Tags).initial_tags = tags
	body.position = feet
	body.rotation.y = PI * 0.5
	_g.scene.add_child(body)
	return body


func test_an_unconscious_ally_is_found_shouted_about_walked_to_and_woken() -> void:
	var body := _downed_guard("Downed", BODY_FEET, UNCONSCIOUS)
	await _g.seconds(1.5)

	var found := Guards.guard_entries(&"actor.body_found")
	assert_array(found).has_size(1)
	assert_str(String(found[0].data["body"])).is_equal("Downed")
	assert_str(String(found[0].data["state"])).is_equal("unconscious")
	var barks := Guards.guard_entries(&"actor.bark").map(
		func(entry: EventLogEntry) -> String: return entry.data["line"]
	)
	assert_bool(barks.any(func(line: String) -> bool: return line.begins_with("Man down"))).is_true()
	var shouts := Guards.guard_entries(&"actor.shout")
	assert_array(shouts).has_size(1)
	assert_str(String(shouts[0].data["reason"])).is_equal("body")
	assert_str(_g.awareness.state_name()).is_equal("searching")
	assert_str(_g.awareness.model.reason).is_equal("body")
	assert_float(_g.awareness.model.wary_time).is_greater(170.0)

	# Walks over (about 4 m at run pace), stands by it for 3 s and wakes it through a `revive`
	# stimulus: well within 10 s.
	var phases: Array[String] = []
	for tick in 600:
		await _g.frames(1)
		var phase := AwarenessModel.PHASE_NAMES[_g.awareness.model.phase]
		if phases.is_empty() or phases[-1] != phase:
			phases.append(phase)
		if not Guards.guard_entries(&"actor.wake").is_empty():
			break
	await _g.frames(4)
	var woke := Guards.guard_entries(&"actor.wake")
	var trace := (
		"phases %s, guard at %s, tend %.2f, dest %s moving %s speed %.1f proc %s path %d ctrl %s"
		% [
			phases,
			_g.guard.global_position,
			BodyDiscovery.of(_g.guard).tend_time,
			_g.awareness.model.destination,
			_g.guard.is_moving(),
			_g.guard.speed,
			_g.guard.is_physics_processing(),
			_g.guard.agent.get_current_navigation_path().size(),
			_g.guard.controller(),
		]
	)
	trace += (
		" root %s real %s"
		% [
			_g.guard.get_tree().root.get_children().map(func(n: Node) -> String: return String(n.name)),
			_g.guard.get_real_velocity(),
		]
	)
	assert_array(woke).override_failure_message(trace).has_size(1)
	assert_array(EventLog.find(&"actor.revived")).has_size(1)
	assert_bool(ActorState.can_act(body)).is_true()
	var parts := BodyParts.of(body)
	assert_float(parts.stun).is_equal(0.0)
	assert_bool(parts.is_unconscious()).is_false()
	var woken := GradedAwareness.of_node(body)
	assert_str(woken.state_name()).is_equal("searching")
	assert_str(woken.model.reason).is_equal("woken")
	assert_str(_g.awareness.state_name()).is_equal("searching")
	assert_bool(BodyDiscovery.of(_g.guard).has_found(body)).is_false()


func test_a_dead_ally_is_found_and_searched_around_but_never_woken() -> void:
	var body := _downed_guard("Dead", BODY_FEET, DEAD)
	await _g.seconds(1.5)
	var found := Guards.guard_entries(&"actor.body_found")
	assert_array(found).has_size(1)
	assert_str(String(found[0].data["state"])).is_equal("dead")
	assert_str(_g.awareness.state_name()).is_equal("searching")
	await _g.seconds(12.0)
	assert_array(Guards.guard_entries(&"actor.wake")).is_empty()
	assert_bool(ActorState.is_dead(body)).is_true()
	# Found once, however long it stays in view.
	assert_array(Guards.guard_entries(&"actor.body_found")).has_size(1)


func test_a_body_in_the_dark_is_found_only_close_up() -> void:
	# Light level 0.04 (ambient): no gain beyond the 2 m close override.
	var far := _dark_body("FarBody", Vector3(0, 0, -4.5))
	await _g.seconds(5.0)
	assert_array(Guards.guard_entries(&"actor.body_found")).is_empty()
	assert_bool(BodyDiscovery.of(_g.guard).has_found(far)).is_false()

	far.global_position = Vector3(0, 0, -1.4)
	await _g.seconds(2.5)
	var found := Guards.guard_entries(&"actor.body_found")
	assert_array(found).has_size(1)
	assert_str(String(found[0].data["body"])).is_equal("FarBody")


func test_a_minimal_non_guard_character_with_the_tags_is_found_and_woken() -> void:
	# A plain CharacterBody3D (test walker, capsule, Tags, BodyParts, the revive receptron): no
	# guard scene, no awareness. The ally and unconscious tags are all that count.
	var body := Characters.character(_g.scene, "Stranger", Vector3(0, 0, -4), [], PhysicsLayers.ACTORS, [REVIVE])
	var tags := Characters.tags_of(body)
	tags.add(&"actor.guard")
	tags.add(&"state.unconscious")
	await _g.seconds(10.0)
	assert_array(Guards.guard_entries(&"actor.body_found")).has_size(1)
	assert_array(Guards.guard_entries(&"actor.wake")).has_size(1)
	assert_bool(tags.has(&"state.unconscious")).is_false()


func test_found_bodies_and_the_tend_survive_save_and_load() -> void:
	var body := _downed_guard("Downed", BODY_FEET, UNCONSCIOUS)
	await _g.seconds(1.5)
	var discovery := BodyDiscovery.of(_g.guard)
	var saved := discovery.save_state()
	assert_bool(discovery.has_found(body)).is_true()
	discovery.model.forget(discovery.key_of(body))
	discovery.load_state(saved)
	assert_bool(discovery.has_found(body)).is_true()
	assert_object(discovery.tending).is_same(body)


# A minimal downed ally whose light level stays at ambient (0.04).
func _dark_body(body_name: String, feet: Vector3) -> CharacterBody3D:
	var body := Characters.character(_g.scene, body_name, feet, [], PhysicsLayers.ACTORS, [REVIVE])
	var tags := Characters.tags_of(body)
	tags.add(&"actor.guard")
	tags.add(&"state.unconscious")
	var exposure := LightExposure.new()
	exposure.name = "LightExposure"
	body.add_child(exposure)
	exposure.set_physics_process(false)
	exposure.level = 0.04
	return body
