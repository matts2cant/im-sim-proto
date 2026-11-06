extends GdUnitTestSuite
## Integration: a `heal` CONTACT heals any character whose receiver has the `heal` receptron
## (HealEffect -> BodyParts.heal(); ADR 0057), here the training dummy, not the player; and the dry
## run (StimulusSystem.would_affect) says no when there is nothing to heal.

const Objects := preload("res://tests/objects/object_test_helpers.gd")
const DUMMY := "res://actors/dummy/training_dummy.tscn"

var _dummy: TrainingDummy


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_dummy = auto_free(load(DUMMY).instantiate()) as TrainingDummy
	add_child(_dummy)
	await Objects.frames(get_tree(), 2)


func test_heal_stimulus_heals_a_hurt_dummy() -> void:
	_dummy.body.take_damage(&"damage.blunt", 30.0, &"torso")
	var heal := Stimulus.make_contact(&"heal", 20.0, _dummy)
	assert_bool(StimulusSystem.would_affect(heal)).is_true()

	StimulusSystem.emit(heal)
	await Objects.frames(get_tree(), 2)

	assert_float(_dummy.body.health(&"torso")).is_equal_approx(70.0, 0.001)
	var healed := EventLog.find(&"actor.healed")
	assert_array(healed).has_size(1)
	assert_float(healed[0].data["amount"]).is_equal_approx(20.0, 0.001)


func test_unhurt_or_dead_dummy_would_not_be_affected() -> void:
	var heal := Stimulus.make_contact(&"heal", 20.0, _dummy)
	assert_bool(StimulusSystem.would_affect(heal)).is_false()

	_dummy.body.take_damage(&"damage.ballistic", 100.0, &"head")
	assert_bool(_dummy.body.is_dead()).is_true()
	assert_bool(StimulusSystem.would_affect(heal)).is_false()
