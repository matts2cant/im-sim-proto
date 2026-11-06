extends GdUnitTestSuite
## Integration: the real StimulusSystem autoload: tick queueing, FIFO order, chain depth cap and
## RADIUS delivery. Only physics frames drive it.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_emit_is_delivered_on_the_next_physics_tick() -> void:
	var listener := Fixtures.entity(_world, "Listener", Vector3(2, 0, 0), [Fixtures.receptron(&"fire")])
	var fire := Stimulus.make_radius(&"fire", 1.0, Vector3.ZERO, 4.0)

	StimulusSystem.emit(fire)

	assert_int(StimulusSystem.pending_count()).is_equal(1)
	assert_array(EventLog.find(&"stimulus.received")).is_empty()
	# Awaiting a physics frame resumes before that frame's processing: the second await
	# observes the first tick's delivery.
	await Fixtures.frames(get_tree(), 2)
	var emitted := Fixtures.entries(&"stimulus.emitted", fire.id)
	var received := Fixtures.entries(&"stimulus.received", fire.id)
	assert_int(received.size()).is_equal(1)
	assert_int(received[0].tick).is_equal(emitted[0].tick)
	assert_str(received[0].target).is_equal(listener.name)
	assert_float(received[0].data["perceived"]).is_equal_approx(0.5, 0.0001)
	assert_float(received[0].data["distance"]).is_equal_approx(2.0, 0.0001)
	assert_str(received[0].data["propagation"]).is_equal("straight")
	assert_int(StimulusSystem.pending_count()).is_equal(0)


func test_emitted_entry_has_the_documented_fields() -> void:
	var source: Node3D = auto_free(Node3D.new())
	source.name = "Barrel"
	StimulusSystem.emit(Stimulus.make_radius(&"fire", 2.0, Vector3(1, 2, 3), 4.0, source))
	await Fixtures.frames(get_tree(), 2)

	var entry := EventLog.find(&"stimulus.emitted")[0]
	assert_str(entry.source).is_equal("Barrel")
	assert_dict(entry.data).contains_key_value("type", &"fire")
	assert_dict(entry.data).contains_key_value("intensity", 2.0)
	assert_dict(entry.data).contains_key_value("origin", Vector3(1, 2, 3))
	assert_dict(entry.data).contains_key_value("depth", 0)
	assert_dict(entry.data).contains_key_value("source", "Barrel")
	assert_int(entry.data["id"]).is_greater(0)


func test_ids_are_unique_and_queue_is_fifo() -> void:
	Fixtures.entity(_world, "Listener", Vector3.ZERO, [Fixtures.receptron(&"noise")])
	var first := Stimulus.make_noise(5.0, Vector3.ZERO)
	var second := Stimulus.make_noise(3.0, Vector3.ZERO)

	StimulusSystem.emit(first)
	StimulusSystem.emit(second)
	await Fixtures.frames(get_tree(), 2)

	assert_int(second.id).is_greater(first.id)
	var received := EventLog.find(&"stimulus.received")
	assert_int(received.size()).is_equal(2)
	assert_int(received[0].data["id"]).is_equal(first.id)
	assert_int(received[1].data["id"]).is_equal(second.id)
	assert_int(received[1].tick).is_equal(received[0].tick)


