extends GdUnitTestSuite
## Unit: the PersonalLog component (ADR 0060) on a bare actor node: read() shows every read and adds
## a new entry once (signal + EventLog `log.entry_added`), the code query M8 keypads use, and the
## saveable round trip.

var _actor: Node
var _log: PersonalLog
var _read: Array[LogEntry] = []
var _added: Array[LogEntry] = []


func before_test() -> void:
	EventLog.clear()
	_read.clear()
	_added.clear()
	_actor = auto_free(Node.new())
	_actor.name = "Reader"
	_log = PersonalLog.new()
	_actor.add_child(_log)
	add_child(_actor)
	_log.entry_read.connect(func(entry: LogEntry) -> void: _read.append(entry))
	_log.entry_added.connect(func(entry: LogEntry) -> void: _added.append(entry))


func test_is_saveable_and_found_on_its_owner() -> void:
	assert_bool(_log.is_in_group(LevelSnapshot.GROUP)).is_true()
	assert_object(PersonalLog.of(_actor)).is_same(_log)
	assert_object(PersonalLog.of(auto_free(Node.new()))).is_null()
	assert_object(PersonalLog.of(null)).is_null()


func test_read_adds_once_and_shows_every_time() -> void:
	var entry := LogEntry.make(&"memo", "Memo", "Hello", "Datapad")

	assert_bool(_log.read(entry, "Datapad")).is_true()
	assert_bool(_log.read(LogEntry.make(&"memo", "Memo", "Hello", "Datapad"), "Datapad")).is_false()

	assert_int(_read.size()).is_equal(2)
	assert_int(_added.size()).is_equal(1)
	assert_int(_log.entries().size()).is_equal(1)
	assert_bool(_log.has(&"memo")).is_true()
	var logged := EventLog.find(&"log.entry_added")
	assert_array(logged).has_size(1)
	assert_str(logged[0].source).is_equal("Reader")
	assert_str(logged[0].target).is_equal("Datapad")
	assert_str(logged[0].data["entry_id"]).is_equal("memo")
	assert_str(logged[0].data["title"]).is_equal("Memo")


func test_codes_become_known_with_their_source() -> void:
	assert_str(_log.known_code(&"storage_door")).is_equal("")

	_log.read(LogEntry.make(&"a", "Storage access", "2817", "Datapad", {&"storage_door": "2817"}))

	assert_str(_log.known_code(&"storage_door")).is_equal("2817")
	assert_str(_log.code_source(&"storage_door")).is_equal("Storage access")
	assert_str(_log.code_source(&"office_door")).is_equal("")
	assert_array(Array(_log.known_code_ids())).contains_exactly([&"storage_door"])
	assert_array(Array(EventLog.find(&"log.entry_added")[0].data["codes"])).contains_exactly(["storage_door"])


func test_save_and_load_round_trip() -> void:
	_log.read(LogEntry.make(&"a", "Note", "First", "Datapad"))
	_log.read(LogEntry.make(&"b", "Storage access", "2817", "Datapad", {&"storage_door": "2817"}))
	var saved := _log.save_state()

	var other: PersonalLog = auto_free(PersonalLog.new())
	other.load_state(saved)

	assert_int(other.entries().size()).is_equal(2)
	assert_str(other.entries()[0].title).is_equal("Storage access")
	assert_str(other.entries()[1].text).is_equal("First")
	assert_str(other.known_code(&"storage_door")).is_equal("2817")
	# Loaded entries count as read: reading again adds nothing.
	assert_bool(other.read(LogEntry.make(&"a", "Note", "First"))).is_false()


func test_load_replaces_the_current_entries() -> void:
	_log.read(LogEntry.make(&"a", "Note", ""))

	_log.load_state({"entries": []})

	assert_array(_log.entries()).is_empty()
	assert_bool(_log.read(LogEntry.make(&"a", "Note", ""))).is_true()
