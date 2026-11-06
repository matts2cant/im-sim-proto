extends GdUnitTestSuite
## Integration: StimulusReceiver wiring, self-exclusion, tag gating and registration.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_wires_entity_tags_and_attributes_from_default_paths() -> void:
	var crate := Fixtures.entity(_world, "Crate", Vector3.ZERO, [], [&"material.wood"])
	var receiver := Fixtures.receiver_of(crate)

	assert_object(receiver.entity).is_same(crate)
	assert_object(receiver.tags).is_same(crate.get_node("Tags"))
	assert_object(receiver.attributes).is_same(crate.get_node("Attributes"))
	assert_bool(StimulusSystem.receivers().has(receiver)).is_true()


func test_entity_without_components_has_null_tags_and_attributes() -> void:
	var bare := Node3D.new()
	var receiver := StimulusReceiver.new()
	bare.add_child(receiver)
	_world.add_child(bare)

	assert_object(receiver.tags).is_null()
	assert_object(receiver.attributes).is_null()


func test_unregisters_on_exit_and_registers_again_on_reentry() -> void:
	var entity := Fixtures.entity(_world, "Mover", Vector3.ZERO, [])
	var receiver := Fixtures.receiver_of(entity)

	_world.remove_child(entity)
	assert_bool(StimulusSystem.receivers().has(receiver)).is_false()

	_world.add_child(entity)
	assert_bool(StimulusSystem.receivers().has(receiver)).is_true()


func test_own_stimulus_is_ignored_by_default() -> void:
	var entity := Fixtures.entity(_world, "Speaker", Vector3.ZERO, [Fixtures.receptron(&"noise")])

	StimulusSystem.emit(Stimulus.make_radius(&"noise", 5.0, Vector3.ZERO, 5.0, entity))
	await Fixtures.frames(get_tree(), 2)

	assert_array(EventLog.find(&"stimulus.received")).is_empty()


func test_own_stimulus_from_a_child_node_is_ignored_too() -> void:
	var entity := Fixtures.entity(_world, "Speaker", Vector3.ZERO, [Fixtures.receptron(&"noise")])

	StimulusSystem.emit(Stimulus.make_radius(&"noise", 5.0, Vector3.ZERO, 5.0, entity.get_node("Tags")))
	await Fixtures.frames(get_tree(), 2)

	assert_array(EventLog.find(&"stimulus.received")).is_empty()


func test_include_self_receptron_fires_for_own_stimulus_and_others_do_not() -> void:
	var own := Fixtures.receptron(&"noise", [], "own")
	own.include_self = true
	var entity := Fixtures.entity(_world, "Speaker", Vector3.ZERO, [Fixtures.receptron(&"noise", [], "other"), own])

	StimulusSystem.emit(Stimulus.make_radius(&"noise", 5.0, Vector3.ZERO, 5.0, entity))
	await Fixtures.frames(get_tree(), 2)

	var fired := EventLog.find(&"receptron.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["receptron"]).is_equal("own")


func test_tags_gate_receptrons_but_reception_is_logged() -> void:
	var receptron := Fixtures.receptron(&"fire", [Fixtures.add_tag(&"state.burning")] as Array[Effect])
	receptron.required_tags = [&"material.wood"] as Array[StringName]
	var metal := Fixtures.entity(_world, "MetalCrate", Vector3(1, 0, 0), [receptron], [&"material.metal"])
	var wood := Fixtures.entity(_world, "WoodCrate", Vector3(-1, 0, 0), [receptron], [&"material.wood"])

	StimulusSystem.emit(Stimulus.make_radius(&"fire", 1.0, Vector3.ZERO, 3.0))
	await Fixtures.frames(get_tree(), 2)

	assert_array(EventLog.find(&"stimulus.received")).has_size(2)
	var fired := EventLog.find(&"receptron.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].target).is_equal("WoodCrate")
	assert_array(fired[0].data["effects"]).contains_exactly(["AddTagEffect"])
	assert_bool(Fixtures.tags_of(wood).has(&"state.burning")).is_true()
	assert_bool(Fixtures.tags_of(metal).has(&"state.burning")).is_false()


func test_intensity_window_uses_perceived_intensity() -> void:
	var receptron := Fixtures.receptron(&"noise")
	receptron.min_intensity = 2.0
	Fixtures.entity(_world, "Close", Vector3(1, 0, 0), [receptron])
	Fixtures.entity(_world, "Far", Vector3(4, 0, 0), [receptron])

	# Perceived: 5 - 1 = 4 for Close, 5 - 4 = 1 for Far.
	StimulusSystem.emit(Stimulus.make_radius(&"noise", 5.0, Vector3.ZERO, 5.0))
	await Fixtures.frames(get_tree(), 2)

	var fired := EventLog.find(&"receptron.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].target).is_equal("Close")
	assert_int(fired[0].data["receptron"]).is_equal(0)