func test_stimuli_emitted_by_effects_wait_for_the_next_tick() -> void:
	var relay_receptron := Fixtures.receptron(&"ping", [Fixtures.emit_radius(&"pong", 5.0)] as Array[Effect])
	Fixtures.entity(_world, "Relay", Vector3.ZERO, [relay_receptron])
	Fixtures.entity(_world, "Listener", Vector3(1, 0, 0), [Fixtures.receptron(&"pong")])

	StimulusSystem.emit(Stimulus.make_radius(&"ping", 1.0, Vector3.ZERO, 2.0))
	await Fixtures.frames(get_tree(), 2)
	# Frame 1 delivered the ping and queued the pong; it is still pending at the start of frame 2.
	assert_array(EventLog.find(&"receptron.fired")).has_size(1)
	assert_int(StimulusSystem.pending_count()).is_equal(1)
	await Fixtures.frames(get_tree(), 1)

	var emitted := EventLog.find(&"stimulus.emitted")
	assert_array(emitted).has_size(2)
	assert_str(emitted[1].data["type"]).is_equal("pong")
	assert_int(emitted[1].tick).is_equal(emitted[0].tick + 1)
	assert_int(emitted[1].data["depth"]).is_equal(1)
	assert_str(emitted[1].source).is_equal("Relay")
	var heard := Fixtures.entries(&"stimulus.received", emitted[1].data["id"])
	assert_array(heard).has_size(1)
	assert_str(heard[0].target).is_equal("Listener")


func test_chain_deeper_than_cap_is_dropped_and_logged() -> void:
	var echo := Fixtures.receptron(&"echo", [Fixtures.emit_radius(&"echo", 2.0)] as Array[Effect])
	echo.include_self = true
	Fixtures.entity(_world, "Echo", Vector3.ZERO, [echo])

	StimulusSystem.emit(Stimulus.make_radius(&"echo", 2.0, Vector3.ZERO, 2.0))
	await Fixtures.frames(get_tree(), StimulusSystem.MAX_DEPTH + 4)

	var emitted := EventLog.find(&"stimulus.emitted")
	assert_array(emitted).has_size(StimulusSystem.MAX_DEPTH + 1)
	assert_int(emitted[emitted.size() - 1].data["depth"]).is_equal(StimulusSystem.MAX_DEPTH)
	var dropped := EventLog.find(&"stimulus.dropped")
	assert_array(dropped).has_size(1)
	assert_int(dropped[0].data["depth"]).is_equal(StimulusSystem.MAX_DEPTH + 1)
	assert_int(StimulusSystem.pending_count()).is_equal(0)


func test_explicit_parent_sets_depth_outside_processing() -> void:
	var parent := Stimulus.make_noise(1.0, Vector3.ZERO)
	parent.depth = 3
	var child := Stimulus.make_noise(1.0, Vector3.ZERO)

	StimulusSystem.emit(child, parent)

	assert_int(child.depth).is_equal(4)
	StimulusSystem.clear()


func test_radius_ignores_receivers_out_of_range_or_type() -> void:
	Fixtures.entity(_world, "Far", Vector3(5, 0, 0), [Fixtures.receptron(&"fire")])
	Fixtures.entity(_world, "Deaf", Vector3(1, 0, 0), [Fixtures.receptron(&"noise")])
	Fixtures.entity(_world, "Near", Vector3(0, 0, 3), [Fixtures.receptron(&"fire")])

	StimulusSystem.emit(Stimulus.make_radius(&"fire", 1.0, Vector3.ZERO, 4.0))
	await Fixtures.frames(get_tree(), 2)

	var received := EventLog.find(&"stimulus.received")
	assert_array(received).has_size(1)
	assert_str(received[0].target).is_equal("Near")


func test_hierarchical_receptron_receives_subtypes() -> void:
	Fixtures.entity(_world, "Target", Vector3(1, 0, 0), [Fixtures.receptron(&"damage", [], "any_damage")])

	StimulusSystem.emit(Stimulus.make_radius(&"damage.explosive", 50.0, Vector3.ZERO, 5.0))
	await Fixtures.frames(get_tree(), 2)

	var fired := EventLog.find(&"receptron.fired")
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["receptron"]).is_equal("any_damage")


func test_clear_drops_pending_stimuli() -> void:
	Fixtures.entity(_world, "Listener", Vector3.ZERO, [Fixtures.receptron(&"noise")])
	StimulusSystem.emit(Stimulus.make_noise(5.0, Vector3.ZERO))

	StimulusSystem.clear()
	await Fixtures.frames(get_tree(), 2)

	assert_array(EventLog.find(&"stimulus.emitted")).is_empty()
