extends GdUnitTestSuite
## Scenario: the player and a guard in the guard fixture (tests/scenarios/fixtures/guard_post.tscn,
## guard at the origin facing -Z holding its post; a wall at x 1..7, z -6; a closet at x -10..-5,
## z -10..-7 whose only opening, a 1 m crawl hole, is covered by a large crate). Asserted on the
## EventLog: sight raises suspicion then the alert, a sprint behind the guard is heard and
## investigated, a dropped crate's impact is investigated, a target that hides is searched for and
## forgotten (wary), a cloaked player walking past in plain view goes unnoticed.

const Guards := preload("res://tests/actors/guard/guard_helpers.gd")
const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const Objects := preload("res://tests/objects/object_test_helpers.gd")
## Inside the closet: nothing sees or reaches it.
const HIDE_SPOT := Vector3(-7.5, 0, -8.8)
const FACING_LEFT := PI * 0.5
const FACING_RIGHT := -PI * 0.5

var _g: Guards
var _driver: PlayerDriver


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	var runner := scene_runner(Guards.POST_WITH_PLAYER)
	_driver = PlayerDriver.new(runner)
	_g = Guards.new()
	await _g.setup(runner)
	await _driver.place(HIDE_SPOT)


func after_test() -> void:
	_g.teardown()
	StimulusSystem.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_player_walking_into_view_lit_is_suspected_then_alerts() -> void:
	# From behind the wall (hidden), walking -X along z = -9: in view from x ~1.4, 9 m away.
	await _driver.place(Vector3(4, 0, -9), FACING_LEFT)
	_driver.runner.simulate_action_press(&"move_forward")
	await _g.seconds(2.5)
	_driver.runner.simulate_action_release(&"move_forward")

	assert_array(Guards.states()).is_equal(["suspicious", "alerted"])
	for entry in Guards.guard_entries(&"actor.awareness"):
		assert_str(entry.data["reason"]).is_equal("sight")
	assert_array(EventLog.find(&"actor.bark")).has_size(2)
	assert_bool(_g.awareness.is_aware()).is_true()


func test_sprint_behind_the_guard_is_heard_and_it_walks_to_the_noise() -> void:
	# Sprinting +X along z = 6 behind the guard: the first footstep (14 loud) is about 6 m away.
	await _driver.place(Vector3(-4, 0, 6), FACING_RIGHT)
	_driver.runner.simulate_action_press(&"sprint")
	_driver.runner.simulate_action_press(&"move_forward")
	for tick in 120:
		await _g.frames(1)
		if not Guards.guard_entries(&"actor.heard").is_empty():
			break
	_driver.runner.simulate_action_release(&"move_forward")
	_driver.runner.simulate_action_release(&"sprint")
	# Gone before the guard turns round.
	_driver.player.load_state(PlayerDriver.state(HIDE_SPOT, 0.0))

	var heard := Guards.guard_entries(&"actor.heard")
	assert_array(heard).is_not_empty()
	assert_str(heard[0].source).is_equal("Player")
	assert_float(heard[0].data["perceived"]).is_between(5.0, 9.5)
	assert_array(Guards.states()).is_equal(["suspicious"])
	var point: Vector3 = _g.awareness.model.point
	await _g.seconds(2.2)
	assert_int(_g.awareness.model.phase).is_equal(AwarenessModel.Phase.MOVE)
	await _wait_for_phase(AwarenessModel.Phase.LOOK_AROUND, 8.0)
	assert_float(VisionRules.flat_distance(_g.guard.global_position, point)).is_less(1.0)
	assert_array(Guards.states()).is_equal(["suspicious"])


func test_crate_impact_near_the_guard_is_investigated() -> void:
	# A small crate dropped 1.2 m about 4.2 m away: impact noise about 12, heard with about 8 to spare.
	var crate := Objects.spawn(_g.scene, Objects.SMALL_CRATE, Vector3(3, 1.5, -3)) as RigidBody3D
	for tick in 90:
		await _g.frames(1)
		if not Guards.guard_entries(&"actor.heard").is_empty():
			break

	var heard := Guards.guard_entries(&"actor.heard")
	assert_array(heard).is_not_empty()
	assert_str(heard[0].source).is_equal(String(crate.name))
	assert_array(Guards.states()).is_equal(["suspicious"])
	assert_str(Guards.guard_entries(&"actor.awareness")[0].data["reason"]).is_equal("noise")
	var point: Vector3 = _g.awareness.model.point
	await _wait_for_phase(AwarenessModel.Phase.LOOK_AROUND, 10.0)
	assert_float(VisionRules.flat_distance(_g.guard.global_position, point)).is_less(1.5)


func test_target_hiding_is_lost_searched_for_then_forgotten_wary() -> void:
	# Seen lit in focus 5.6 m away, then slips behind the crate into the closet.
	await _driver.place(Vector3(-2.5, 0, -5))
	for tick in 120:
		await _g.frames(1)
		if _g.awareness.state() == AwarenessModel.State.ALERTED:
			break
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.ALERTED)
	_driver.player.load_state(PlayerDriver.state(HIDE_SPOT, 0.0))

	await _g.seconds(4.5)
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.SEARCHING)
	await _g.seconds(31.0)

	assert_array(Guards.states()).is_equal(["suspicious", "alerted", "searching", "unaware"])
	assert_str(Guards.guard_entries(&"actor.awareness").back().data["reason"]).is_equal("search_over")
	assert_bool(_g.awareness.model.is_wary()).is_true()


func test_cloaked_player_walking_past_in_focus_goes_unnoticed() -> void:
	# Walking +X along z = -8, lit, in the focus cone for about 1.3 s (8-9 m: footsteps unheard).
	await _driver.place(Vector3(-4, 0, -8), FACING_RIGHT)
	ActorState.set_tag(_driver.player, ActorState.CLOAKED, true)
	_driver.runner.simulate_action_press(&"move_forward")
	await _g.seconds(2.0)
	_driver.runner.simulate_action_release(&"move_forward")
	await _g.seconds(1.0)

	assert_array(Guards.guard_entries(&"actor.awareness")).is_empty()
	assert_array(Guards.guard_entries(&"actor.heard")).is_empty()
	assert_int(_g.awareness.state()).is_equal(AwarenessModel.State.UNAWARE)
	assert_float(_g.awareness.model.meter).is_equal(0.0)


func _wait_for_phase(phase: AwarenessModel.Phase, limit: float) -> void:
	for tick in roundi(limit * 60.0):
		if _g.awareness.model.phase == phase:
			return
		await _g.frames(1)
