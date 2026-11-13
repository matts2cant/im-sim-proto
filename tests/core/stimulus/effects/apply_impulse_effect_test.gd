extends GdUnitTestSuite
## Unit + integration: ApplyImpulseEffect pushes any RigidBody3D entity with a `force` receptron
## (ADR 0057): a minimal body built in code, floating (gravity 0) so only the push moves it.

const Wait := preload("res://tests/helpers/wait.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const PUSHED: Receptron = preload("res://objects/components/receptrons/pushed_by_force.tres")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)


func test_push_direction_radius_is_away_from_the_origin() -> void:
	var blast := Stimulus.make_radius(&"force.blast", 10.0, Vector3(1, 0, 0), 4.0)
	assert_vector(ApplyImpulseEffect.push_direction(blast, Vector3(1, 0, 3))).is_equal_approx(
		Vector3(0, 0, 1), Vector3.ONE * 0.0001
	)
	# At the origin itself: straight up.
	assert_vector(ApplyImpulseEffect.push_direction(blast, Vector3(1, 0, 0))).is_equal(Vector3.UP)


func test_push_direction_ray_is_the_stimulus_direction() -> void:
	var ray := Stimulus.make_ray(&"force.impact", 3.0, Vector3.ZERO, Vector3(0, 0, -2), 10.0)
	assert_vector(ApplyImpulseEffect.push_direction(ray, Vector3(5, 5, 5))).is_equal_approx(
		Vector3(0, 0, -1), Vector3.ONE * 0.0001
	)


func test_blast_pushes_a_minimal_body_with_falloff_and_lift() -> void:
	# 2 kg, 1.5 m from the origin of a 40 N s / 3 m blast: perceived 40 x (1 - 1.5 / 3) = 20 N s.
	var body := Fixtures.rigid_entity(_root, "Probe", Vector3(1.5, 1, 0), [PUSHED], [], 0.4, 2.0, 0.0)
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", 40.0, Vector3(0, 1, 0), 3.0))
	await Wait.frames(get_tree(), 3)

	var expected := Vector3(1, 0.3, 0).normalized() * 20.0 / 2.0
	assert_vector(body.linear_velocity).is_equal_approx(expected, Vector3.ONE * 0.05)
	var fired := Fixtures.entries(&"receptron.fired").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Probe"
	)
	assert_array(fired).has_size(1)
	assert_str(fired[0].data["receptron"]).is_equal("pushed_by_force")


func test_blast_beyond_its_radius_does_not_push() -> void:
	var body := Fixtures.rigid_entity(_root, "Probe", Vector3(3.5, 1, 0), [PUSHED], [], 0.4, 2.0, 0.0)
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", 40.0, Vector3(0, 1, 0), 3.0))
	await Wait.frames(get_tree(), 3)

	assert_float(body.linear_velocity.length()).is_equal(0.0)


func test_impact_ray_pushes_along_the_ray_at_the_hit_point() -> void:
	# 0.4 m box at z = -2: the ray hits its +z face 0.15 m above the centre and spins it about -x.
	var body := Fixtures.rigid_entity(_root, "Probe", Vector3(0, 1, -2), [PUSHED], [], 0.4, 2.0, 0.0)
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_ray(&"force.impact", 6.0, Vector3(0, 1.15, 0), Vector3.FORWARD, 10.0))
	await Wait.frames(get_tree(), 3)

	assert_vector(body.linear_velocity).is_equal_approx(Vector3(0, 0, -3), Vector3.ONE * 0.05)
	assert_float(body.angular_velocity.x).is_less(-0.5)
	var received := Fixtures.entries(&"stimulus.received").filter(
		func(entry: EventLogEntry) -> bool: return entry.target == "Probe"
	)
	assert_vector(received[0].data["position"] as Vector3).is_equal_approx(Vector3(0, 1.15, -1.8), Vector3.ONE * 0.01)


func test_entity_that_is_not_a_body_is_ignored() -> void:
	var probe := Fixtures.entity(_root, "Probe", Vector3(1, 1, 0), [PUSHED])
	await Wait.frames(get_tree(), 2)

	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", 40.0, Vector3(0, 1, 0), 3.0))
	await Wait.frames(get_tree(), 3)

	# Received and fired, nothing to push, no error.
	assert_array(Fixtures.entries(&"receptron.fired")).has_size(1)
	assert_vector(probe.global_position).is_equal(Vector3(1, 1, 0))
