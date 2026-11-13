extends GdUnitTestSuite
## Integration: DownedPose's collision on minimal characters (character_fixtures, no guard): while
## `state.dead` or `state.unconscious` the body leaves the character layers for DOWNED and stops
## scanning them (ADR 0082), so another character walks across it; it stays on the floor and a
## blast still reaches it; standing up restores the layers, and it blocks again.
## The body lies along +X from its feet at (-0.9, 0, 0) (yaw 90 degrees: it falls onto world +X),
## across the walker's path along -Z at x = 0; the lying capsule is 0.71 m high, above any step.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const BODY_FEET := Vector3(-0.9, 0, 0)
const STANDING_MASK := PhysicsLayers.WORLD | PhysicsLayers.PLAYER | PhysicsLayers.ACTORS | PhysicsLayers.OBJECTS
## The walker's speed (m/s) and start, 2 m (centre to centre) in front of the body's middle.
const WALK_SPEED: float = 2.0
const WALKER_START := Vector3(0, 0, 2)

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func after_test() -> void:
	StimulusSystem.clear()


func test_downed_layer_and_mask_drop_the_character_layers() -> void:
	assert_int(DownedPose.downed_layer(PhysicsLayers.ACTORS)).is_equal(PhysicsLayers.DOWNED)
	assert_int(DownedPose.downed_layer(PhysicsLayers.PLAYER)).is_equal(PhysicsLayers.DOWNED)
	var mask := DownedPose.downed_mask(STANDING_MASK | PhysicsLayers.DOWNED)
	assert_int(mask).is_equal(PhysicsLayers.WORLD | PhysicsLayers.OBJECTS)


func test_a_dead_character_leaves_the_character_layers_and_stays_on_the_floor() -> void:
	var body := _body("Fallen", BODY_FEET, ActorState.DEAD)
	await Wait.frames(get_tree(), 3)
	assert_int(body.collision_layer).is_equal(PhysicsLayers.DOWNED)
	assert_int(body.collision_mask).is_equal(PhysicsLayers.WORLD | PhysicsLayers.OBJECTS)
	await Wait.frames(get_tree(), 60)
	assert_float(body.global_position.y).is_equal_approx(0.0, 0.05)
	assert_bool((body.get_node("DownedPose") as DownedPose).is_down).is_true()


func test_standing_up_restores_the_character_layers() -> void:
	var body := _body("Sleeper", BODY_FEET, ActorState.UNCONSCIOUS)
	await Wait.frames(get_tree(), 3)
	assert_int(body.collision_layer).is_equal(PhysicsLayers.DOWNED)
	ActorState.set_tag(body, ActorState.UNCONSCIOUS, false)
	await Wait.frames(get_tree(), 3)
	assert_int(body.collision_layer).is_equal(PhysicsLayers.ACTORS)
	assert_int(body.collision_mask).is_equal(STANDING_MASK)


func test_a_walker_crosses_a_dead_character() -> void:
	_body("Fallen", BODY_FEET, ActorState.DEAD)
	await Wait.frames(get_tree(), 3)
	var walker := _walker()
	await Wait.frames(get_tree(), 120)
	# 2 m/s for 2 s from z = 2: about z = -2, well past the body (z = 0, 0.35 m deep each side).
	assert_float(walker.global_position.z).is_less(-1.5)
	assert_float(walker.global_position.y).is_equal_approx(0.0, 0.05)


func test_a_walker_crosses_an_unconscious_character() -> void:
	_body("Sleeper", BODY_FEET, ActorState.UNCONSCIOUS)
	await Wait.frames(get_tree(), 3)
	var walker := _walker()
	await Wait.frames(get_tree(), 120)
	assert_float(walker.global_position.z).is_less(-1.5)


func test_a_character_that_stood_up_blocks_the_walker_again() -> void:
	# Feet on the walker's line: standing, its capsule is in the way (stopped near z = 0.7, the two
	# 0.35 m radii centre to centre).
	var body := _body("Sleeper", Vector3.ZERO, ActorState.UNCONSCIOUS)
	await Wait.frames(get_tree(), 3)
	ActorState.set_tag(body, ActorState.UNCONSCIOUS, false)
	await Wait.frames(get_tree(), 3)
	var walker := _walker()
	await Wait.frames(get_tree(), 120)
	assert_float(walker.global_position.z).is_greater(0.5)


func test_a_blast_still_reaches_a_downed_character() -> void:
	var body := _body("Fallen", BODY_FEET, ActorState.DEAD, [Characters.KNOCKBACK_COMPONENT])
	await Wait.frames(get_tree(), 3)
	EventLog.clear()
	StimulusSystem.emit(Stimulus.make_radius(&"force.blast", 120.0, Vector3(-3, 0.45, 0), 4.0))
	await Wait.frames(get_tree(), 60)
	var pushes := EventLog.find(&"actor.knocked_back")
	assert_array(pushes).has_size(1)
	assert_str(pushes[0].target).is_equal("Fallen")
	assert_float(body.global_position.x).is_greater(BODY_FEET.x + 0.1)
	assert_float(body.global_position.y).is_equal_approx(0.0, 0.05)


## A minimal character standing with a guard's layers (actors; it scans the player and actors),
## lying along +X from `feet` with `tag`.
func _body(body_name: String, feet: Vector3, tag: StringName, components: Array[StringName] = []) -> CharacterBody3D:
	var body := Characters.character(_root, body_name, feet, components, PhysicsLayers.ACTORS)
	body.collision_mask = STANDING_MASK
	body.rotation.y = PI * 0.5
	var pose := DownedPose.new()
	pose.name = "DownedPose"
	body.add_child(pose)
	ActorState.set_tag(body, tag, true)
	return body


## A standing walker (actors layer, scanning actors like a guard) driven along -Z at WALK_SPEED.
func _walker() -> CharacterBody3D:
	var no_components: Array[StringName] = []
	var walker := Characters.character(_root, "Walker", WALKER_START, no_components, PhysicsLayers.ACTORS)
	walker.collision_mask = STANDING_MASK
	walker.set("drive", Vector3(0, 0, -WALK_SPEED))
	return walker
