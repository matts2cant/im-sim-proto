extends GdUnitTestSuite
## Integration: MovementNoise on a minimal CharacterBody3D (tests/actors/common/fixtures/walker.gd)
## that knows nothing about noise: footsteps per stance tag and surface, landings.

const Wait := preload("res://tests/helpers/wait.gd")
const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")
const NOISE: MovementNoiseConfig = preload("res://actors/player/player_movement_noise.tres")
const SHOT_FX: ShotFxConfig = preload("res://items/weapons/fx/shot_fx.tres")
const METAL_CRATE: PackedScene = preload("res://objects/metal_crate/metal_crate.tscn")
const WOOD: float = 1.2
const METAL: float = 1.6
## 75 ticks at 4 m/s = 5 m: 2 walk strides (2 m), 4 crouch strides (1.2 m), 1 sprint stride (2.6 m),
## each at least 0.2 m (3 ticks) away from the next step.
const WALK_TICKS: int = 75
const SPEED: float = 4.0

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root, 0.0, &"wood")


func test_footsteps_every_stride_with_surface_loudness() -> void:
	var walker := await _standing_walker()

	await _walk(walker, WALK_TICKS)

	var steps := EventLog.find(&"actor.footstep")
	assert_array(steps).has_size(2)
	for step in steps:
		assert_str(step.source).is_equal("Walker")
		assert_str(step.data["mode"]).is_equal("walk")
		assert_str(step.data["surface"]).is_equal("wood")
		assert_float(step.data["loudness"]).is_equal_approx(NOISE.walk_loudness * WOOD, 0.0001)


func test_crouch_tag_makes_quieter_shorter_steps() -> void:
	var walker := await _standing_walker()
	Characters.tags_of(walker).add(ActorState.CROUCHING)

	await _walk(walker, WALK_TICKS)

	var steps := EventLog.find(&"actor.footstep")
	assert_array(steps).has_size(4)
	assert_str(steps[0].data["mode"]).is_equal("crouch")
	assert_float(steps[0].data["loudness"]).is_equal_approx(NOISE.crouch_loudness * WOOD, 0.0001)


func test_sprint_tag_makes_louder_steps() -> void:
	var walker := await _standing_walker()
	Characters.tags_of(walker).add(ActorState.SPRINTING)

	await _walk(walker, WALK_TICKS)

	var steps := EventLog.find(&"actor.footstep")
	assert_array(steps).has_size(1)
	assert_str(steps[0].data["mode"]).is_equal("sprint")
	assert_float(steps[0].data["loudness"]).is_equal_approx(NOISE.sprint_loudness * WOOD, 0.0001)


func test_footstep_is_a_noise_stimulus_from_the_feet() -> void:
	var walker := await _standing_walker()
	var listener := Fixtures.entity(_root, "Listener", Vector3(-5, 1.6, 0), [Fixtures.receptron(&"noise")])

	await _walk(walker, 40)
	await Wait.frames(get_tree(), 2)

	var step := EventLog.find(&"actor.footstep")[0]
	var noise := EventLog.find(&"stimulus.emitted")[0]
	assert_str(noise.source).is_equal("Walker")
	assert_float(noise.data["intensity"]).is_equal_approx(step.data["loudness"], 0.0001)
	var origin: Vector3 = noise.data["origin"]
	assert_float(origin.y).is_equal_approx(0.0, 0.05)
	var heard := Fixtures.entries(&"stimulus.received", noise.data["id"])
	assert_array(heard).has_size(1)
	assert_str(heard[0].target).is_equal(listener.name)


func test_landing_noise_scales_with_the_impact() -> void:
	# 3 m at 1 g lands at about 7.7 m/s.
	var walker := Characters.character(_root, "Walker", Vector3(0, 3, 0), [Characters.MOVEMENT_NOISE])

	await Wait.frames(get_tree(), 60)

	var landings := EventLog.find(&"actor.landed")
	assert_array(landings).has_size(1)
	var impact: float = landings[0].data["impact_speed"]
	assert_float(impact).is_equal_approx(sqrt(2.0 * 9.8 * 3.0), 0.3)
	var expected := NOISE.landing_loudness * clampf(impact / NOISE.landing_reference_speed, 1.0, 4.0) * WOOD
	assert_float(landings[0].data["loudness"]).is_equal_approx(expected, 0.0001)
	assert_float((walker.get_node("MovementNoise") as MovementNoise).last_landing_loudness).is_equal(expected)
	assert_array(EventLog.find(&"actor.footstep")).is_empty()


func test_a_metal_tagged_crate_sounds_and_sparks_as_metal() -> void:
	# Five shipped metal crates (0.8 m, `material.metal`, no surface metadata), frozen side by side
	# from x = -10 to -6 on the wood floor; the walker starts on the second (x = -8.8, 0.85 m up)
	# and walks 2.7 m (40 ticks at 4 m/s), staying 0.5 m from the far end.
	var crates: Array[RigidBody3D] = []
	for i in 5:
		var crate := METAL_CRATE.instantiate() as RigidBody3D
		crate.freeze = true
		crate.position = Vector3(-9.6 + 0.8 * i, 0.4, 0)
		_root.add_child(crate)
		crates.append(crate)
	var walker := Characters.character(_root, "Walker", Vector3(-8.8, 0.85, 0), [Characters.MOVEMENT_NOISE])
	await Wait.frames(get_tree(), 10)
	EventLog.clear()

	await _walk(walker, 40)

	var steps := EventLog.find(&"actor.footstep")
	assert_array(steps).is_not_empty()
	for step in steps:
		assert_str(step.data["surface"]).is_equal("metal")
		assert_float(step.data["loudness"]).is_equal_approx(NOISE.walk_loudness * METAL, 0.0001)
	assert_str(String(SHOT_FX.group_for(crates[0], Vector3.BACK))).is_equal("metal")


func _standing_walker() -> CharacterBody3D:
	var walker := Characters.character(_root, "Walker", Vector3(-8, 0.05, 0), [Characters.MOVEMENT_NOISE])
	await Wait.frames(get_tree(), 10)
	EventLog.clear()
	return walker


func _walk(walker: CharacterBody3D, ticks: int) -> void:
	walker.set(&"drive", Vector3(SPEED, 0, 0))
	await Wait.frames(get_tree(), ticks)
	walker.set(&"drive", Vector3.ZERO)
