extends GdUnitTestSuite
## Unit (ADR 0064): the game menu's texts: the save line (local time and level name) and the
## messages for saves that cannot be loaded.


func test_slot_line_names_the_local_time_and_the_level() -> void:
	var header := {"level": "res://levels/hub/hub.tscn", "saved_at": "2026-11-06T13:32:10"}

	assert_str(GameMenuRules.slot_line(header, 3600)).is_equal("Saved 14:32 · Hub")
	assert_str(GameMenuRules.slot_line(header, 0)).is_equal("Saved 13:32 · Hub")
	assert_str(GameMenuRules.slot_line(header, -5 * 3600)).is_equal("Saved 08:32 · Hub")


func test_local_time_wraps_past_midnight() -> void:
	assert_str(GameMenuRules.local_time("2026-11-06T23:10:00", 2 * 3600)).is_equal("01:10")


func test_an_unreadable_time_is_left_out() -> void:
	var header := {"level": "res://tests/actors/player/fixtures/flat_floor.tscn", "saved_at": "x"}

	assert_str(GameMenuRules.local_time("x", 0)).is_equal("")
	assert_str(GameMenuRules.slot_line(header, 0)).is_equal("Saved · Flat Floor")


func test_level_names() -> void:
	assert_str(GameMenuRules.level_name("res://levels/hub/hub.tscn")).is_equal("Hub")
	assert_str(GameMenuRules.level_name("res://levels/mission/warehouse_mission.tscn")).is_equal("Warehouse Mission")


func test_messages_say_save_not_quicksave() -> void:
	assert_str(GameMenuRules.message(SaveFile.Status.MISSING)).is_equal("No save")
	assert_str(GameMenuRules.message(SaveFile.Status.CORRUPT)).is_equal("Save is damaged")
	assert_str(GameMenuRules.message(SaveFile.Status.WRONG_VERSION)).is_equal("Save is from another version")
	for text: String in GameMenuRules.MESSAGES.values():
		assert_str(text.to_lower()).not_contains("quick")


func test_utc_offset_is_whole_minutes() -> void:
	assert_int(GameMenuRules.system_utc_offset() % 60).is_equal(0)
