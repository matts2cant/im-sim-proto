extends GdUnitTestSuite
## Unit: the Readable component (ADR 0060) on minimal entities: any node with a Readable is read
## into the PersonalLog of any user that has one (not only the player and the datapad scene).

var _sign: Node3D
var _readable: Readable
var _reader: Node
var _log: PersonalLog


func before_test() -> void:
	EventLog.clear()
	_sign = auto_free(Node3D.new())
	_sign.name = "WallNote"
	_readable = Readable.new()
	_readable.entry_id = &"test.wall_note"
	_readable.title = "Wall note"
	_readable.text = "The vent code is 42."
	_readable.codes = {&"vent": "42"}
	_sign.add_child(_readable)
	add_child(_sign)
	_reader = auto_free(Node.new())
	_reader.name = "Guard"
	_log = PersonalLog.new()
	_reader.add_child(_log)
	add_child(_reader)


func test_reads_into_any_users_personal_log() -> void:
	assert_object(Usable.of(_sign)).is_same(_readable)
	assert_str(_readable.verb).is_equal("read")
	assert_str(_readable.target_name()).is_equal("Wall note")

	assert_bool(_readable.use(_reader)).is_true()

	assert_int(_log.entries().size()).is_equal(1)
	var entry := _log.entries()[0]
	assert_str(String(entry.id)).is_equal("test.wall_note")
	assert_str(entry.text).is_equal("The vent code is 42.")
	# No `source` set: the owner's node name in words.
	assert_str(entry.source).is_equal("Wall Note")
	assert_str(_log.known_code(&"vent")).is_equal("42")
	var logged := EventLog.find(&"log.entry_added")
	assert_array(logged).has_size(1)
	assert_str(logged[0].source).is_equal("Guard")
	assert_str(logged[0].target).is_equal("WallNote")


func test_reading_twice_adds_one_entry() -> void:
	_readable.use(_reader)
	_readable.use(_reader)

	assert_int(_log.entries().size()).is_equal(1)
	assert_array(EventLog.find(&"log.entry_added")).has_size(1)


func test_source_override_and_used_signal() -> void:
	_readable.source = "Terminal"
	var users: Array[Node] = []
	_readable.used.connect(func(user: Node) -> void: users.append(user))

	_readable.use(_reader)

	assert_str(_log.entries()[0].source).is_equal("Terminal")
	assert_array(users).contains_exactly([_reader])


func test_a_user_without_a_personal_log_cannot_read() -> void:
	var stranger: Node = auto_free(Node.new())

	assert_bool(_readable.use(stranger)).is_false()
	assert_array(EventLog.find(&"log.entry_added")).is_empty()


func test_entry_does_not_share_the_readables_codes() -> void:
	var entry := _readable.entry()
	entry.codes[&"vent"] = "0"

	assert_str(_readable.codes[&"vent"]).is_equal("42")
