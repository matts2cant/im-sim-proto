extends GdUnitTestSuite
## Integration: StepClimber on the minimal test walker (fixtures/walker.gd, which only sets a velocity
## and calls move_and_slide()): steps up low obstacles at crouch, walk and sprint speeds, is blocked
## by higher ones, keeps the floor down stairs (no landing, no fall), still falls off real ledges,
## needs headroom for its current shape, steps onto physics props, and is off while mantling.
## Obstacle faces at z = -2; walkers start with a 0.3 m gap (surface to surface) to the face, i.e.
## feet at z = -2 + 0.35 + 0.3 = -1.35, and walk toward -Z. Lanes are 3 m apart in X.

const Characters := preload("res://tests/actors/common/character_fixtures.gd")
const Course := preload("res://tests/actors/common/step_course.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

const FACE_Z := -2.0
const START_Z := -1.35
const SPEEDS: Array[float] = [2.0, 4.0, 6.0]
const LOW_STEPS: Array[float] = [0.15, 0.2, 0.3]
const LANE: float = 3.0
## 0.5 s at 60 ticks/s.
const HALF_SECOND: int = 30
const CLIMBER_ONLY: Array[StringName] = [Characters.STEP_CLIMBER]
const WITH_NOISE: Array[StringName] = [Characters.STEP_CLIMBER, Characters.MOVEMENT_NOISE, Characters.FALL_IMPACT]

var _root: Node3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	Characters.floor_box(_root)


func test_walks_up_low_steps_at_any_speed_within_half_a_second() -> void:
	var walkers: Array[CharacterBody3D] = []
	var lane := 0
	for top in LOW_STEPS:
		for speed in SPEEDS:
			var x := (lane - 4) * LANE
			Course.block(_root, top, FACE_Z, 3.0, x)
			walkers.append(_walker("Walker%d" % lane, Vector3(x, 0, START_Z), CLIMBER_ONLY))
			lane += 1
	await Fixtures.frames(get_tree(), 3)
	lane = 0
	for top in LOW_STEPS:
		for speed in SPEEDS:
			walkers[lane].set(&"drive", Vector3(0, 0, -speed))
			lane += 1

	await Fixtures.frames(get_tree(), HALF_SECOND)

	lane = 0
	for top in LOW_STEPS:
		for speed in SPEEDS:
			var walker := walkers[lane]
			var label := "%.2f m step at %.0f m/s: feet at %s" % [top, speed, walker.global_position]
			assert_float(walker.global_position.y).override_failure_message(label).is_equal_approx(top, 0.02)
			assert_float(walker.global_position.z).override_failure_message(label).is_less(FACE_Z - 0.1)
			assert_bool(walker.is_on_floor()).override_failure_message(label).is_true()
			lane += 1


func test_keeps_its_speed_over_a_step() -> void:
	Course.block(_root, 0.3, FACE_Z, 6.0)
	var walker := _walker("Walker", Vector3(0, 0, START_Z), CLIMBER_ONLY)
	await Fixtures.frames(get_tree(), 3)
	walker.set(&"drive", Vector3(0, 0, -4.0))

	await Fixtures.frames(get_tree(), HALF_SECOND)

	# 0.5 s at 4 m/s is 2 m on a flat floor; the step may cost a tick or two, not more.
	assert_float(START_Z - walker.global_position.z).is_greater(1.85)
	assert_float(walker.velocity.z).is_equal_approx(-4.0, 0.01)


func test_higher_block_stops_the_walker_on_the_floor() -> void:
	var walkers: Array[CharacterBody3D] = []
	for i in SPEEDS.size():
		var x := (i - 1) * LANE
		Course.block(_root, 0.45, FACE_Z, 3.0, x)
		walkers.append(_walker("Walker%d" % i, Vector3(x, 0, START_Z), CLIMBER_ONLY))
	await Fixtures.frames(get_tree(), 3)
	for i in SPEEDS.size():
		walkers[i].set(&"drive", Vector3(0, 0, -SPEEDS[i]))

	await Fixtures.frames(get_tree(), HALF_SECOND * 2)

	for walker in walkers:
		assert_float(walker.global_position.y).is_less(0.02)
		assert_float(walker.global_position.z).is_greater(FACE_Z + 0.3)
		assert_bool(walker.is_on_floor()).is_true()


func test_walks_up_and_down_stairs_without_leaving_the_floor() -> void:
	var walkers: Array[CharacterBody3D] = []
	var top := 0.0
	for i in SPEEDS.size():
		var x := (i - 1) * LANE
		top = Course.stair(_root, FACE_Z, x)
		walkers.append(_walker("Walker%d" % i, Vector3(x, 0, START_Z), WITH_NOISE))
	await Fixtures.frames(get_tree(), 3)
	EventLog.clear()

	# Up the 1.5 m of stair onto the landing (its face at z = -3.5, 3 m deep): stop 0.5 m onto it.
	var landing_z := Course.landing_face(FACE_Z) - 0.5
	var up := await _walk_until(
		walkers, _signed(-1.0), func(w: CharacterBody3D) -> bool: return w.position.z < landing_z
	)
	for walker in walkers:
		assert_float(walker.global_position.y).is_equal_approx(top, 0.02)
	# Down to the floor, 0.6 m past the first riser.
	var down := await _walk_until(
		walkers, _signed(1.0), func(w: CharacterBody3D) -> bool: return w.position.z > FACE_Z + 0.6
	)

	for i in walkers.size():
		var label := "%.0f m/s: up %d, down %d ticks airborne" % [SPEEDS[i], up[i], down[i]]
		assert_float(walkers[i].global_position.y).override_failure_message(label).is_less(0.02)
		assert_int(up[i]).override_failure_message(label).is_less_equal(2)
		assert_int(down[i]).override_failure_message(label).is_less_equal(2)
	assert_array(EventLog.find(&"actor.landed")).is_empty()
	assert_array(_falls()).is_empty()
	# Footsteps keep coming on the stair (a landing would restart the stride).
	assert_array(EventLog.find(&"actor.footstep")).is_not_empty()


func test_still_falls_off_ledges_above_the_step_height() -> void:
	var heights: Array[float] = [0.45, 1.2]
	var walkers: Array[CharacterBody3D] = []
	for i in heights.size():
		var x := (i * 2 - 1) * LANE
		# The walker stands 0.65 m (centre to face) back on the ledge and walks off its face toward +Z.
		Course.block(_root, heights[i], FACE_Z, 3.0, x)
		walkers.append(_walker("Walker%d" % i, Vector3(x, heights[i], FACE_Z - 1.0), WITH_NOISE))
	await Fixtures.frames(get_tree(), 10)
	EventLog.clear()

	var airborne := await _walk_until(
		walkers, [4.0, 4.0] as Array[float], func(w: CharacterBody3D) -> bool: return w.position.z > 2.0
	)

	for i in walkers.size():
		assert_int(airborne[i]).is_greater_equal(4)
		assert_float(walkers[i].global_position.y).is_less(0.02)
	# 1.2 m at 1 g lands at about 4.6 m/s: a landing noise and a fall report.
	var landed := EventLog.find(&"actor.landed").filter(
		func(entry: EventLogEntry) -> bool: return entry.source == "Walker1"
	)
	assert_array(landed).has_size(1)
	assert_array(_falls()).is_not_empty()


func test_steps_down_a_low_ledge_and_reports_both_steps() -> void:
	Course.block(_root, 0.3, FACE_Z, 1.5)
	var walker := _walker("Walker", Vector3(0, 0, START_Z), WITH_NOISE)
	var climber := StepClimber.of(walker)
	var rises: Array[float] = []
	climber.stepped.connect(func(rise: float) -> void: rises.append(rise))
	await Fixtures.frames(get_tree(), 3)
	EventLog.clear()

	var walkers: Array[CharacterBody3D] = [walker]
	var airborne := (await _walk_until(
		walkers, [-4.0] as Array[float], func(w: CharacterBody3D) -> bool: return w.position.z < -5.0
	))[0]

	assert_float(walker.global_position.z).is_less(FACE_Z - 1.5 - 0.5)
	assert_float(walker.global_position.y).is_less(0.02)
	assert_int(airborne).is_less_equal(2)
	assert_array(EventLog.find(&"actor.landed")).is_empty()
	assert_bool(rises.any(func(rise: float) -> bool: return rise > 0.0 and rise <= 0.35)).is_true()
	assert_bool(rises.any(func(rise: float) -> bool: return rise < 0.0 and rise >= -0.35)).is_true()


func test_needs_headroom_for_its_current_shape() -> void:
	# Standing (1.8 m) under 1.4 m of headroom above a 0.3 m step: no step. A crouch-sized walker
	# (0.95 m) under 1.1 m of headroom: steps (0.15 m to spare).
	Course.block(_root, 0.3, FACE_Z, 3.0, -LANE)
	Course.slab(_root, 0.3 + 1.4, 3.0, FACE_Z, 3.0, -LANE)
	Course.block(_root, 0.3, FACE_Z, 3.0, LANE)
	Course.slab(_root, 0.3 + 1.1, 3.0, FACE_Z, 3.0, LANE)
	var standing := _walker("Standing", Vector3(-LANE, 0, START_Z), CLIMBER_ONLY)
	var crouched := _walker("Crouched", Vector3(LANE, 0, START_Z), CLIMBER_ONLY)
	_set_height(crouched, 0.95)
	await Fixtures.frames(get_tree(), 3)
	standing.set(&"drive", Vector3(0, 0, -2.0))
	crouched.set(&"drive", Vector3(0, 0, -2.0))

	await Fixtures.frames(get_tree(), HALF_SECOND * 2)

	assert_float(standing.global_position.y).is_less(0.02)
	assert_float(standing.global_position.z).is_greater(FACE_Z + 0.2)
	assert_float(crouched.global_position.y).is_equal_approx(0.3, 0.02)
	assert_float(crouched.global_position.z).is_less(FACE_Z - 0.5)


func test_steps_onto_a_physics_prop_that_passes_through_it() -> void:
	# A body on the player's layer: props do not collide with it in the solver (ADR 0054), so it can
	# stand on them. A 0.2 m slab of debris.
	var prop := _prop(Vector3(0, 0.1, FACE_Z - 0.6))
	var walker := Characters.character(_root, "Walker", Vector3(0, 0, START_Z), CLIMBER_ONLY, PhysicsLayers.PLAYER)
	await Fixtures.frames(get_tree(), 10)
	walker.set(&"drive", Vector3(0, 0, -2.0))

	await Fixtures.frames(get_tree(), HALF_SECOND)

	assert_float(walker.global_position.y).is_equal_approx(0.2, 0.03)
	assert_bool(walker.is_on_floor()).is_true()
	assert_float(prop.global_position.y).is_equal_approx(0.1, 0.02)


func test_does_not_step_onto_a_prop_the_solver_pushes_it_against() -> void:
	# A prop whose mask has the walker's layer (actors) collides with it in the solver: stepping onto
	# it would fling it. (Shipped props never scan the character layers, ADR 0054.)
	var prop := _prop(Vector3(0, 0.1, FACE_Z - 0.6), PhysicsLayers.OBJECT_MASK | PhysicsLayers.ACTORS)
	var walker := _walker("Walker", Vector3(0, 0, START_Z), CLIMBER_ONLY)
	await Fixtures.frames(get_tree(), 10)
	walker.set(&"drive", Vector3(0, 0, -2.0))

	await Fixtures.frames(get_tree(), HALF_SECOND)

	assert_float(walker.global_position.y).is_less(0.02)
	assert_float(prop.global_position.y).is_equal_approx(0.1, 0.02)


func test_mantling_tag_turns_it_off() -> void:
	Course.block(_root, 0.2, FACE_Z)
	var walker := _walker("Walker", Vector3(0, 0, START_Z), CLIMBER_ONLY)
	ActorState.set_tag(walker, ActorState.MANTLING, true)
	await Fixtures.frames(get_tree(), 3)
	walker.set(&"drive", Vector3(0, 0, -4.0))

	await Fixtures.frames(get_tree(), HALF_SECOND)

	assert_float(walker.global_position.y).is_less(0.02)


func test_puts_itself_first_among_the_components() -> void:
	var walker := _walker("Walker", Vector3.ZERO, WITH_NOISE)
	await Fixtures.frames(get_tree(), 1)

	assert_int(StepClimber.of(walker).get_index()).is_equal(0)


func _walker(walker_name: String, feet: Vector3, components: Array[StringName]) -> CharacterBody3D:
	return Characters.character(_root, walker_name, feet, components)


# A 200 kg, 0.2 m high slab of debris (1.6 x 1.2 m) on the objects layer.
func _prop(centre: Vector3, mask: int = PhysicsLayers.OBJECT_MASK) -> RigidBody3D:
	var prop := RigidBody3D.new()
	prop.collision_layer = PhysicsLayers.OBJECTS
	prop.collision_mask = mask
	prop.mass = 200.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.2, 1.2)
	shape.shape = box
	prop.add_child(shape)
	prop.position = centre
	_root.add_child(prop)
	return prop


