extends GdUnitTestSuite
## Integration (ADR 0087): the hub's mission doorway (west wall, north doorway) is a LevelExit to
## `levels/mission/warehouse.tscn`. Walking through it loads the mission level (here the mission
## fixture, the exit's path being configurable): the player starts at PlayerSpawn with exactly the
## mission's kit (nothing from the hub comes along) and the briefing open. An exit to a scene that
## does not exist changes nothing.

const Wait := preload("res://tests/helpers/wait.gd")
const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const LOCKPICK: ItemData = preload("res://items/lockpick/lockpick.tres")
const KIT := {"baton": 1, "pistol": 1, "pistol_ammo": 10, "medkit": 1}

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


func test_the_mission_doorway_targets_the_warehouse() -> void:
	var hub := (load(Missions.HUB) as PackedScene).instantiate()
	var exit := hub.get_node("MissionExit") as LevelExit
	var doorway := (hub.get_node("Room") as Room).openings.filter(
		func(opening: RoomOpening) -> bool: return opening.node_name == &"DoorwayMission"
	)
	var exit_position := exit.position
	var scene := exit.scene_path
	hub.free()

	assert_str(scene).is_equal("res://levels/mission/warehouse.tscn")
	# In the west doorway (wall 3, offset -7.5: hub x -15, z -7.5), behind the wall's inner face.
	assert_int(doorway.size()).is_equal(1)
	assert_float(exit_position.z).is_equal_approx(-7.5, 0.01)
	assert_float((doorway[0] as RoomOpening).offset).is_equal_approx(-7.5, 0.01)
	assert_float(exit_position.x).is_between(-16.5, -15.0)


func test_walking_through_the_doorway_loads_the_mission_with_only_its_kit() -> void:
	var hub := await Saves.open_level(get_tree(), Missions.HUB)
	var exit := hub.get_node("MissionExit") as LevelExit
	exit.scene_path = Missions.FIXTURE
	var player := hub.get_node("Player") as Player
	player.inventory.give(LOCKPICK, 2)
	# 2.5 m east of the doorway, facing west (yaw +90 degrees turns -Z to -X).
	player.load_state({"position": Vector3(-12.5, 0, -7.5), "yaw": PI / 2.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	await Wait.frames(get_tree(), 3)
	# The exit fires in a physics callback (body_entered): the hub (its collision objects) must
	# still be in the tree when that callback returns ("Removing a CollisionObject node during a
	# physics callback"); the change happens deferred. Connected after the exit, so it runs after it.
	var in_tree_after_exit: Array[bool] = []
	exit.body_entered.connect(func(_body: Node3D) -> void: in_tree_after_exit.append(hub.is_inside_tree()))

	Input.action_press(&"move_forward")
	var level := await Missions.wait_for_scene_change(get_tree(), hub, 600)
	Input.action_release(&"move_forward")
	assert_array(in_tree_after_exit).is_equal([true])
	await Wait.frames(get_tree(), 3)

	assert_object(level).is_not_null()
	assert_str(level.scene_file_path).is_equal(Missions.FIXTURE)
	var exits := EventLog.find(&"level.exit")
	assert_int(exits.size()).is_equal(1)
	assert_str(str(exits[0].data["scene"])).is_equal(Missions.FIXTURE)
	var mission := Missions.mission(level)
	var spawn := Missions.at(Vector3(0, 0, 10))
	var feet := Missions.player(level).global_position
	assert_float(Vector2(feet.x, feet.z).distance_to(Vector2(spawn.x, spawn.z))).is_less(0.05)
	assert_dict(Missions.inventory_counts(level)).is_equal(KIT)
	assert_bool(mission.briefing.is_open()).is_true()
	await Missions.close_briefing(level)
	assert_bool(mission.briefing.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_an_exit_to_a_missing_scene_changes_nothing() -> void:
	var hub := await Saves.open_level(get_tree(), Missions.HUB)
	var exit := hub.get_node("MissionExit") as LevelExit
	exit.scene_path = "res://levels/does_not_exist.tscn"
	var player := hub.get_node("Player") as Player

	player.load_state({"position": Vector3(-15.5, 0, -7.5), "yaw": PI / 2.0, "pitch": 0.0, "velocity": Vector3.ZERO})
	await Wait.frames(get_tree(), 10)

	assert_object(get_tree().current_scene).is_same(hub)
	assert_int(EventLog.find(&"level.exit_refused").size()).is_greater_equal(1)
	assert_int(EventLog.find(&"level.exit").size()).is_equal(0)
