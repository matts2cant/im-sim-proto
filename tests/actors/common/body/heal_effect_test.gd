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


func test_heal_on_a_part_hitbox_heals_that_part_only() -> void:
	# A medkit used on one part (ADR 0111): the CONTACT touches the part's hitbox, like a hit does.
	_dummy.body.take_damage(&"damage.blunt", 40.0, &"arm_l")
	_dummy.body.take_damage(&"damage.blunt", 30.0, &"torso")
	var arm := Hitboxes.of(_dummy).box(&"arm_l")
	var heal := Stimulus.make_contact(&"heal", 30.0, arm)
	assert_bool(StimulusSystem.would_affect(heal)).is_true()

	StimulusSystem.emit(heal)
	await Objects.frames(get_tree(), 2)

	assert_float(_dummy.body.health(&"arm_l")).is_equal_approx(40.0, 0.001)
	assert_float(_dummy.body.health(&"torso")).is_equal_approx(50.0, 0.001)
	var healed := EventLog.find(&"actor.healed")
	assert_array(healed).has_size(1)
	assert_str(str(healed[0].data["part"])).is_equal("arm_l")


func test_heal_on_an_unhurt_part_would_not_affect() -> void:
	_dummy.body.take_damage(&"damage.blunt", 30.0, &"torso")
	var head := Stimulus.make_contact(&"heal", 30.0, Hitboxes.of(_dummy).box(&"head"))
	assert_bool(StimulusSystem.would_affect(head)).is_false()
	var torso := Stimulus.make_contact(&"heal", 30.0, Hitboxes.of(_dummy).box(&"torso"))
	assert_bool(StimulusSystem.would_affect(torso)).is_true()
