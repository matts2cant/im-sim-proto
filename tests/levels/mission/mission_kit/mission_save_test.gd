extends GdUnitTestSuite
## Integration (ADR 0087): the one quicksave slot records the level it was made in. Saved in the
## mission, loaded from the hub: the mission level comes back with its state (time, objectives done,
## tallies, first alarm), the player as saved, no briefing and the game running. The Mission node's
## state round-trips on its own.

const Wait := preload("res://tests/helpers/wait.gd")
const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	Saves.use_test_slot()
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


func test_quicksave_in_the_mission_loads_back_from_the_hub() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	await Missions.close_briefing(level)
	Missions.read_manifest(level)
	_controller(level).raise(Missions.at(Vector3(-6, 0, -4)), "test", true)
	await Wait.frames(get_tree(), 3)
	mission.time += 100.0
	Missions.place(level, Vector3(1, 0, 2))
	await Wait.frames(get_tree(), 3)
	var saved_time := mission.time
	assert_bool(mission.tracker.is_done(&"manifest")).is_true()
	assert_int(mission.tally.alarms).is_equal(1)

	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	assert_str(str(SaveFile.read(QuickSave.path).data["level"])).is_equal(Missions.FIXTURE)
	LevelReset.load_level(get_tree(), Missions.HUB)
	var hub := await Missions.wait_for_scene_change(get_tree(), level)
	assert_str(hub.scene_file_path).is_equal(Missions.HUB)

	QuickSave.load_game(get_tree())
	var loaded := await Saves.wait_for_load(get_tree(), hub, 240)

	assert_object(loaded).is_not_null()
	assert_str(loaded.scene_file_path).is_equal(Missions.FIXTURE)
	var again := Missions.mission(loaded)
	assert_bool(again.started).is_true()
	assert_bool(again.tracker.is_done(&"manifest")).is_true()
	# Saved time, plus the frame or two played since the load ended.
	assert_float(again.time).is_between(saved_time, saved_time + 0.1)
	assert_int(again.tally.alarms).is_equal(1)
	assert_float(again.alarm_time).is_greater_equal(0.0)
	assert_bool(again.briefing.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	var feet := Missions.player(loaded).global_position
	assert_float(feet.distance_to(Missions.at(Vector3(1, 0, 2)))).is_less(0.1)
	assert_int(Missions.inventory_counts(loaded).get("pistol", 0)).is_equal(1)
	assert_bool(PersonalLog.of(Missions.player(loaded)).has(&"fixture.manifest")).is_true()
	# The saved stimulus ids are reserved: a new stimulus never reuses one.
	assert_int(StimulusSystem.last_id()).is_greater_equal(int(SaveFile.read(QuickSave.path).data["stimulus_ids"]))


func test_mission_state_round_trips() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	await Missions.close_briefing(level)
	Missions.read_manifest(level)
	await Wait.frames(get_tree(), 3)
	mission.time = 42.0
	mission.alarm_time = 12.0
	mission.incident_point = Vector3(1, 2, 3)
	mission.reinforcements_sent = true
	mission.tally.kills = 2
	var saved := mission.save_state()
	var other := (load("res://levels/mission/mission_kit/mission.tscn") as PackedScene).instantiate() as Mission
	other.data = mission.data
	add_child(other)

	other.load_state(saved)

	assert_str(Saves.difference(saved, other.save_state())).is_empty()
	assert_bool(other.tracker.is_done(&"manifest")).is_true()
	assert_int(other.tally.kills).is_equal(2)
	assert_bool(other.tally.pacifist()).is_false()
	other.free()
