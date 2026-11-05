extends GdUnitTestSuite

# Uses the real DebugPanel and EventLog autoloads: this checks the wiring (input map, autoload, built-in tabs).


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()


func after_test() -> void:
	DebugPanel.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_hidden_by_default() -> void:
	var panel: CanvasLayer = auto_free(load("res://ui/debug_panel/debug_panel.tscn").instantiate())

	assert_bool(panel.visible).is_false()


func test_toggle_key_opens_and_closes() -> void:
	_press_toggle_key()
	assert_bool(DebugPanel.is_open()).is_true()
	assert_bool(DebugPanel.visible).is_true()

	_press_toggle_key()
	assert_bool(DebugPanel.is_open()).is_false()
	assert_bool(DebugPanel.visible).is_false()


func test_restores_mouse_mode_on_close(
	_do_skip := DisplayServer.get_name() == "headless", _skip_reason := "headless display server has no mouse modes"
) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	DebugPanel.set_open(true)
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)

	DebugPanel.set_open(false)
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_CAPTURED)


func test_register_tab_adds_tab() -> void:
	var tabs := _tabs()
	var content: Control = auto_free(Label.new())

	DebugPanel.register_tab("Probe", content)

	assert_int(tabs.get_tab_idx_from_control(content)).is_equal(tabs.get_tab_count() - 1)
	assert_str(tabs.get_tab_title(tabs.get_tab_count() - 1)).is_equal("Probe")


func test_event_log_tab_shows_new_entries_newest_first() -> void:
	var list: ItemList = _event_log_tab().get_node("Entries")

	EventLog.record(&"noise", "player")
	var newest := EventLog.record(&"spawned", "crate_1")

	assert_int(list.item_count).is_equal(2)
	assert_str(list.get_item_text(0)).is_equal(str(newest))


func test_event_log_tab_filters_by_kind() -> void:
	var tab := _event_log_tab()
	var filter: LineEdit = tab.get_node("Filter")
	var list: ItemList = tab.get_node("Entries")
	var noise := EventLog.record(&"noise", "player")
	EventLog.record(&"spawned", "crate_1")

	filter.text = "noi"
	filter.text_changed.emit(filter.text)
	EventLog.record(&"spawned", "crate_2")

	assert_int(list.item_count).is_equal(1)
	assert_str(list.get_item_text(0)).is_equal(str(noise))

	filter.text = ""
	filter.text_changed.emit(filter.text)
	assert_int(list.item_count).is_equal(3)


func _press_toggle_key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_QUOTELEFT
	event.pressed = true
	get_tree().root.push_input(event)


func _tabs() -> TabContainer:
	return DebugPanel.get_node("TabContainer")


func _event_log_tab() -> Control:
	var tabs := _tabs()
	for i in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Event Log":
			return tabs.get_tab_control(i)
	return null


func test_event_log_tab_empties_when_log_is_cleared() -> void:
	var list: ItemList = _event_log_tab().get_node("Entries")
	EventLog.record(&"noise", "player")

	EventLog.clear()

	assert_int(list.item_count).is_equal(0)
