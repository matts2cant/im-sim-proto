extends GdUnitTestSuite
## The `restore` receptron (RestoreEffect) on minimal entities: a CONTACT `restore` gives a body
## full health and removes `state.dead` / `state.unconscious` (whatever added them); an entity
## without BodyParts just loses those tags. Logged `actor.reset`.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const Wait := preload("res://tests/helpers/wait.gd")
const RESTORE: Receptron = preload("res://actors/common/body/receptrons/restore.tres")

var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new()) as Node3D
	add_child(_world)


func test_restore_brings_a_dead_body_back_to_full_health() -> void:
	var extra: Array[Receptron] = [RESTORE]
	var character := Characters.character(_world, "Subject", Vector3(0, 0, 540), [], PhysicsLayers.ACTORS, extra)
	var body := Characters.body_parts(character)
	body.take_damage(&"damage.ballistic", 500.0, &"head")
	body.take_damage(&"damage.blunt", 200.0, &"leg_l")
	assert_bool(ActorState.is_dead(character)).is_true()

	StimulusSystem.emit(Stimulus.make_contact(RestoreEffect.STIMULUS, 1.0, character))
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.can_act(character)).is_true()
	assert_bool(body.is_dead()).is_false()
	for part in BodyDamageModel.PARTS:
		assert_float(body.health(part)).is_equal(body.model.max_health(part))
	assert_float(Attributes.read(character, BodyParts.MOVE_SPEED, 1.0)).is_equal_approx(1.0, 0.0001)
	var logged := EventLog.find(&"actor.reset")
	assert_array(logged).has_size(1)
	assert_str(str(logged[0].data["actor"])).is_equal("Subject")


func test_restore_without_a_body_removes_the_down_tags() -> void:
	var tags: Array[StringName] = [ActorState.UNCONSCIOUS, ActorState.DEAD]
	var entity := Fixtures.entity(_world, "Thing", Vector3(2, 0, 540), [RESTORE], tags)

	StimulusSystem.emit(Stimulus.make_contact(RestoreEffect.STIMULUS, 1.0, entity))
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.can_act(entity)).is_true()
	assert_array(EventLog.find(&"actor.reset")).has_size(1)


func test_an_entity_without_the_receptron_is_left_alone() -> void:
	var tags: Array[StringName] = [ActorState.UNCONSCIOUS]
	var entity := Fixtures.entity(_world, "Other", Vector3(4, 0, 540), [], tags)
	var restore := Stimulus.make_contact(RestoreEffect.STIMULUS, 1.0, entity)
	assert_bool(StimulusSystem.would_affect(restore)).is_false()

	StimulusSystem.emit(restore)
	await Wait.frames(get_tree(), 2)

	assert_bool(ActorState.has(entity, ActorState.UNCONSCIOUS)).is_true()
