extends GdUnitTestSuite
## Integration: CONTACT and RAY delivery through the real StimulusSystem, against physics bodies.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _world: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_world = auto_free(Node3D.new())
	add_child(_world)


func test_contact_reaches_only_the_target() -> void:
	var target := Fixtures.entity(_world, "Target", Vector3(10, 0, 0), [Fixtures.receptron(&"damage.blunt")])
	Fixtures.entity(_world, "Bystander", Vector3.ZERO, [Fixtures.receptron(&"damage.blunt")])

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 25.0, target))
	await Wait.frames(get_tree(), 2)

	var received := EventLog.find(&"stimulus.received")
	assert_array(received).has_size(1)
	assert_str(received[0].target).is_equal("Target")
	assert_float(received[0].data["perceived"]).is_equal(25.0)


func test_contact_on_a_child_node_reaches_the_entity() -> void:
	var target := Fixtures.entity(_world, "Guard", Vector3.ZERO, [Fixtures.receptron(&"damage")])
	var hitbox := Node3D.new()
	hitbox.name = "Head"
	target.add_child(hitbox)

	StimulusSystem.emit(Stimulus.make_contact(&"damage.blunt", 10.0, hitbox))
	await Wait.frames(get_tree(), 2)

	assert_str(EventLog.find(&"stimulus.received")[0].target).is_equal("Guard")


func test_ray_reaches_only_the_first_collider() -> void:
	_body("Near", Vector3(0, 0, -3))
	_body("Far", Vector3(0, 0, -6))
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 20.0, Vector3.ZERO, Vector3.FORWARD, 10.0))
	await Wait.frames(get_tree(), 2)

	var received := EventLog.find(&"stimulus.received")
	assert_array(received).has_size(1)
	assert_str(received[0].target).is_equal("Near")
	assert_float(received[0].data["perceived"]).is_equal(20.0)
	assert_float(received[0].data["distance"]).is_equal_approx(2.5, 0.01)


func test_ray_that_hits_nothing_delivers_nothing() -> void:
	_body("Beside", Vector3(3, 0, -3))
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 20.0, Vector3.ZERO, Vector3.FORWARD, 10.0))
	await Wait.frames(get_tree(), 2)

	assert_array(EventLog.find(&"stimulus.emitted")).has_size(1)
	assert_array(EventLog.find(&"stimulus.received")).is_empty()


func test_ray_ignores_its_source_body() -> void:
	var shooter := _body("Shooter", Vector3.ZERO)
	_body("Target", Vector3(0, 0, -4))
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_ray(&"damage.ballistic", 20.0, Vector3.ZERO, Vector3.FORWARD, 10.0, shooter))
	await Wait.frames(get_tree(), 2)

	var received := EventLog.find(&"stimulus.received")
	assert_array(received).has_size(1)
	assert_str(received[0].target).is_equal("Target")


## A 1 m static box with a receiver for `damage`.
func _body(body_name: String, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	collision.shape = box
	body.add_child(collision)
	var receiver := StimulusReceiver.new()
	receiver.receptrons = [Fixtures.receptron(&"damage")] as Array[Receptron]
	body.add_child(receiver)
	_world.add_child(body)
	return body
