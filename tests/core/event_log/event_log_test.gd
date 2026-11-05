extends GdUnitTestSuite

const EventLogScript := preload("res://core/event_log/event_log.gd")

var _log: EventLogScript


func before_test() -> void:
	_log = auto_free(EventLogScript.new())


func test_record_stores_fields() -> void:
	var entry := _log.record(&"noise", "player", "guard_1", {"radius": 8.0})

	assert_str(entry.kind).is_equal("noise")
	assert_str(entry.source).is_equal("player")
	assert_str(entry.target).is_equal("guard_1")
	assert_dict(entry.data).is_equal({"radius": 8.0})
	assert_array(_log.entries()).contains_exactly([entry])


func test_record_defaults_target_and_data_to_empty() -> void:
	var entry := _log.record(&"spawned", "crate_1")

	assert_str(entry.target).is_empty()
	assert_dict(entry.data).is_empty()


func test_record_stamps_physics_tick() -> void:
	var first := _log.record(&"a", "test")
	assert_int(first.tick).is_equal(Engine.get_physics_frames())

	await get_tree().physics_frame
	var second := _log.record(&"b", "test")

	assert_int(second.tick).is_greater(first.tick)


func test_to_string_is_one_line() -> void:
	var entry := EventLogEntry.new(42, &"damaged", "pistol", "dummy", {"amount": 10})

	assert_str(str(entry)).is_equal('[42] damaged pistol -> dummy {"amount":10}')


func test_ring_buffer_evicts_oldest_at_capacity() -> void:
	_log.capacity = 3
	for i in 5:
		_log.record(&"step", "s%d" % i)

	var sources: Array[String] = []
	for entry: EventLogEntry in _log.entries():
		sources.append(entry.source)
	assert_array(sources).contains_exactly(["s2", "s3", "s4"])


func test_find_returns_matching_kind_in_order() -> void:
	var first := _log.record(&"noise", "a")
	_log.record(&"spawned", "b")
	var third := _log.record(&"noise", "c")

	assert_array(_log.find(&"noise")).contains_exactly([first, third])
	assert_array(_log.find(&"missing")).is_empty()


func test_clear_removes_all_entries() -> void:
	_log.capacity = 2
	for i in 3:
		_log.record(&"step", "s%d" % i)

	_log.clear()
	var entry := _log.record(&"after", "x")

	assert_array(_log.entries()).contains_exactly([entry])


func test_record_emits_entry_added() -> void:
	monitor_signals(_log)

	var entry := _log.record(&"noise", "player")

	await assert_signal(_log).is_emitted("entry_added", entry)