func _set_height(walker: CharacterBody3D, height: float) -> void:
	var collision := walker.get_node("Collision") as CollisionShape3D
	(collision.shape as CapsuleShape3D).height = height
	collision.position.y = height * 0.5


# Drives each walker along Z at its `velocities` entry (m/s) until `arrived` holds for it (then
# stops it), at most 3 s. Returns each walker's longest run of ticks off the floor.
func _walk_until(walkers: Array[CharacterBody3D], velocities: Array[float], arrived: Callable) -> Array[int]:
	var longest: Array[int] = []
	var runs: Array[int] = []
	for walker in walkers:
		walker.set(&"drive", Vector3.ZERO)
		longest.append(0)
		runs.append(0)
	for tick in 180:
		var moving := false
		for i in walkers.size():
			var walker := walkers[i]
			var done: bool = arrived.call(walker)
			walker.set(&"drive", Vector3.ZERO if done else Vector3(0, 0, velocities[i]))
			moving = moving or not done
			runs[i] = 0 if walker.is_on_floor() else runs[i] + 1
			longest[i] = maxi(longest[i], runs[i])
		if not moving:
			break
		await get_tree().physics_frame
	return longest


# SPEEDS toward `direction` (+1 / -1 along Z).
func _signed(direction: float) -> Array[float]:
	var velocities: Array[float] = []
	for speed in SPEEDS:
		velocities.append(speed * direction)
	return velocities


func _falls() -> Array[EventLogEntry]:
	return EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data["type"] == &"damage.fall"
	)
