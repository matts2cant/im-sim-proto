extends GdUnitTestSuite
## Integration (ADR 0087): 30 s of mission time after the first alarm rings (a real alarm
## controller raised), the mission data's two guards spawn at ReinforcementSpawn (12, 0, 12) and
## search where the alarm was raised; later alarms bring nobody else. The mission clock is moved on
## by hand (25 s: nobody yet; 5.5 s more: they arrive) instead of simulating half a minute. The
## player drops its `actor.player` tag so nobody fights it.

const Wait := preload("res://tests/helpers/wait.gd")
const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const INCIDENT := Vector3(-6, 0, -4)

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


func _controller(level: Node) -> AlarmController:
	for controller in AlarmController.all(get_tree()):
		if level.is_ancestor_of(controller):
			return controller
	return null


func test_two_guards_arrive_once_30_s_after_the_first_alarm() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	await Missions.close_briefing(level)
	ActorState.set_tag(Missions.player(level), &"actor.player", false)
	var controller := _controller(level)
	var arrivals := mission.get_node("Reinforcements")

	controller.raise(Missions.at(INCIDENT), "test", true)
	await Wait.frames(get_tree(), 3)
	assert_float(mission.alarm_time).is_greater_equal(0.0)
	assert_vector(mission.incident_point).is_equal(Missions.at(INCIDENT))
	mission.time += 25.0
	await Wait.frames(get_tree(), 5)
	assert_int(arrivals.get_child_count()).is_equal(0)

	mission.time += 5.5
	await Wait.frames(get_tree(), 3)

	assert_int(arrivals.get_child_count()).is_equal(2)
	var spawn := Missions.at(Vector3(12, 0, 12))
	for guard: Node3D in arrivals.get_children():
		assert_float(guard.global_position.distance_to(spawn)).override_failure_message(guard.name).is_less(1.5)
		var awareness := GradedAwareness.of_node(guard)
		assert_str(awareness.state_name()).override_failure_message(guard.name).is_equal("searching")
		assert_vector(awareness.model.point).is_equal_approx(Missions.at(INCIDENT), Vector3(0.5, 0.5, 0.5))
	# They head for the incident.
	var before := (arrivals.get_child(0) as Node3D).global_position.distance_to(Missions.at(INCIDENT))
	await Wait.frames(get_tree(), 120)
	var after := (arrivals.get_child(0) as Node3D).global_position.distance_to(Missions.at(INCIDENT))
	assert_float(before - after).is_greater(1.0)
	# Once per mission.
	controller.stop("reset")
	controller.raise(Missions.at(Vector3(4, 0, -4)), "test", true)
	mission.time += 40.0
	await Wait.frames(get_tree(), 5)
	assert_int(arrivals.get_child_count()).is_equal(2)
	assert_int(EventLog.find(&"mission.reinforcements").size()).is_equal(1)
	assert_bool(mission.save_state()["reinforcements_sent"]).is_true()
