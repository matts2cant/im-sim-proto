extends GdUnitTestSuite
## Audit S5: "down" has one source of truth, the `state.dead` / `state.unconscious` tags. A body
## knocked out or killed by adding the tag alone (an Effect, sleep gas) is down for every reader:
## BodyParts, the dummy's pose (DownedPose), the range's reset button, the heal effect (and the
## Health tab: health_tab_test.gd). A body without Tags keeps the state in its own container.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Wait := preload("res://tests/helpers/wait.gd")
const DUMMY: PackedScene = preload("res://actors/dummy/training_dummy.tscn")
const ORIGIN := Vector3(-420, 0, 300)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	_root.position = ORIGIN
	add_child(_root)


func test_body_parts_reads_the_tags_whatever_added_them() -> void:
	var character := Characters.character(_root, "Subject", Vector3(4, 0, 0), [])
	var body := Characters.body_parts(character)
	var tags := Characters.tags_of(character)

	tags.add(ActorState.UNCONSCIOUS)
	assert_bool(body.is_unconscious()).is_true()
	# Already down: a knockout blow does not knock it out a second time.
	body.take_damage(&"damage.stun", 500.0)
	assert_array(EventLog.find(&"actor.knocked_out")).is_empty()
	tags.remove(ActorState.UNCONSCIOUS)
	assert_bool(body.is_unconscious()).is_false()

	tags.add(ActorState.DEAD)
	assert_bool(body.is_dead()).is_true()
	assert_float(body.take_damage(&"damage.stun", 10.0)).is_equal(0.0)


func test_a_tag_only_knockout_lays_the_dummy_down_and_the_button_stands_it_up() -> void:
	var dummy := DUMMY.instantiate() as TrainingDummy
	dummy.name = "Dummy"
	_root.add_child(dummy)
	var button := BodyResetButton.new()
	button.scope_path = NodePath("..")
	_root.add_child(button)
	await Wait.frames(get_tree(), 2)

	ActorState.set_tag(dummy, ActorState.UNCONSCIOUS, true)
	await Wait.frames(get_tree(), 2)
	assert_bool((dummy.get_node("DownedPose") as DownedPose).is_down).is_true()

	assert_int(button.reset_downed()).is_equal(1)
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.can_act(dummy)).is_true()
	assert_bool((dummy.get_node("DownedPose") as DownedPose).is_down).is_false()
	# Standing now: nothing left to reset.
	assert_int(button.reset_downed()).is_equal(0)


func test_a_tag_only_death_refuses_healing() -> void:
	var dummy := DUMMY.instantiate() as TrainingDummy
	_root.add_child(dummy)
	await Wait.frames(get_tree(), 2)
	dummy.body.take_damage(&"damage.blunt", 30.0, &"torso")
	var heal := Stimulus.make_contact(&"heal", 20.0, dummy)
	assert_bool(StimulusSystem.would_affect(heal)).is_true()

	ActorState.set_tag(dummy, ActorState.DEAD, true)

	assert_bool(StimulusSystem.would_affect(heal)).is_false()


func test_a_body_without_tags_keeps_and_saves_its_own_state() -> void:
	var entity := Node3D.new()
	entity.name = "Untagged"
	var body := BodyParts.new()
	body.name = "BodyParts"
	body.profile = Characters.BODY_PROFILE
	entity.add_child(body)
	_root.add_child(entity)

	body.take_damage(&"damage.stun", 500.0)
	assert_bool(body.is_unconscious()).is_true()
	var saved := body.save_state()
	body.revive()
	assert_bool(body.is_unconscious()).is_false()

	body.load_state(saved)

	assert_bool(body.is_unconscious()).is_true()
	assert_bool(body.is_dead()).is_false()
