extends GdUnitTestSuite
## Integration: StimulusSystem.would_affect(), the dry run of a CONTACT stimulus (a consumable is
## refused when it would do nothing to its user; ADR 0057). Nothing is queued, run or logged.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")


## An effect that never applies (a heal on someone unhurt).
class Useless:
	extends Effect

	func can_apply(_ctx: EffectContext) -> bool:
		return false


var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_true_when_a_matching_receptron_has_an_effect_that_applies() -> void:
	var target := Fixtures.entity(
		_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"buff", [Fixtures.add_tag(&"a")])]
	)
	var buff := Stimulus.make_contact(&"buff", 1.0, target)

	assert_bool(StimulusSystem.would_affect(buff)).is_true()
	# A dry run: nothing queued, nothing logged, no tag added.
	assert_int(StimulusSystem.pending_count()).is_equal(0)
	assert_array(EventLog.find(&"stimulus.received")).is_empty()
	assert_bool(Fixtures.tags_of(target).has(&"a")).is_false()


func test_false_without_a_receiver_or_a_matching_receptron() -> void:
	var bare: Node3D = auto_free(Node3D.new())
	_world.add_child(bare)
	var deaf := Fixtures.entity(_world, "Deaf", Vector3.ZERO, [Fixtures.receptron(&"noise", [Fixtures.add_tag(&"a")])])

	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, bare))).is_false()
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, deaf))).is_false()


func test_false_when_every_effect_says_it_cannot_apply() -> void:
	var useless: Array[Effect] = [Useless.new()]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"buff", useless)])

	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, target))).is_false()


func test_respects_blocked_tags_and_own_stimuli() -> void:
	var receptron := Fixtures.receptron(&"buff", [Fixtures.add_tag(&"a")])
	receptron.blocked_tags = [&"state.immune"]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [receptron], [&"state.immune"])
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, target))).is_false()

	Fixtures.tags_of(target).remove(&"state.immune")
	# From itself: ignored unless the receptron opts in (include_self).
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, target, target))).is_false()
	receptron.include_self = true
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"buff", 1.0, target, target))).is_true()
