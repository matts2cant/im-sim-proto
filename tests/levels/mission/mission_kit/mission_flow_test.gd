extends GdUnitTestSuite
## Integration (ADR 0087): the mission fixture played through. The Mission spawns the player at
## PlayerSpawn with exactly the starting kit, opens the briefing (paused; Esc closes it), completes
## objectives from real events (reading the datapad, picking up the keycard, burning the tagged
## crate) with toasts, refuses the extraction before the main objective and ends the mission in the
## zone after it: the summary (paused, Esc does nothing) shows the tallies and both badges. Restart
## reloads the mission; Return to hub loads the hub with its own player and nothing carried over.

const Missions := preload("res://tests/levels/mission/mission_kit/mission_helpers.gd")
const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const KIT := {"baton": 1, "pistol": 1, "pistol_ammo": 10, "medkit": 1}

var _original: Node


func before_test() -> void:
	_original = get_tree().current_scene
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)


func after_test() -> void:
	Saves.close_level(get_tree(), _original)
	StimulusSystem.clear()


func test_start_gives_the_kit_and_opens_the_briefing() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	var player := Missions.player(level)

	assert_object(player).is_not_null()
	assert_bool(mission.started).is_true()
	var spawn := Missions.at(Vector3(0, 0, 10))
	(
		assert_float(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(spawn.x, spawn.z)))
		. is_less(0.05)
	)
	assert_float(player.rotation.y).is_equal_approx(0.0, 0.001)
	assert_dict(Missions.inventory_counts(level)).is_equal(KIT)
	var pistol := player.inventory.inventory.stacks_of(&"pistol")[0]
	assert_int(int(pistol.state["magazine"])).is_equal(10)
	assert_float(player.energy.current()).is_equal_approx(50.0, 0.01)
	for id: StringName in [&"cloak", &"speed_enhancement", &"combat_strength"]:
		assert_bool(player.augmentations.is_installed(id)).override_failure_message(String(id)).is_true()
	for id: StringName in [&"run_silent", &"regeneration"]:
		assert_bool(player.augmentations.is_installed(id)).override_failure_message(String(id)).is_false()
	assert_array(player.augmentations.active_ids()).is_empty()
	for skill in player.skills.skill_ids():
		assert_int(player.skills.tier(skill)).override_failure_message(String(skill)).is_equal(0)
	# Objectives are in the personal log, without opening the reading overlay.
	var reader_log := PersonalLog.of(player)
	for id: String in ["manifest", "keycard", "shipment"]:
		assert_bool(reader_log.has(StringName("mission.fixture.%s" % id))).override_failure_message(id).is_true()
	assert_bool((player.get_node("ReadingOverlay") as ReadingOverlay).is_open()).is_false()
	# The briefing pauses the game until Esc.
	assert_bool(mission.briefing.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_str(mission.briefing.title_text()).is_equal("Test mission")
	assert_str(mission.briefing.objectives_text()).contains("Objective: Read the test manifest")
	assert_str(mission.briefing.objectives_text()).contains("Optional: Take the keycard")
	var paused_time := mission.time

	await Missions.close_briefing(level)

	assert_bool(mission.briefing.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_float(paused_time).is_equal(0.0)
	assert_int(EventLog.find(&"mission.briefing_closed").size()).is_equal(1)
	await Missions.frames(get_tree(), 30)
	assert_float(mission.time).is_between(0.4, 0.6)


func test_objectives_extraction_and_summary() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	var player := Missions.player(level)
	await Missions.close_briefing(level)
	# Extraction before the main objective: refused, with its hint.
	Missions.place(level, Vector3(0, 0, -12))
	await Missions.frames(get_tree(), 5)
	assert_bool(mission.finished).is_false()
	assert_str(mission.toast.text()).is_equal("Read the test manifest first")
	assert_int(EventLog.find(&"mission.extraction_refused").size()).is_equal(1)
	Missions.place(level, Vector3(0, 0, 4))
	await Missions.frames(get_tree(), 3)

	Missions.read_manifest(level)
	await Missions.frames(get_tree(), 3)
	assert_bool(mission.tracker.is_done(&"manifest")).is_true()
	assert_str(mission.toast.text()).is_equal("Objective complete: Read the test manifest")
	player.inventory.pick_up(ItemPickup.of(level.get_node("Keycard")))
	await Missions.frames(get_tree(), 2)
	assert_bool(mission.tracker.is_done(&"keycard")).is_true()
	assert_str(mission.toast.text()).is_equal("Optional complete: Take the keycard")
	(level.get_node("Shipment/Flammable") as Flammable).ignite(null)
	await Missions.frames(get_tree(), 2)
	assert_bool(mission.tracker.is_done(&"shipment")).is_true()
	assert_int(EventLog.find(&"mission.objective_completed").size()).is_equal(3)
	await Missions.frames(get_tree(), 60)

	Missions.place(level, Vector3(0, 0, -12))
	await Missions.frames(get_tree(), 5)

	assert_bool(mission.finished).is_true()
	assert_bool(mission.summary.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_str(mission.summary.value("Kills")).is_equal("0")
	assert_str(mission.summary.value("Knockouts")).is_equal("0")
	assert_str(mission.summary.value("Alarms raised")).is_equal("0")
	assert_str(mission.summary.value("Optional objectives")).is_equal("2 / 2")
	assert_str(mission.summary.value("Time")).is_equal("0:01")
	assert_array(Array(mission.summary.earned_badges())).is_equal(["Ghost", "Pacifist"])
	var completed := EventLog.find(&"mission.completed")
	assert_int(completed.size()).is_equal(1)
	assert_bool(completed[0].data["ghost"]).is_true()
	# Esc does nothing on the summary (no game menu over it).
	Saves.press(KEY_ESCAPE)
	await get_tree().process_frame
	assert_bool(mission.summary.is_open()).is_true()
	assert_bool((player.get_node("GameMenu") as GameMenu).is_open()).is_false()


func test_restart_reloads_the_mission() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	await Missions.close_briefing(level)
	mission.finish()
	assert_bool(mission.summary.is_open()).is_true()

	mission.summary.restart_button.pressed.emit()
	var restarted := await Missions.wait_for_scene_change(get_tree(), level)
	await Missions.frames(get_tree(), 3)

	assert_object(restarted).is_not_null()
	assert_str(restarted.scene_file_path).is_equal(Missions.FIXTURE)
	var again := Missions.mission(restarted)
	assert_bool(again.finished).is_false()
	assert_bool(again.briefing.is_open()).is_true()
	assert_dict(Missions.inventory_counts(restarted)).is_equal(KIT)


func test_return_to_hub_loads_the_hub_at_its_spawn() -> void:
	var level := await Missions.open(get_tree())
	var mission := Missions.mission(level)
	await Missions.close_briefing(level)
	mission.finish()

	mission.summary.hub_button.pressed.emit()
	var hub := await Missions.wait_for_scene_change(get_tree(), level)
	await Missions.frames(get_tree(), 3)

	assert_object(hub).is_not_null()
	assert_str(hub.scene_file_path).is_equal(Missions.HUB)
	assert_bool(get_tree().paused).is_false()
	var player := hub.get_node("Player") as Player
	assert_float(player.global_position.distance_to(Vector3(0, 0, 10))).is_less(0.1)
	assert_array(player.inventory.inventory.stacks).is_empty()
	assert_int(EventLog.find(&"mission.left").size()).is_equal(1)
