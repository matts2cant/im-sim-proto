extends GdUnitTestSuite
## Unit/integration: ActorState reads a character's state from its tags, whoever added them (an
## AddTag effect on a minimal stimulus entity here; BodyParts injuries elsewhere).

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func test_entity_without_tags_can_act() -> void:
	var plain: Node3D = auto_free(Node3D.new())

	assert_bool(ActorState.can_act(plain)).is_true()
	assert_bool(ActorState.can_use_arms(plain)).is_true()
	assert_bool(ActorState.legs_disabled(plain)).is_false()


func test_sleep_gas_effect_stops_acting() -> void:
	var gas := Fixtures.receptron(&"gas.sleep", [Fixtures.add_tag(ActorState.UNCONSCIOUS)])
	var guard := Fixtures.entity(_root, "Guard", Vector3.ZERO, [gas])
	assert_bool(ActorState.can_act(guard)).is_true()

	StimulusSystem.emit(Stimulus.make_contact(&"gas.sleep", 1.0, guard))
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.can_act(guard)).is_false()
	assert_bool(ActorState.can_use_arms(guard)).is_false()
	assert_bool(ActorState.is_dead(guard)).is_false()


func test_cuffs_effect_only_stops_the_arms() -> void:
	var cuffs := Fixtures.receptron(&"restrain.cuffs", [Fixtures.add_tag(ActorState.ARMS_DISABLED)])
	var guard := Fixtures.entity(_root, "Guard", Vector3.ZERO, [cuffs])

	StimulusSystem.emit(Stimulus.make_contact(&"restrain.cuffs", 1.0, guard))
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.can_act(guard)).is_true()
	assert_bool(ActorState.can_use_arms(guard)).is_false()


func test_set_tag_adds_and_removes() -> void:
	var guard := Fixtures.entity(_root, "Guard", Vector3.ZERO, [])

	ActorState.set_tag(guard, ActorState.CROUCHING, true)
	assert_bool(ActorState.has(guard, ActorState.CROUCHING)).is_true()
	ActorState.set_tag(guard, ActorState.CROUCHING, false)
	assert_bool(ActorState.has(guard, ActorState.CROUCHING)).is_false()
