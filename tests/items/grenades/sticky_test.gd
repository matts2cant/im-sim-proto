extends GdUnitTestSuite
## Integration (ADR 0131): Sticky on a minimal entity. A stuck body follows what it is stuck to: a
## sliding door whose panel shape moves (the body stays), a body that turns about a hinge, a crate
## pushed along; it lets go and falls when that thing is gone.

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")
const ORIGIN := Vector3(760, 0, 0)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)
	Grenades.box(_root, ORIGIN + Vector3(0, -0.5, 0), Vector3(30, 1, 30))


func after_test() -> void:
	StimulusSystem.clear()


func test_a_grenade_stuck_on_a_sliding_panel_follows_it() -> void:
	var user := Grenades.thrower(_root, ORIGIN)
	# A door: a world body whose panel shape (face 1.0 m ahead of the eye) slides, the body stays.
	var door := Grenades.box(_root, ORIGIN + Vector3(0, 1.1, -1.1), Vector3(1.2, 2.2, 0.2))
	var panel := door.get_node("Shape") as CollisionShape3D
	await Wait.frames(get_tree(), 3)
	Grenades.holder_of(user).trigger()
	var grenade := _spawned()
	var start := grenade.global_position
	assert_object(Sticky.of(grenade).target).is_same(panel)

	panel.position.x += 1.0
	await Wait.frames(get_tree(), 2)

	assert_vector(grenade.global_position).is_equal_approx(start + Vector3(1, 0, 0), Vector3.ONE * 0.01)


func test_a_grenade_stuck_on_a_turning_leaf_turns_with_it() -> void:
	var hinge := Grenades.box(_root, ORIGIN + Vector3(3, 1.1, 0), Vector3(0.2, 2.2, 1.0))
	var shape := hinge.get_node("Shape") as Node3D
	shape.position = Vector3(0, 0, -0.5)
	var grenade := Grenades.grenade(_root, ORIGIN + Vector3(5, 1, 0))
	await Wait.frames(get_tree(), 2)
	# On the leaf's +X face, 0.7 m from the hinge.
	var pose := ThrowRules.stick_transform(ORIGIN + Vector3(3.1, 1.2, -0.7), Vector3.RIGHT, Vector3.LEFT, 0.04)
	Sticky.of(grenade).stick(shape, pose)

	hinge.rotation.y = PI * 0.5
	await Wait.frames(get_tree(), 2)

	# Turned 90 degrees about the hinge's vertical axis: +X -> -Z, -Z -> -X.
	var expected := ORIGIN + Vector3(3, 1.1, 0) + Basis(Vector3.UP, PI * 0.5) * Vector3(0.14, 0.1, -0.7)
	assert_vector(grenade.global_position).is_equal_approx(expected, Vector3.ONE * 0.01)
	assert_vector(grenade.global_basis.y).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.01)


func test_a_grenade_stuck_on_a_crate_rides_it_without_pushing_it() -> void:
	var crate := RigidBody3D.new()
	crate.collision_layer = PhysicsLayers.OBJECTS
	crate.collision_mask = PhysicsLayers.OBJECT_MASK
	crate.mass = 10.0
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3(0.6, 0.6, 0.6)
	shape.shape = cube
	crate.add_child(shape)
	crate.position = ORIGIN + Vector3(-3, 0.3, 0)
	_root.add_child(crate)
	var grenade := Grenades.grenade(_root, ORIGIN + Vector3(-5, 1, 0))
	await Wait.frames(get_tree(), 20)
	var top := ThrowRules.stick_transform(crate.global_position + Vector3(0, 0.3, 0), Vector3.UP, Vector3.FORWARD, 0.04)
	Sticky.of(grenade).stick(shape, top)
	await Wait.frames(get_tree(), 20)
	# Still at rest with a grenade on it.
	assert_float(crate.linear_velocity.length()).is_less(0.05)

	crate.global_position += Vector3(1, 0, 0)
	await Wait.frames(get_tree(), 2)

	assert_vector(grenade.global_position).is_equal_approx(
		crate.global_position + Vector3(0, 0.34, 0), Vector3.ONE * 0.02
	)


func test_lets_go_when_what_it_sticks_to_is_gone() -> void:
	var post := Grenades.box(_root, ORIGIN + Vector3(0, 1, 5), Vector3(0.4, 2, 0.4))
	var grenade := Grenades.grenade(_root, ORIGIN + Vector3(2, 1, 5))
	await Wait.frames(get_tree(), 2)
	var pose := ThrowRules.stick_transform(ORIGIN + Vector3(0.2, 1.5, 5), Vector3.RIGHT, Vector3.LEFT, 0.04)
	Sticky.of(grenade).stick(post.get_node("Shape") as Node3D, pose)
	await Wait.frames(get_tree(), 2)

	post.free()
	await Grenades.seconds(get_tree(), 0.5)

	assert_bool(Sticky.of(grenade).is_stuck).is_false()
	assert_bool(grenade.freeze).is_false()
	assert_float(grenade.global_position.y).is_less(1.4)


func _spawned() -> RigidBody3D:
	for child in _root.get_children():
		if child is RigidBody3D and Sticky.of(child) != null:
			return child as RigidBody3D
	return null
