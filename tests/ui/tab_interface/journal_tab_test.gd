extends GdUnitTestSuite
## Integration (ADR 0110): the Journal tab of the Tab interface. Objectives of the level's mission
## (an inert Mission with the fixture mission data: title, short briefing line, primary and secondary
## objectives with their state, live when one completes; "no mission" outside one), the codes and
## logins the PersonalLog knows (readable names from the entry's code labels, logins as
## "user / password", a link to the entry), and the notes newest first with the reader. Plus the pure
## JournalRules.

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"
const MISSION_SCENE: PackedScene = preload("res://levels/mission/mission_kit/mission.tscn")
const MISSION_DATA: MissionData = preload("res://tests/levels/mission/mission_kit/fixtures/mission_fixture.tres")

var _driver: PlayerDriver
var _player: Player
var _tabs: TabInterface
var _journal: JournalTab
var _log: PersonalLog


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()


func after_test() -> void:
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_objectives_of_the_mission_with_their_state() -> void:
	await _load()
	var mission := MISSION_SCENE.instantiate() as Mission
	mission.data = MISSION_DATA
	_driver.runner.scene().add_child(mission)
	await _open_journal()

	var box := _section_box("Objectives")
	assert_str((box.get_node("MissionTitle") as Label).text).is_equal(MISSION_DATA.title)
	assert_str((box.get_node("Briefing") as Label).text).is_equal(JournalRules.briefing_line(MISSION_DATA.briefing))
	var rows := _journal.objective_rows()
	(
		assert_array(rows.map(func(row: Dictionary) -> String: return row["id"]))
		. is_equal(["manifest", "keycard", "shipment"])
	)
	assert_array(rows.map(func(row: Dictionary) -> bool: return row["optional"])).is_equal([false, true, true])
	assert_str(_pill(box, "keycard")).is_equal("SECONDARY")
	assert_str(_pill(box, "manifest")).is_equal("PRIMARY")

	# Completing one shows at once (live while open).
	mission.tracker.done.append(&"keycard")
	await _driver.frames(2)
	box = _section_box("Objectives")
	assert_str(_pill(box, "keycard")).is_equal("DONE")
	mission.queue_free()


func test_no_mission_says_so() -> void:
	await _load()
	await _open_journal()

	assert_array(_journal.objective_rows()).is_empty()
	var none := _section_box("Objectives").get_node("NoMission") as Label
	assert_str(none.text).is_equal(JournalRules.NO_MISSION)


func test_codes_and_logins_with_readable_names_link_to_their_note() -> void:
	await _load()
	var labels := {&"office_door": "Manager's office door", &"pc": "Office PC login"}
	_log.add(
		LogEntry.make(
			&"a",
			"Shift notes",
			"Door 4471, PC kbrandt.",
			"Datapad",
			{&"office_door": "4471", &"pc": "kbrandt:ferry19"},
			labels
		)
	)
	_log.add(LogEntry.make(&"b", "Crumpled note", "Side door 2390.", "Datapad", {&"side_door": "2390"}))
	await _open_journal()
	_journal.show_section(JournalTab.Section.CODES)

	var rows := _journal.code_rows()
	(
		assert_array(rows.map(func(row: Dictionary) -> String: return row["label"]))
		. is_equal(["Manager's office door", "Office PC login", "Side Door"])
	)
	(
		assert_array(rows.map(func(row: Dictionary) -> String: return row["value"]))
		. is_equal(["4471", "kbrandt / ferry19", "2390"])
	)
	var link := _section_box("Codes").get_node("Table/From_pc") as LinkButton
	assert_str(link.text).is_equal("Shift notes")

	link.pressed.emit()
	assert_int(_journal.section).is_equal(JournalTab.Section.NOTES)
	assert_str(_journal.shown_note().title).is_equal("Shift notes")


func test_notes_newest_first_with_the_reader() -> void:
	await _load()
	_log.add(LogEntry.make(&"a", "Inventory bay", "Press I.", "Datapad"))
	_log.add(
		LogEntry.make(
			&"b",
			"Storage access",
			"Code 2817.",
			"Datapad",
			{&"storage_door": "2817"},
			{&"storage_door": "Storage door"}
		)
	)
	await _open_journal()
	_journal.show_section(JournalTab.Section.NOTES)

	(
		assert_array(_journal.notes().map(func(entry: LogEntry) -> String: return entry.title))
		. is_equal(["Storage access", "Inventory bay"])
	)
	var reader := _section_box("Reader")
	assert_str((reader.get_node("Title") as Label).text).is_equal("Storage access")
	assert_str((reader.get_node("Source") as Label).text).is_equal("Datapad")
	assert_str((reader.get_node("Learned") as Label).text).is_equal("Learned: Storage door 2817")

	(_section_box("List").get_node("Note_a") as Button).pressed.emit()
	reader = _section_box("Reader")
	assert_str((reader.get_node("Title") as Label).text).is_equal("Inventory bay")
	assert_object(reader.find_child("Learned", true, false)).is_null()

	# A note read while the tab shows appears at once.
	_log.add(LogEntry.make(&"c", "New note", "Fresh.", "Datapad"))
	await _driver.frames(2)
	assert_str(_journal.notes()[0].title).is_equal("New note")
	assert_object(_section_box("List").get_node_or_null("Note_c")).is_not_null()


func test_journal_rules() -> void:
	assert_str(JournalRules.code_value("dmarsh:harbor77")).is_equal("dmarsh / harbor77")
	assert_str(JournalRules.code_value("2817")).is_equal("2817")
	assert_str(JournalRules.briefing_line("Short one.")).is_equal("Short one.")
	var long_text := "A" + "a".repeat(130) + ". Second sentence. Third."
	assert_str(JournalRules.briefing_line(long_text)).is_equal("A" + "a".repeat(130) + ".")
	var two := "First sentence. " + "b".repeat(120) + ". Third."
	assert_str(JournalRules.briefing_line(two)).is_equal("First sentence. " + "b".repeat(120) + ".")
	var entry := LogEntry.make(&"x", "X", "", "", {&"vault_code": "1"})
	assert_str(entry.code_label(&"vault_code")).is_equal("Vault Code")
	# Labels survive a save.
	var labelled := LogEntry.make(&"y", "Y", "", "", {&"k": "1"}, {&"k": "Back door"})
	assert_str(LogEntry.from_dict(labelled.to_dict()).code_label(&"k")).is_equal("Back door")


func _pill(box: Node, objective_id: String) -> String:
	return (box.get_node("Objective_%s" % objective_id).find_child("Text", true, false) as Label).text


# The content box of the body's column `name` (Objectives, Codes, List or Reader).
func _section_box(column: String) -> VBoxContainer:
	return _journal.get_node("Columns/Body/%s/Margin/Box" % column) as VBoxContainer


func _open_journal() -> void:
	await _driver.hold(&"personal_log", 2)
	await _driver.frames(1)
	assert_bool(_tabs.is_open()).is_true()
	assert_object(_tabs.current_page()).is_same(_journal)


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_tabs = TabInterface.of(_player)
	_journal = _tabs.page(4) as JournalTab
	_log = PersonalLog.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
