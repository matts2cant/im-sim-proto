extends GdUnitTestSuite
## Integration (ADR 0087): walking through the hub's mission doorway (`MissionExit`, west wall, north
## doorway) loads the warehouse level itself: the Mission spawns the player at the level's
## PlayerSpawn, facing the compound, with the briefing open.

const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const WAREHOUSE := "res://levels/mission/warehouse.tscn"

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Input.action_release(&"move_forward")
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


func test_the_hub_doorway_loads_the_warehouse() -> void:
	var hub := await Saves.open_level(get_tree(), Missions.HUB)
	var exit := hub.get_node("MissionExit") as LevelExit
	assert_str(exit.scene_path).is_equal(WAREHOUSE)
	var player := hub.get_node("Player") as Player
	# 2.5 m east of the doorway, facing west (yaw +90 degrees turns -Z to -X).
	player.load_state({"position": Vector3(-12.5, 0, -7.5), "yaw": PI / 2.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	await Missions.frames(get_tree(), 3)

	Input.action_press(&"move_forward")
	var level := await Missions.wait_for_scene_change(get_tree(), hub, 600)
	Input.action_release(&"move_forward")
	await Missions.frames(get_tree(), 3)

	assert_object(level).is_not_null()
	assert_str(level.scene_file_path).is_equal(WAREHOUSE)
	var spawn := level.get_node("PlayerSpawn") as Node3D
	var feet := Missions.player(level).global_position
	(
		assert_float(Vector2(feet.x, feet.z).distance_to(Vector2(spawn.global_position.x, spawn.global_position.z)))
		. is_less(0.05)
	)
	var mission := Missions.mission(level)
	assert_bool(mission.started).is_true()
	assert_bool(mission.briefing.is_open()).is_true()
	await Missions.close_briefing(level)
	assert_bool(get_tree().paused).is_false()
