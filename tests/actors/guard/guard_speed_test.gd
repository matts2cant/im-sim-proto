extends GdUnitTestSuite
## Measured guard speeds (ADR 0102): in the guard fixture, on flat navmesh, a patrolling guard
## covers PATROL_SPEED and a running (alerted) guard RUN_SPEED, each within TOLERANCE, timed over a
## straight stretch of at least 5 m (centre-to-centre distance along the leg) away from where it
## starts and stops. The targets are the design's measured outcomes, not the walker's tuning.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
## Patrol pace and run pace (m/s), design/game/perception-and-ai.md.
const PATROL_SPEED := 1.5
const RUN_SPEED := 4.0
const TOLERANCE := 0.05
const TICK := 1.0 / 60.0

var _g: Guards


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()


func test_patrols_at_one_and_a_half_metres_per_second() -> void:
	await _setup(true)
	# Leg B (5, 0, 6) -> C (-5, 0, 6), 10 m along -X: timed from x 3 to x -3 (6 m), 2 m clear of
	# either point. Reaching it: A (2 m), wait 2 s, B (6.4 m), wait 1 s; about 12 s at 1.5 m/s.
	var behaviour := _g.behaviour
	var speed := await _timed_stretch(
		# On the B -> C leg only (heading for point 2, not waiting at B): before it, x 0..5 too.
		func(p: Vector3) -> float:
			return -p.x if behaviour.patrol_index == 2 and behaviour.patrol_wait <= 0.0 else -INF,
		-3.0,
		3.0,
		30.0
	)
	print("Guard patrol speed: %.3f m/s" % speed)
	assert_float(speed).is_between(PATROL_SPEED * (1.0 - TOLERANCE), PATROL_SPEED * (1.0 + TOLERANCE))
	assert_bool(ActorState.has(_g.guard, ActorState.SPRINTING)).is_false()


func test_runs_at_four_metres_per_second() -> void:
	await _setup(false)
	# From its post at the origin to (0, 0, 9) along +Z: timed from z 2 to z 7 (5 m), clear of the
	# acceleration (0.6 m) and of the stop (0.4 m short of the point, then 0.6 m of braking).
	_g.awareness.alert_at(Vector3(0, 0, 9))
	var sprinting := [false]
	var speed := await _timed_stretch(
		func(p: Vector3) -> float:
			if p.z > 2.0 and ActorState.has(_g.guard, ActorState.SPRINTING):
				sprinting[0] = true
			return p.z,
		2.0,
		7.0,
		5.0
	)
	print("Guard run speed: %.3f m/s" % speed)
	assert_float(speed).is_between(RUN_SPEED * (1.0 - TOLERANCE), RUN_SPEED * (1.0 + TOLERANCE))
	# Running is the sprint stance (the louder footsteps).
	assert_bool(sprinting[0]).is_true()


# Seconds between `along(position)` passing `from` and passing `to` (from < to), as a speed over the
# stretch (m/s); 0 when the guard does not cover it within `limit` seconds of game time.
func _timed_stretch(along: Callable, from: float, to: float, limit: float) -> float:
	var start := -1.0
	for frame in roundi(limit / TICK):
		await _g.frames(1)
		var value: float = along.call(_g.guard.global_position)
		if start < 0.0 and value >= from:
			start = frame * TICK
		if start >= 0.0 and value >= to:
			return (to - from) / (frame * TICK - start)
	return 0.0


func _setup(patrol: bool) -> void:
	EventLog.clear()
	StimulusSystem.clear()
	if _g != null:
		_g.teardown()
	_g = Guards.new()
	await _g.setup(scene_runner(Guards.POST), patrol)
