extends GdUnitTestSuite
## Unit: LogBook and LogEntry (ADR 0060): adding entries once per id, newest first, known codes
## merged across entries (the last entry added wins a shared code id), dict round trips.

var _book: LogBook


func before_test() -> void:
	_book = LogBook.new()


func test_add_keeps_entries_in_reading_order() -> void:
	assert_bool(_book.add(LogEntry.make(&"a", "First", "one"))).is_true()
	assert_bool(_book.add(LogEntry.make(&"b", "Second", "two"))).is_true()

	assert_int(_book.entries.size()).is_equal(2)
	assert_str(_book.entries[0].title).is_equal("First")
	assert_str(_book.newest_first()[0].title).is_equal("Second")
	assert_str(_book.newest_first()[1].title).is_equal("First")
	# newest_first() is a copy.
	assert_str(_book.entries[0].title).is_equal("First")
	assert_bool(_book.has(&"a")).is_true()
	assert_str(_book.find(&"b").text).is_equal("two")
	assert_object(_book.find(&"c")).is_null()


func test_same_entry_id_is_added_once() -> void:
	_book.add(LogEntry.make(&"memo", "Memo", "text"))

	assert_bool(_book.add(LogEntry.make(&"memo", "Memo (copy)", "other", "", {&"door": "1111"}))).is_false()

	assert_int(_book.entries.size()).is_equal(1)
	assert_str(_book.entries[0].title).is_equal("Memo")
	# The refused copy's code is not learned.
	assert_str(_book.known_code(&"door")).is_equal("")


func test_entry_without_id_is_refused() -> void:
	assert_bool(_book.add(LogEntry.make(&"", "Nameless", "text"))).is_false()
	assert_bool(_book.add(null)).is_false()
	assert_array(_book.entries).is_empty()


func test_codes_merge_across_entries() -> void:
	_book.add(LogEntry.make(&"a", "Storage access", "", "Datapad", {&"storage_door": "2817"}))
	_book.add(LogEntry.make(&"b", "Office memo", "", "Datapad", {&"office_door": "0451", &"safe": "9"}))

	assert_str(_book.known_code(&"storage_door")).is_equal("2817")
	assert_str(_book.known_code(&"office_door")).is_equal("0451")
	assert_str(_book.code_entry(&"storage_door").title).is_equal("Storage access")
	assert_str(_book.code_entry(&"safe").title).is_equal("Office memo")
	assert_array(Array(_book.known_code_ids())).contains_exactly([&"storage_door", &"office_door", &"safe"])
	assert_str(_book.known_code(&"vault")).is_equal("")
	assert_object(_book.code_entry(&"vault")).is_null()


func test_a_later_entry_overrides_a_shared_code() -> void:
	_book.add(LogEntry.make(&"old", "Old memo", "", "", {&"storage_door": "1111"}))
	_book.add(LogEntry.make(&"new", "Code changed", "", "", {&"storage_door": "2817"}))

	assert_str(_book.known_code(&"storage_door")).is_equal("2817")
	assert_str(_book.code_entry(&"storage_door").title).is_equal("Code changed")
	assert_int(_book.known_code_ids().size()).is_equal(1)


func test_dict_round_trip_keeps_entries_and_codes() -> void:
	_book.add(LogEntry.make(&"a", "Note", "Line one\nLine two", "Datapad"))
	_book.add(LogEntry.make(&"b", "Storage access", "Code 2817", "Terminal", {&"storage_door": "2817"}))

	var copy := LogBook.new()
	copy.from_dict(_book.to_dict())

	assert_int(copy.entries.size()).is_equal(2)
	assert_str(String(copy.entries[0].id)).is_equal("a")
	assert_str(copy.entries[0].text).is_equal("Line one\nLine two")
	assert_str(copy.entries[1].source).is_equal("Terminal")
	assert_str(copy.known_code(&"storage_door")).is_equal("2817")
	assert_str(copy.code_entry(&"storage_door").title).is_equal("Storage access")


func test_from_dict_replaces_what_was_there() -> void:
	_book.add(LogEntry.make(&"a", "Note", ""))
	var other := LogBook.new()
	other.add(LogEntry.make(&"z", "Other", "", "", {&"door": "5"}))

	_book.from_dict(other.to_dict())

	assert_bool(_book.has(&"a")).is_false()
	assert_bool(_book.has(&"z")).is_true()
	assert_str(_book.known_code(&"door")).is_equal("5")


func test_entry_dict_uses_plain_strings() -> void:
	var data := LogEntry.make(&"a", "Note", "x", "Datapad", {&"door": "12"}).to_dict()

	var expected := {"entry_id": "a", "title": "Note", "text": "x", "source": "Datapad"}
	expected["codes"] = {"door": "12"}
	expected["code_labels"] = {}
	assert_dict(data).is_equal(expected)
	var entry := LogEntry.from_dict(data)
	assert_str(entry.codes[&"door"]).is_equal("12")
