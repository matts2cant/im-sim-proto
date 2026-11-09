extends GdUnitTestSuite
## Integration: a guard's path crosses a downed character (ADR 0082) in the guard fixture. A minimal
## dead character (character_fixtures, no ally tag, so no body discovery) lies along +X from its feet
## at (-0.9, 0, -3), across the straight path from the guard's post (origin) to (0, 0, -5.5); the
## lying capsule is 0.71 m high, above the guard's 0.35 m step. The guard (controlled by the test)
## walks there at 1.5 m/s: 5.5 m in about 3.7 s. Standing, the same character blocks it.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const WALKER: NavWalkerConfig = preload("res://actors/guard/guard_walker.tres")
const BODY_FEET := Vector3(-0.9, 0, -3)
const TARGET := Vector3(0, 0, -5.5)

var _g: Guards


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()


func test_a_guard_walks_across_a_dead_character_on_its_path() -> void:
	await _setup()
	var body := _body(BODY_FEET, true)
	await _g.frames(5)
	assert_int(body.collision_layer).is_equal(PhysicsLayers.DOWNED)
	_g.guard.take_control(self)
	_g.guard.move_to(TARGET, WALKER.walk_speed)
	await _g.seconds(5.0)
	assert_float(VisionRules.flat_distance(_g.guard.global_position, TARGET)).is_less(0.6)
	assert_float(body.global_position.distance_to(BODY_FEET)).is_less(0.05)


func test_a_standing_character_on_its_path_blocks_the_guard() -> void:
	await _setup()
	# Feet on the path: standing, its capsule fills it.
	_body(Vector3(0, 0, -3), false)
	await _g.frames(5)
	_g.guard.take_control(self)
	_g.guard.move_to(TARGET, WALKER.walk_speed)
	await _g.seconds(5.0)
	assert_float(_g.guard.global_position.z).is_greater(-2.6)


func _setup() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	if _g != null:
		_g.teardown()
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST), false)


## A minimal character with a guard's layers at `feet`, facing -X (lying along +X when dead).
func _body(feet: Vector3, dead: bool) -> CharacterBody3D:
	var no_components: Array[StringName] = []
	var body := Characters.character(_g.scene, "Stranger", feet, no_components, PhysicsLayers.ACTORS)
	body.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ACTORS | PhysicsLayers.OBJECTS
	body.rotation.y = PI * 0.5
	var pose := DownedPose.new()
	pose.name = "DownedPose"
	body.add_child(pose)
	ActorState.set_tag(body, ActorState.DEAD, dead)
	return body
