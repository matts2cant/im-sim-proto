extends GdUnitTestSuite
## Integration: StimulusSystem.emit_now() delivers at once outside stimulus processing (a deliberate
## act such as using an item, also while the game is paused) and queues like emit() when an effect
## calls it during processing (no recursion; ADR 0057).

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")


## Calls emit_now() from inside a delivery.
class EmitNowEffect:
	extends Effect
	var type: StringName

	func _init(p_type: StringName) -> void:
		type = p_type

	func apply(ctx: EffectContext) -> void:
		StimulusSystem.emit_now(Stimulus.make_contact(type, 1.0, ctx.entity))


var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_outside_processing_it_is_delivered_at_once() -> void:
	var target := Fixtures.entity(
		_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"buff", [Fixtures.add_tag(&"a")])]
	)
	var buff := Stimulus.make_contact(&"buff", 1.0, target)

	StimulusSystem.emit_now(buff)

	assert_int(StimulusSystem.pending_count()).is_equal(0)
	assert_bool(Fixtures.tags_of(target).has(&"a")).is_true()
	assert_array(Fixtures.entries(&"stimulus.received", buff.id)).has_size(1)
	assert_int(buff.depth).is_equal(0)


func test_during_processing_it_queues_for_the_next_tick() -> void:
	var chain: Array[Effect] = [EmitNowEffect.new(&"second")]
	var receptrons: Array[Receptron] = [Fixtures.receptron(&"first", chain), Fixtures.receptron(&"second")]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, receptrons)
	var first := Stimulus.make_contact(&"first", 1.0, target)

	StimulusSystem.emit(first)
	await Wait.frames(get_tree(), 2)

	var second := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"second"
	)
	assert_array(second).is_empty()
	assert_int(StimulusSystem.pending_count()).is_equal(1)
	await Wait.frames(get_tree(), 1)
	second = EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"second"
	)
	assert_array(second).has_size(1)
	assert_int(second[0].data["depth"]).is_equal(1)
	assert_int(second[0].data["cause_id"]).is_equal(first.id)
