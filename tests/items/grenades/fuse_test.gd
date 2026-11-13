extends GdUnitTestSuite
## Integration (ADR 0131): Fuse on a minimal entity (the test grenade: a plain RigidBody3D with an
## Explosive): it sets the Explosive off its time after being lit, a body with a lit fuse collides
## with characters, and anything that damages the entity to 0 sets it off too (the one detonation
## entry, Explosive.explode()).

const Wait := preload("res://tests/helpers/wait.gd")
const Grenades := preload("res://tests/items/grenades/grenade_helpers.gd")

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new()) as Node3D
	add_child(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_fuse_explodes_after_its_time_and_not_before() -> void:
	var grenade := Grenades.grenade(_root, Vector3(600, 5, 0), true)
	var explosive := Explosive.of(grenade)
	await Wait.frames(get_tree(), 1)

	Fuse.of(grenade).light()
	await Grenades.seconds(get_tree(), 2.3)
	assert_bool(explosive.has_exploded).is_false()
	await Grenades.seconds(get_tree(), 0.4)

	# Exploded and gone.
	assert_bool(is_instance_valid(grenade)).is_false()
	assert_array(Grenades.logged(&"object.exploded", "TestGrenade")).has_size(1)


func test_a_lit_body_collides_with_characters() -> void:
	var grenade := Grenades.grenade(_root, Vector3(602, 5, 0), true)
	await Wait.frames(get_tree(), 1)
	assert_int(grenade.collision_mask & PhysicsLayers.CHARACTER_LAYERS).is_equal(0)

	Fuse.of(grenade).light()

	assert_int(grenade.collision_mask & PhysicsLayers.CHARACTER_LAYERS).is_equal(PhysicsLayers.CHARACTER_LAYERS)


func test_lighting_again_keeps_the_shorter_time() -> void:
	var grenade := Grenades.grenade(_root, Vector3(604, 5, 0), true)
	await Wait.frames(get_tree(), 1)
	var fuse := Fuse.of(grenade)

	fuse.light()
	fuse.light(0.5)
	fuse.light()

	assert_float(fuse.left).is_equal_approx(0.5, 0.0001)


func test_damage_to_zero_sets_it_off_without_a_fuse() -> void:
	var grenade := Grenades.grenade(_root, Vector3(606, 5, 0), true)
	await Wait.frames(get_tree(), 1)

	Breakable.of(grenade).take_damage(&"damage.ballistic", 10.0)

	assert_bool(Explosive.of(grenade).has_exploded).is_true()
