extends GdUnitTestSuite
## Integration: NavWalker and AwarenessBehaviour on the guard in the guard fixture: patrol route in
## order with waits, holding a post with glances, speeds per pace and the sprint stance tag, pushing
## a small crate with bounded force (BodyPusher, ADR 0054).

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const CrateWatch := preload("res://tests/objects/crate_watch.gd")
const WALKER: NavWalkerConfig = preload("res://actors/guard/guard_walker.tres")
const AWARENESS: AwarenessConfig = preload("res://actors/guard/guard_awareness.tres")

var _g: Guards


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()


func test_patrols_the_route_in_order_and_loops() -> void:
	await _setup(true)
	var route := _g.behaviour.route
	var order: Array[int] = []
	# A (2 m away, wait 2 s), B (6.4 m), C (10 m), back to A (6.4 m): about 18 s at 1.8 m/s.
	for tick in 60 * 24:
		await _g.frames(1)
		for index in route.size():
			var near := VisionRules.flat_distance(_g.guard.global_position, route.point(index)) < 0.6
			if near and (order.is_empty() or order.back() != index):
				order.append(index)
		if order.size() >= 4:
			break
	assert_array(order).is_equal([0, 1, 2, 0])


func test_waits_at_a_patrol_point_for_its_wait_metadata() -> void:
	await _setup(true)
	var a := _g.behaviour.route.point(0)
	for tick in 60 * 3:
		await _g.frames(1)
		if VisionRules.flat_distance(_g.guard.global_position, a) < 0.45:
			break
	await _g.seconds(1.0)
	# Point A waits 2 s: still there a second later, standing still.
	assert_float(VisionRules.flat_distance(_g.guard.global_position, a)).is_less(0.6)
	assert_float(_g.guard.horizontal_speed()).is_less(0.1)
	await _g.seconds(2.0)
	assert_float(VisionRules.flat_distance(_g.guard.global_position, a)).is_greater(1.0)


func test_walks_at_patrol_speed_without_the_sprint_tag() -> void:
	await _setup(true)
	# Halfway along the first leg (2 m to point A).
	await _g.seconds(0.6)
	assert_float(_g.guard.horizontal_speed()).is_equal_approx(WALKER.walk_speed, 0.1)
	assert_bool(ActorState.has(_g.guard, ActorState.SPRINTING)).is_false()


func test_runs_when_alerted_with_the_sprint_tag() -> void:
	await _setup(false)
	_g.awareness.alert_at(Vector3(0, 0, 9))
	await _g.seconds(1.0)

	assert_float(_g.guard.horizontal_speed()).is_equal_approx(WALKER.run_speed, 0.2)
	assert_bool(ActorState.has(_g.guard, ActorState.SPRINTING)).is_true()
	await _g.seconds(2.0)
	# Arrived at the last known position (9 m at 5 m/s) and stands there.
	assert_float(VisionRules.flat_distance(_g.guard.global_position, Vector3(0, 0, 9))).is_less(0.6)
	assert_bool(ActorState.has(_g.guard, ActorState.SPRINTING)).is_false()


func test_alerted_guard_stops_and_faces_a_seen_target_at_arms_length() -> void:
	await _setup(false)
	# A stand-in hostile (no body: a 1.8 m figure on its origin), lit, 6 m ahead, off to the side.
	var target := _g.tagged("Intruder", Vector3(1.5, 0, -6), [&"actor.player"])
	await _g.seconds(3.5)

	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.ALERTED)
	var distance := VisionRules.flat_distance(_g.guard.global_position, target.global_position)
	assert_float(distance).is_between(AWARENESS.face_distance - 0.3, AWARENESS.face_distance + 0.3)
	assert_float(_g.guard.horizontal_speed()).is_less(0.1)
	var to_target := (target.global_position - _g.guard.global_position).normalized()
	assert_float(_g.guard.facing().dot(Vector3(to_target.x, 0, to_target.z).normalized())).is_greater(0.98)


func test_holds_its_post_and_glances_left_and_right() -> void:
	await _setup(false)
	var interval := AWARENESS.glance_interval
	var hold := AWARENESS.glance_hold
	# Middle of the first stretch facing ahead, then the middle of the first glance.
	await _g.seconds((interval - hold) * 0.5)
	assert_float(_g.guard.rotation.y).is_equal_approx(0.0, 0.02)
	await _g.seconds((interval - hold) * 0.5 + hold * 0.5)
	var first := _g.guard.rotation.y
	assert_float(absf(first)).is_equal_approx(deg_to_rad(AWARENESS.glance_angle), 0.05)
	await _g.seconds(interval)
	# The next glance looks the other way.
	assert_float(_g.guard.rotation.y).is_equal_approx(-first, 0.05)
	assert_float(VisionRules.flat_distance(_g.guard.global_position, Vector3.ZERO)).is_less(0.1)


func test_pushes_a_small_crate_with_bounded_force() -> void:
	await _setup(false)
	var watch := CrateWatch.new()
	var crate := watch.small(_g.scene, 0.0, 0.3, 3.0)
	await _g.frames(10)
	assert_int(crate.collision_mask & PhysicsLayers.ACTORS).is_equal(0)
	var start := crate.global_position
	_g.awareness.alert_at(Vector3(0, 0, 7))
	var peak := 0.0
	for tick in 120:
		await _g.frames(1)
		peak = maxf(peak, Vector2(crate.linear_velocity.x, crate.linear_velocity.z).length())

	assert_float(crate.global_position.distance_to(start)).is_greater(0.3)
	# Running at 5 m/s, the guard still pushes at most at push_max_speed (2 m/s).
	assert_float(peak).is_less(2.3)


func _setup(patrol: bool) -> void:
	EventLog.clear()
	StimulusSystem.clear()
	if _g != null:
		_g.teardown()
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST), patrol)
