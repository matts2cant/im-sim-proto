extends GdUnitTestSuite
## Integration: each Effect applied directly to a small entity.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: Node3D
var _entity: Node3D
var _ctx: EffectContext


func before_test() -> void:
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_entity = Fixtures.entity(_world, "Crate", Vector3(1, 2, 3), [], [&"material.wood"])
	var cause := Stimulus.make_radius(&"fire", 1.0, Vector3.ZERO, 5.0, _world)
	_ctx = EffectContext.new(Fixtures.receiver_of(_entity), cause, 0.75)


func after_test() -> void:
	StimulusSystem.clear()


func test_context_exposes_entity_tags_and_attributes() -> void:
	assert_object(_ctx.entity).is_same(_entity)
	assert_object(_ctx.tags()).is_same(Fixtures.tags_of(_entity))
	assert_object(_ctx.attributes()).is_same((_entity.get_node("Attributes") as Attributes).attribute_set)
	assert_float(_ctx.perceived).is_equal(0.75)


func test_add_and_remove_tag() -> void:
	Fixtures.add_tag(&"state.burning").apply(_ctx)
	assert_bool(_ctx.tags().has(&"state.burning")).is_true()

	var remove := RemoveTagEffect.new()
	remove.tag = &"state.burning"
	remove.apply(_ctx)
	assert_bool(_ctx.tags().has(&"state")).is_false()


func test_apply_modifier_adds_a_copy_each_time() -> void:
	_ctx.attributes().set_base(&"health", 100.0)
	var effect := ApplyModifierEffect.new()
	effect.modifier = Modifier.create(&"health", Modifier.Op.ADD, -10.0, &"burning")

	effect.apply(_ctx)
	effect.apply(_ctx)

	assert_float(_ctx.attributes().value(&"health")).is_equal(80.0)
	assert_bool(_ctx.attributes().modifiers().has(effect.modifier)).is_false()


func test_apply_modifier_can_replace_same_source() -> void:
	_ctx.attributes().set_base(&"speed", 4.0)
	var effect := ApplyModifierEffect.new()
	effect.modifier = Modifier.create(&"speed", Modifier.Op.MULTIPLY, 0.5, &"leg_damage")
	effect.replace_same_source = true

	effect.apply(_ctx)
	effect.apply(_ctx)

	assert_float(_ctx.attributes().value(&"speed")).is_equal(2.0)


func test_emit_stimulus_builds_from_receiver_position_with_entity_source() -> void:
	var effect := Fixtures.emit_radius(&"noise", 10.0, Stimulus.Propagation.PATH)

	var stimulus := effect.make_stimulus(_ctx)

	assert_str(stimulus.type).is_equal("noise")
	assert_float(stimulus.intensity).is_equal(10.0)
	assert_float(stimulus.radius).is_equal(10.0)
	assert_int(stimulus.propagation).is_equal(Stimulus.Propagation.PATH)
	assert_vector(stimulus.origin).is_equal(Vector3(1, 2, 3))
	assert_object(stimulus.source).is_same(_entity)
	assert_object(stimulus.target).is_same(_world)


func test_emit_stimulus_queues_it() -> void:
	Fixtures.emit_radius(&"noise", 10.0).apply(_ctx)

	assert_int(StimulusSystem.pending_count()).is_equal(1)


func test_play_cue_spawns_a_one_shot_player_at_the_receiver() -> void:
	var effect := PlayCueEffect.new()
	effect.stream = AudioStreamWAV.new()
	var viewport := get_viewport()
	var before := viewport.get_child_count()

	effect.apply(_ctx)

	assert_int(viewport.get_child_count()).is_equal(before + 1)
	var player := viewport.get_child(before) as AudioStreamPlayer3D
	assert_object(player).is_not_null()
	assert_vector(player.global_position).is_equal(Vector3(1, 2, 3))
	assert_bool(player.finished.is_connected(player.queue_free)).is_true()
	player.free()


func test_play_cue_without_stream_does_nothing() -> void:
	var viewport := get_viewport()
	var before := viewport.get_child_count()

	PlayCueEffect.new().apply(_ctx)

	assert_int(viewport.get_child_count()).is_equal(before)


func test_log_event_records_its_kind_with_the_stimulus() -> void:
	EventLog.clear()
	var effect := LogEventEffect.new()
	effect.apply(_ctx)
	# No kind: nothing recorded.
	assert_array(EventLog.entries()).is_empty()
	effect.kind = &"test.reacted"
	effect.apply(_ctx)
	var found := EventLog.find(&"test.reacted")
	assert_int(found.size()).is_equal(1)
	assert_str(found[0].target).is_equal("Crate")
	assert_int(found[0].data["id"]).is_equal(_ctx.stimulus.id)
	assert_float(found[0].data["perceived"]).is_equal(0.75)
