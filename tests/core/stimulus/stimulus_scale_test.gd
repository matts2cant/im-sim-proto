extends GdUnitTestSuite
## Integration: Stimulus.scale_attribute (what an entity puts out is scaled by its own attribute on
## emit) and ChangeAttributeEffect (a biocell's `energy`), on minimal entities built in code
## (ADR 0061).

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_emit_scales_the_intensity_by_the_source_attribute_and_logs_it() -> void:
	var source := Fixtures.entity(_world, "Healer", Vector3.ZERO, [])
	_attributes(source).add_modifier(Modifier.create(&"medical_heal_mult", Modifier.Op.MULTIPLY, 3.0))
	var target := Fixtures.entity(_world, "Target", Vector3(1, 0, 0), [Fixtures.receptron(&"heal")])
	var heal := Stimulus.make_contact(&"heal", 30.0, target, source)
	heal.scale_attribute = &"medical_heal_mult"

	StimulusSystem.emit_now(heal)

	var received := EventLog.find(&"stimulus.received")
	assert_array(received).has_size(1)
	assert_float(received[0].data["perceived"]).is_equal_approx(90.0, 0.001)
	var emitted := EventLog.find(&"stimulus.emitted")[0]
	assert_float(emitted.data["scale"]).is_equal_approx(3.0, 0.001)
	assert_str(String(emitted.data["scale_attribute"])).is_equal("medical_heal_mult")


func test_without_the_attribute_or_a_source_the_intensity_is_unchanged() -> void:
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"heal")])
	var plain := Fixtures.entity(_world, "Plain", Vector3(1, 0, 0), [])
	var from_plain := Stimulus.make_contact(&"heal", 30.0, target, plain)
	from_plain.scale_attribute = &"medical_heal_mult"
	var sourceless := Stimulus.make_contact(&"heal", 30.0, target)
	sourceless.scale_attribute = &"medical_heal_mult"

	StimulusSystem.emit_now(from_plain)
	StimulusSystem.emit_now(sourceless)

	for entry in EventLog.find(&"stimulus.received"):
		assert_float(entry.data["perceived"]).is_equal_approx(30.0, 0.001)


func test_emit_stimulus_effect_scales_by_the_reacting_entity() -> void:
	var emit := Fixtures.emit_radius(&"noise", 4.0)
	emit.scale_attribute = &"noise_mult"
	var emitter := Fixtures.entity(_world, "Emitter", Vector3.ZERO, [Fixtures.receptron(&"poke", [emit])])
	_attributes(emitter).add_modifier(Modifier.create(&"noise_mult", Modifier.Op.MULTIPLY, 2.5))

	StimulusSystem.emit_now(Stimulus.make_contact(&"poke", 1.0, emitter))
	await Wait.frames(get_tree(), 2)

	var noise := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"noise"
	)
	assert_array(noise).has_size(1)
	assert_float(noise[0].data["intensity"]).is_equal_approx(10.0, 0.001)


func test_change_attribute_restores_up_to_the_max_and_refuses_when_full() -> void:
	var restore := ChangeAttributeEffect.new()
	restore.attribute = &"energy"
	restore.max_attribute = &"energy_max"
	var effects: Array[Effect] = [restore]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"energy", effects)])
	_attributes(target).set_base(&"energy", 90.0)
	_attributes(target).set_base(&"energy_max", 100.0)

	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"energy", 25.0, target))).is_true()
	StimulusSystem.emit_now(Stimulus.make_contact(&"energy", 25.0, target))

	assert_float(_attributes(target).base(&"energy")).is_equal_approx(100.0, 0.001)
	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"energy", 25.0, target))).is_false()


func test_change_attribute_does_not_apply_to_entities_without_the_attribute() -> void:
	var restore := ChangeAttributeEffect.new()
	restore.attribute = &"energy"
	var effects: Array[Effect] = [restore]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"energy", effects)])

	assert_bool(StimulusSystem.would_affect(Stimulus.make_contact(&"energy", 25.0, target))).is_false()


func test_change_attribute_drains_down_to_the_minimum() -> void:
	var drain := ChangeAttributeEffect.new()
	drain.attribute = &"energy"
	drain.per_intensity = -1.0
	var effects: Array[Effect] = [drain]
	var target := Fixtures.entity(_world, "Target", Vector3.ZERO, [Fixtures.receptron(&"emp", effects)])
	_attributes(target).set_base(&"energy", 30.0)

	StimulusSystem.emit_now(Stimulus.make_contact(&"emp", 50.0, target))

	assert_float(_attributes(target).base(&"energy")).is_equal(0.0)


func _attributes(entity: Node) -> AttributeSet:
	return Attributes.of(entity).attribute_set
