extends GdUnitTestSuite
## Integration (ADR 0131): ProximityTrigger on a minimal entity (the test grenade stuck on a floor)
## near minimal characters (walkers): it arms 2 s after sticking (not at 1.5 s, yes at 2.5 s) and
## blinks; it goes off for a walking character 2.0 m away (centre to centre, horizontal) and not at
## 3.0 m, for a crouched one at 0.7 m and not at 1.5 m; never for a rolling prop or a noise; not
## through a wall. Mines sit 20 m apart so one blast never reaches another test point.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const StimulusFixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const ORIGIN := Vector3(820, 0, 0)

var _root: Node3D
var _floor: StaticBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	_floor = Grenades.box(_root, ORIGIN + Vector3(0, -0.5, 0), Vector3(80, 1, 80))


func after_test() -> void:
	StimulusSystem.clear()


func test_arms_two_seconds_after_sticking_and_blinks() -> void:
	var mine := await _mine(Vector3.ZERO)
	var trigger := ProximityTrigger.of(mine)

	await Grenades.seconds(get_tree(), 1.5)
	assert_bool(trigger.is_armed).is_false()
	assert_bool(trigger.is_light_on()).is_false()
	assert_object(TargetStatus.word_of(mine, [])).is_null()
	await Grenades.seconds(get_tree(), 1.0)

	assert_bool(trigger.is_armed).is_true()
	assert_object(TargetStatus.word_of(mine, [])).is_same(ProximityTrigger.ARMED_WORD)
	assert_array(Grenades.logged(&"mine.armed")).has_size(1)
	# It blinks: lit and dark within one period.
	var lit := 0
	for frame in 60:
		await get_tree().physics_frame
		lit += 1 if trigger.is_light_on() else 0
	assert_int(lit).is_between(5, 40)


func test_walking_character_triggers_at_two_metres_not_at_three() -> void:
	var near_mine := await _armed_mine(Vector3(-10, 0, 0))
	var far_mine := await _armed_mine(Vector3(10, 0, 0))
	var near := _walker("Near", Vector3(-10, 0, -2.0))
	var far := _walker("Far", Vector3(10, 0, -3.0))
	near.set(&"drive", Vector3(0.5, 0, 0))
	far.set(&"drive", Vector3(0.5, 0, 0))

	await Grenades.seconds(get_tree(), 0.3)

	assert_bool(is_instance_valid(near_mine)).is_false()
	assert_bool(is_instance_valid(far_mine)).is_true()
	var triggered := Grenades.logged(&"mine.triggered")
	assert_array(triggered).has_size(1)
	assert_str(str(triggered[0].data["by"])).is_equal("Near")


func test_crouched_character_triggers_at_point_seven_metres_not_at_one_and_a_half() -> void:
	var near_mine := await _armed_mine(Vector3(-10, 0, 10))
	var far_mine := await _armed_mine(Vector3(10, 0, 10))
	var near := _walker("CrouchedNear", Vector3(-10, 0, 9.3))
	var far := _walker("CrouchedFar", Vector3(10, 0, 8.5))
	ActorState.set_tag(near, ActorState.CROUCHING, true)
	ActorState.set_tag(far, ActorState.CROUCHING, true)

	await Grenades.seconds(get_tree(), 0.3)

	assert_bool(is_instance_valid(near_mine)).is_false()
	assert_bool(is_instance_valid(far_mine)).is_true()
	# Standing up at 1.5 m is close enough.
	ActorState.set_tag(far, ActorState.CROUCHING, false)
	await Grenades.seconds(get_tree(), 0.2)
	assert_bool(is_instance_valid(far_mine)).is_false()


func test_a_rolling_prop_and_a_noise_never_trigger_it() -> void:
	var mine := await _armed_mine(Vector3(0, 0, -15))
	# Floating (no gravity, no friction): it glides past 0.5 m from the mine at 4 m/s.
	var prop := StimulusFixtures.rigid_entity(_root, "Ball", ORIGIN + Vector3(-2, 0.3, -14.5), [], [], 0.3, 2.0, 0.0)
	prop.linear_velocity = Vector3(4, 0, 0)
	StimulusSystem.emit(Stimulus.make_noise(30.0, ORIGIN + Vector3(0.5, 0.5, -15), prop))

	await Grenades.seconds(get_tree(), 1.0)

	assert_bool(is_instance_valid(mine)).is_true()
	assert_bool(ProximityTrigger.of(mine).is_armed).is_true()
	assert_float(prop.global_position.x).is_greater(ORIGIN.x)


func test_its_tag_filter_lets_ignored_characters_pass() -> void:
	# A mine that ignores `actor.guard`: a guard-tagged walker standing 1.5 m away (centre to centre,
	# inside the 2.5 m reach) never sets it off; an untagged walker then placed 1.5 m away does.
	var mine := await _armed_mine(Vector3(-20, 0, -20))
	var trigger := ProximityTrigger.of(mine)
	trigger.config = trigger.config.duplicate() as ProximityTriggerConfig
	trigger.config.ignored_tags = [&"actor.guard"] as Array[StringName]
	var guard := _walker("Guard", Vector3(-20, 0, -18.5))
	ActorState.set_tag(guard, &"actor.guard", true)

	await Grenades.seconds(get_tree(), 0.3)
	assert_bool(is_instance_valid(mine)).is_true()

	_walker("Other", Vector3(-21.5, 0, -20))
	await Grenades.seconds(get_tree(), 0.3)
	assert_bool(is_instance_valid(mine)).is_false()
	var triggered := Grenades.logged(&"mine.triggered")
	assert_array(triggered).has_size(1)
	assert_str(str(triggered[0].data["by"])).is_equal("Other")


func test_a_wall_hides_a_character_from_it() -> void:
	var mine := await _armed_mine(Vector3(0, 0, 20))
	Grenades.box(_root, ORIGIN + Vector3(0, 1.5, 19), Vector3(4, 3, 0.2))
	_walker("Hidden", Vector3(0, 0, 18.0))

	await Grenades.seconds(get_tree(), 0.3)

	assert_bool(is_instance_valid(mine)).is_true()


# A test grenade stuck on the floor at `at` (from ORIGIN), arming.
func _mine(at: Vector3) -> RigidBody3D:
	var grenade := Grenades.grenade(_root, ORIGIN + at + Vector3(0, 2, 0))
	await Wait.frames(get_tree(), 1)
	var shape := _floor.get_node("Shape") as Node3D
	Sticky.of(grenade).stick(shape, Sticky.of(grenade).pose_on(ORIGIN + at, Vector3.UP, Vector3.FORWARD))
	return grenade


func _armed_mine(at: Vector3) -> RigidBody3D:
	var grenade := await _mine(at)
	await Grenades.seconds(get_tree(), 2.1)
	assert_bool(ProximityTrigger.of(grenade).is_armed).is_true()
	return grenade


func _walker(walker_name: String, at: Vector3) -> CharacterBody3D:
	return Characters.character(_root, walker_name, ORIGIN + at, []) as CharacterBody3D
