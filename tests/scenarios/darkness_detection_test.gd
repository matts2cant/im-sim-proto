extends GdUnitTestSuite
## Scenario: the moving floor of the light factor (ADR 0095) measured end to end. A guard at the
## fixture's origin faces -Z in darkness (no lights: the target's light level is the 0.04 ambient);
## a minimal walker character (tests/actors/common/character_fixtures.gd, not the player: the floor
## reads any body's velocity) tagged `actor.player` with a real LightExposure stands 4.5 m ahead
## (centre to centre; 4.5 m keeps clear of the 5 m distance breakpoint) in the focus cone and paces
## sideways between x -1 and +1 (at most 12.5 degrees off the facing), backing off to stay 4.5 m
## ahead when the guard walks to the point after its look. Built far from the origin, no navmesh (it walks
## straight). Tuning targets of the brief: walking Suspicious 1.5-2.5 s and Alerted 4-7 s;
## crouch-walking 2-4 s and 7-11 s; standing still never Suspicious in 10 s.

const Wait := preload("res://tests/helpers/wait.gd")
const CHARACTERS := preload("res://tests/actors/common/character_fixtures.gd")
const GUARD := "res://actors/guard/guard.tscn"
const ORIGIN := Vector3(-300, 0, 300)
const AHEAD := 4.5
const PACE_HALF_WIDTH := 1.0
const WALK_SPEED := 4.0
const CROUCH_SPEED := 2.0

var _root: Node3D
var _guard: NavWalker
var _awareness: GradedAwareness
var _target: CharacterBody3D


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_root.global_position = ORIGIN
	CHARACTERS.floor_box(_root)
	_guard = load(GUARD).instantiate() as NavWalker
	_root.add_child(_guard)
	(_guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	_awareness = GradedAwareness.of_node(_guard)
	_target = CHARACTERS.character(_root, "Target", Vector3(0, 0, -AHEAD), [])
	var exposure := LightExposure.new()
	exposure.name = "LightExposure"
	_target.add_child(exposure)
	ActorState.set_tag(_target, &"actor.player", true)
	# Hidden until it has landed and its light level has settled: the meter starts at 0 with the clock.
	ActorState.set_tag(_target, ActorState.CLOAKED, true)
	await Wait.frames(get_tree(), 12)


func after_test() -> void:
	StimulusSystem.clear()


func test_walking_in_the_dark_is_noticed_then_alerts() -> void:
	var times := await _pace(WALK_SPEED, 10.0)
	prints("darkness: walking at %.1f m Suspicious %.2f s Alerted %.2f s" % [AHEAD, times.x, times.y])
	assert_float(LightExposure.of(_target).level).is_less(0.1)
	assert_float(times.x).is_between(1.5, 2.5)
	assert_float(times.y).is_between(4.0, 7.0)


func test_crouch_walking_in_the_dark_is_noticed_later() -> void:
	ActorState.set_tag(_target, ActorState.CROUCHING, true)
	var times := await _pace(CROUCH_SPEED, 13.0)
	prints("darkness: crouch-walking at %.1f m Suspicious %.2f s Alerted %.2f s" % [AHEAD, times.x, times.y])
	assert_float(times.x).is_between(2.0, 4.0)
	assert_float(times.y).is_between(7.0, 11.0)


func test_standing_still_in_the_dark_is_never_noticed() -> void:
	var times := await _pace(0.0, 10.0)
	assert_float(times.x).is_equal(INF)
	assert_int(_awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_awareness.model.meter).is_equal(0.0)


# Uncloaks the target and paces it sideways at `speed` (relative to the guard) for at most `seconds`,
# keeping it AHEAD m in front of the guard: when the guard walks to the point after its look, the
# target backs off (a ruling of this test: the brief's targets are times at a held distance, not
# with the guard closing in to the 2 m close override). Returns the seconds until the guard was
# Suspicious (x) and Alerted (y), INF when it never was.
func _pace(speed: float, seconds: float) -> Vector2:
	var walker: Variant = _target
	var side := 1.0
	ActorState.set_tag(_target, ActorState.CLOAKED, false)
	var suspicious := INF
	var alerted := INF
	var ticks := roundi(seconds * 60.0)
	for tick in ticks:
		var offset := _target.global_position - _guard.global_position
		if offset.x > PACE_HALF_WIDTH:
			side = -1.0
		elif offset.x < -PACE_HALF_WIDTH:
			side = 1.0
		var back_off := clampf((-AHEAD - offset.z) * 5.0, -3.0, 3.0) if speed > 0.0 else 0.0
		walker.drive = Vector3(side * speed, 0, back_off)
		await get_tree().physics_frame
		var state := _awareness.state()
		var now := (tick + 1) / 60.0
		if suspicious == INF and state != AwarenessModel.State.UNAWARE:
			suspicious = now
		if state == AwarenessModel.State.ALERTED:
			alerted = now
			break
	return Vector2(suspicious, alerted)
