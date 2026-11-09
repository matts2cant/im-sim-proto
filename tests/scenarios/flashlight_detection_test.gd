extends GdUnitTestSuite
## Scenario: flashlights (ADR 0095) feed the existing vision rules through LightExposure. In the
## dark (no lights at all), far from the origin, no navmesh: a guard at the fixture's origin faces
## -Z with its flashlight on while patrolling (it stays Unaware until it sees something).
## - A walking target (a minimal walker, tagged `actor.player`, with a LightExposure) pacing
##   sideways 8 m ahead (centre to centre; x -1..+1) in the beam: Alerted in 2-3 s (target of the
##   brief). It keeps its distance when the guard walks to the point after its look.
## - A downed ally (a guard.tscn lying unconscious across the view, its middle 6 m ahead) is found
##   through the body-discovery rules unchanged: lit by the beam it is found, in the dark it is not
##   (6 m: past the 2 m close override).

const CHARACTERS := preload("res://tests/actors/common/character_fixtures.gd")
const GUARD: PackedScene = preload("res://actors/guard/guard.tscn")
const ORIGIN := Vector3(-300, 0, -300)
const AHEAD := 8.0
const BODY_FEET := Vector3(-0.9, 0, -6)

var _root: Node3D
var _guard: NavWalker
var _awareness: GradedAwareness


func before_test() -> void:
	EventLog.clear()
	StimulusSystem.clear()
	_root = auto_free(Node3D.new())
	add_child(_root)
	_root.global_position = ORIGIN
	CHARACTERS.floor_box(_root)
	_guard = GUARD.instantiate() as NavWalker
	_guard.name = "Watcher"
	_root.add_child(_guard)
	(_guard.get_node("Behaviour") as AwarenessBehaviour).route = null
	_awareness = GradedAwareness.of_node(_guard)


func after_test() -> void:
	StimulusSystem.clear()


func test_a_walking_target_in_the_beam_at_8m_alerts_in_2_to_3s() -> void:
	Flashlight.of(_guard).on_while_patrolling = true
	var target := CHARACTERS.character(_root, "Target", Vector3(0, 0, -AHEAD), [])
	var exposure := LightExposure.new()
	exposure.name = "LightExposure"
	target.add_child(exposure)
	ActorState.set_tag(target, &"actor.player", true)
	ActorState.set_tag(target, ActorState.CLOAKED, true)
	await _frames(12)
	ActorState.set_tag(target, ActorState.CLOAKED, false)

	var walker: Variant = target
	var side := 1.0
	var levels: Array[float] = []
	var alerted := INF
	for tick in 300:
		var offset := target.global_position - _guard.global_position
		if offset.x > 1.0:
			side = -1.0
		elif offset.x < -1.0:
			side = 1.0
		walker.drive = Vector3(side * 4.0, 0, clampf((-AHEAD - offset.z) * 5.0, -3.0, 3.0))
		await get_tree().physics_frame
		levels.append(exposure.level)
		if _awareness.state() == AwarenessModel.State.ALERTED:
			alerted = (tick + 1) / 60.0
			break
	prints(
		(
			"flashlight: walking at %.1f m in the beam, level %.2f..%.2f, Alerted %.2f s"
			% [AHEAD, levels.min(), levels.max(), alerted]
		)
	)
	assert_float(alerted).is_between(2.0, 3.0)


func test_a_body_lit_by_the_beam_is_found() -> void:
	Flashlight.of(_guard).on_while_patrolling = true
	var body := _downed("Downed")
	await _frames(20)
	# Lit by the beam before it is found (the guard then runs over and stands beside it).
	assert_float(LightExposure.of(body).level).is_greater(0.2)
	await _frames(130)
	assert_bool(Flashlight.of(_guard).lit).is_true()
	assert_bool(Flashlight.of(body).lit).is_false()
	var found := EventLog.find(&"actor.body_found")
	assert_array(found).has_size(1)
	assert_str(String(found[0].data["body"])).is_equal("Downed")


func test_a_body_in_the_dark_is_not_found() -> void:
	var body := _downed("Downed")
	await _frames(150)
	assert_bool(Flashlight.of(_guard).lit).is_false()
	assert_array(EventLog.find(&"actor.body_found")).is_empty()
	assert_float(LightExposure.of(body).level).is_less(0.1)


# A guard.tscn lying unconscious along +X from BODY_FEET.
func _downed(body_name: String) -> NavWalker:
	var body := GUARD.instantiate() as NavWalker
	body.name = body_name
	(body.get_node("Tags") as Tags).initial_tags = [&"actor.guard", &"state.unconscious"]
	body.position = BODY_FEET
	body.rotation.y = PI * 0.5
	_root.add_child(body)
	return body


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
