extends GdUnitTestSuite
## Integration: LINE_OF_SIGHT propagation (blocked by the world layer only) and cause_id.

const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func test_world_layer_blocks_line_of_sight() -> void:
	_box(StaticBody3D.new(), "Wall", Vector3(0, 1, -2), PhysicsLayers.WORLD)
	var hidden := _listener("Hidden", Vector3(0, 1, -4))
	var visible := _listener("Visible", Vector3(0, 1, 4))
	await _settle()

	_emit_fire(Vector3(0, 1, 0), 6.0)
	await Fixtures.frames(get_tree(), 2)

	assert_array(_received_by(hidden)).is_empty()
	var seen := _received_by(visible)
	assert_array(seen).has_size(1)
	assert_str(seen[0].data["propagation"]).is_equal("line_of_sight")
	assert_float(seen[0].data["distance"]).is_equal_approx(4.0, 0.0001)


func test_objects_layer_does_not_block() -> void:
	var crate := RigidBody3D.new()
	crate.freeze = true
	_box(crate, "Crate", Vector3(0, 1, -2), PhysicsLayers.OBJECTS)
	var behind := _listener("Behind", Vector3(0, 1, -4))
	await _settle()

	_emit_fire(Vector3(0, 1, 0), 6.0)
	await Fixtures.frames(get_tree(), 2)

	assert_array(_received_by(behind)).has_size(1)


func test_source_and_receiver_bodies_do_not_block_themselves() -> void:
	# A brazier on the world layer emits from inside its own body; a barricade on the world layer
	# receives at its centre, inside its own body.
	var brazier := _box(StaticBody3D.new(), "Brazier", Vector3(0, 1, 0), PhysicsLayers.WORLD)
	var barricade := _box(StaticBody3D.new(), "Barricade", Vector3(0, 1, -1.5), PhysicsLayers.WORLD)
	_add_receiver(barricade)
	await _settle()

	StimulusSystem.emit(
		Stimulus.make_radius(&"fire", 3.0, Vector3(0, 1, 0), 3.0, brazier, Stimulus.Propagation.LINE_OF_SIGHT)
	)
	await Fixtures.frames(get_tree(), 2)

	assert_array(_received_by(barricade)).has_size(1)


func test_straight_propagation_ignores_walls() -> void:
	_box(StaticBody3D.new(), "Wall", Vector3(0, 1, -2), PhysicsLayers.WORLD)
	var hidden := _listener("Hidden", Vector3(0, 1, -4))
	await _settle()

	StimulusSystem.emit(Stimulus.make_radius(&"fire", 6.0, Vector3(0, 1, 0), 6.0))
	await Fixtures.frames(get_tree(), 2)

	assert_array(_received_by(hidden)).has_size(1)


func test_cause_id_defaults_to_parent_and_is_logged() -> void:
	var parent := Stimulus.make_radius(&"fire", 1.0, Vector3.ZERO, 1.0)
	StimulusSystem.emit(parent)
	var child := Stimulus.make_radius(&"noise", 1.0, Vector3.ZERO, 1.0)
	StimulusSystem.emit(child, parent)
	var explicit := Stimulus.make_radius(&"noise", 1.0, Vector3.ZERO, 1.0)
	explicit.cause_id = 77
	StimulusSystem.emit(explicit, parent)
	await Fixtures.frames(get_tree(), 2)

	assert_int(parent.cause_id).is_equal(0)
	assert_int(child.cause_id).is_equal(parent.id)
	assert_int(explicit.cause_id).is_equal(77)
	var logged := Fixtures.entries(&"stimulus.emitted", child.id)
	assert_int(logged[0].data["cause_id"]).is_equal(parent.id)


func _emit_fire(origin: Vector3, radius: float) -> void:
	StimulusSystem.emit(Stimulus.make_radius(&"fire", radius, origin, radius, null, Stimulus.Propagation.LINE_OF_SIGHT))


func _listener(listener_name: String, position: Vector3) -> Node3D:
	var receptrons: Array[Receptron] = [Fixtures.receptron(&"fire")]
	return Fixtures.entity(_root, listener_name, position, receptrons)


func _box(body: CollisionObject3D, body_name: String, position: Vector3, layer: int) -> Node3D:
	body.name = body_name
	body.collision_layer = layer
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.4)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_root.add_child(body)
	(body as Node3D).global_position = position
	return body as Node3D


func _add_receiver(body: Node3D) -> void:
	var receiver := StimulusReceiver.new()
	receiver.receptrons = [Fixtures.receptron(&"fire")]
	body.add_child(receiver)


func _received_by(entity: Node) -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == String(entity.name)
	)


func _settle() -> void:
	await Fixtures.frames(get_tree(), 2)
