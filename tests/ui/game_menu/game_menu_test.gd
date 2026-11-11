extends GdUnitTestSuite
## Integration (ADR 0064): the Esc game menu on a small level made the current scene, with real
## key events: Esc opens (paused, mouse free, Resume focused) and closes it; Esc on the Tab
## interface closes only it (a second Esc opens the menu, ADR 0110); Save writes the slot and says
## "Saved"; Load is disabled without a
## loadable save and loads it from the death screen; Save is refused while dead; on the knocked-out
## screen the menu opens, Save is refused and Load works; Quit asks first and
## quits only on Yes. F5 is Combat Strength now and F9 does nothing.

const Saves := preload("res://tests/core/save/save_test_helpers.gd")
const LEVEL := "res://tests/actors/player/fixtures/flat_floor.tscn"
const SPOT := Vector3(1.5, 0.0, -2.0)

var _original: Node
var _level: Node


func before_test() -> void:
	_original = get_tree().current_scene
	Saves.use_test_slot()
	EventLog.clear()
	StimulusSystem.clear()
	DebugPanel.set_open(false)
	_level = await Saves.open_level(get_tree(), LEVEL)


func after_test() -> void:
	DebugPanel.set_open(false)
	Saves.close_level(get_tree(), _original)


func _player(level: Node = _level) -> Player:
	return level.get_node("Player") as Player


func _menu(level: Node = _level) -> GameMenu:
	return _player(level).get_node("GameMenu") as GameMenu


func _press(key: Key) -> void:
	Saves.press(key)
	await get_tree().process_frame


## Holds a key for `count` physics frames (the player polls its actions in _physics_process).
func _hold(key: Key, count: int = 2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		for i in count:
			await get_tree().physics_frame


func _place(position: Vector3) -> void:
	_player().load_state({"position": position, "yaw": 0.5, "pitch": 0.0, "velocity": Vector3.ZERO})
	for i in 3:
		await get_tree().physics_frame


func _kill() -> void:
	_player().body.take_damage(&"damage.blunt", 1000.0, &"head")
	await get_tree().physics_frame


func test_esc_opens_pauses_and_esc_closes() -> void:
	var mouse_before := Input.mouse_mode

	await _press(KEY_ESCAPE)

	var menu := _menu()
	assert_bool(menu.is_open()).is_true()
	assert_bool(menu.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_bool(menu.resume_button.has_focus()).is_true()

	await _press(KEY_ESCAPE)

	assert_bool(menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(Input.mouse_mode).is_equal(mouse_before)
	assert_object(menu.get_viewport().gui_get_focus_owner()).is_null()


func test_resume_closes() -> void:
	await _press(KEY_ESCAPE)

	_menu().resume_button.pressed.emit()

	assert_bool(_menu().is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_esc_on_the_tab_interface_closes_only_it() -> void:
	var tabs := TabInterface.of(_player())
	tabs.open()
	assert_bool(tabs.is_open()).is_true()

	await _press(KEY_ESCAPE)

	assert_bool(tabs.is_open()).is_false()
	assert_bool(_menu().is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

	# The next Esc opens the menu (it pauses), and the Tab interface does not open over it.
	await _press(KEY_ESCAPE)
	assert_bool(_menu().is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	tabs.open()
	assert_bool(tabs.is_open()).is_false()


func test_does_not_open_while_the_debug_panel_is_open() -> void:
	DebugPanel.set_open(true)

	await _press(KEY_ESCAPE)

	assert_bool(_menu().is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_save_with_the_keyboard_writes_the_slot_and_stays_open() -> void:
	await _press(KEY_ESCAPE)
	var menu := _menu()
	assert_bool(menu.load_button.disabled).is_true()
	assert_str(menu.slot_label.text).is_equal(GameMenuRules.NO_SAVE)

	# Resume has focus: Down moves to Save, Enter presses it.
	await _press(KEY_DOWN)
	assert_bool(menu.save_button.has_focus()).is_true()
	await _press(KEY_ENTER)

	assert_bool(FileAccess.file_exists(Saves.SLOT)).is_true()
	assert_array(EventLog.find(&"game.saved")).has_size(1)
	assert_bool(menu.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_str(menu.status_label.text).is_equal(GameMenu.SAVED)
	assert_bool(menu.load_button.disabled).is_false()
	assert_str(menu.slot_label.text).starts_with("Saved ").ends_with(" · Flat Floor")


func test_save_is_refused_while_dead() -> void:
	await _kill()
	assert_bool(_player().is_dead()).is_true()

	await _press(KEY_ESCAPE)
	assert_bool(_menu().is_open()).is_true()
	_menu().save_button.pressed.emit()

	assert_str(_menu().status_label.text).is_equal(GameMenu.DEAD)
	assert_bool(FileAccess.file_exists(Saves.SLOT)).is_false()
	assert_array(EventLog.find(&"game.saved")).is_empty()


func test_load_from_the_death_screen() -> void:
	await _place(SPOT)
	var saved := _player().global_position
	await _press(KEY_ESCAPE)
	assert_bool(_menu().save_game()).is_true()
	await _press(KEY_ESCAPE)
	assert_bool(_menu().is_open()).is_false()
	await _place(Vector3(-2, 0, 2))
	await _kill()
	assert_bool((_player().get_node("Hud") as Hud).death_overlay.visible).is_true()

	await _press(KEY_ESCAPE)
	assert_bool(_menu().is_open()).is_true()
	assert_bool(_menu().load_button.disabled).is_false()
	_menu().load_button.pressed.emit()
	var fresh := await Saves.wait_for_load(get_tree(), _level)

	assert_object(fresh).is_not_null()
	var player := _player(fresh)
	assert_bool(player.is_dead()).is_false()
	assert_vector(player.global_position).is_equal_approx(saved, Vector3.ONE * 0.01)
	assert_bool((player.get_node("Hud") as Hud).death_overlay.visible).is_false()
	assert_str((player.get_node("Hud") as Hud).message_label.text).is_equal(GameMenu.LOADED)
	assert_bool(_menu(fresh).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(PauseScreens.any_open(get_tree())).is_false()
	assert_array(EventLog.find(&"game.loaded")).has_size(1)
	assert_int(StimulusSystem.pending_count()).is_equal(0)


func test_knocked_out_screen_refuses_save_and_loads() -> void:
	await _place(SPOT)
	var saved := _player().global_position
	assert_bool(_menu().save_game()).is_true()
	_player().body.take_damage(&"damage.stun", 1000.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	var hud := _player().get_node("Hud") as Hud
	assert_bool(hud.death_overlay.visible).is_true()
	assert_str(hud.overlay_title.text).is_equal(HudRules.KNOCKED_OUT_TITLE)

	await _press(KEY_ESCAPE)
	assert_bool(_menu().is_open()).is_true()
	assert_bool(_menu().save_game()).is_false()
	assert_str(_menu().status_label.text).is_equal(GameMenu.KNOCKED_OUT)
	assert_array(EventLog.find(&"game.saved")).has_size(1)
	_menu().load_button.pressed.emit()
	var fresh := await Saves.wait_for_load(get_tree(), _level)

	assert_object(fresh).is_not_null()
	var player := _player(fresh)
	assert_bool(ActorState.can_act(player)).is_true()
	assert_vector(player.global_position).is_equal_approx(saved, Vector3.ONE * 0.01)
	assert_bool((player.get_node("Hud") as Hud).death_overlay.visible).is_false()


func test_a_damaged_save_cannot_be_loaded() -> void:
	Saves.write_slot("{ this is not a save")

	await _press(KEY_ESCAPE)

	var menu := _menu()
	assert_bool(menu.load_button.disabled).is_true()
	assert_str(menu.slot_label.text).is_equal(GameMenuRules.MESSAGES[SaveFile.Status.CORRUPT])
	assert_bool(menu.load_game()).is_false()
	assert_str(menu.status_label.text).is_equal(GameMenuRules.MESSAGES[SaveFile.Status.CORRUPT])
	await get_tree().process_frame
	assert_object(get_tree().current_scene).is_same(_level)
	assert_bool(QuickSave.is_loading()).is_false()


func test_a_save_of_another_version_cannot_be_loaded() -> void:
	var data := {"version": SaveFile.VERSION + 1, "level": LEVEL, "saved_at": "x"}
	data.merge({"states": {}, "removed": [], "spawned": {}})
	Saves.write_slot(SaveFile.encode(data))

	await _press(KEY_ESCAPE)

	assert_bool(_menu().load_button.disabled).is_true()
	assert_str(_menu().slot_label.text).is_equal(GameMenuRules.MESSAGES[SaveFile.Status.WRONG_VERSION])
	assert_int(await QuickSave.load_game(get_tree())).is_equal(SaveFile.Status.WRONG_VERSION)


func test_quit_asks_and_quits_only_on_yes() -> void:
	var menu := _menu()
	menu.quit_on_confirm = false
	var quits: Array[int] = []
	menu.quit_requested.connect(func() -> void: quits.append(1))
	await _press(KEY_ESCAPE)

	menu.quit_button.pressed.emit()
	assert_bool(menu.is_confirming_quit()).is_true()
	assert_bool(menu.buttons.visible).is_false()
	assert_str((menu.get_node("%Question") as Label).text).is_equal(GameMenu.QUIT_QUESTION)
	assert_bool(menu.no_button.has_focus()).is_true()
	assert_str(menu.hint_label.text).is_equal(GameMenu.CONFIRM_HINT)

	# Esc backs out of the question only.
	await _press(KEY_ESCAPE)
	assert_bool(menu.is_confirming_quit()).is_false()
	assert_bool(menu.is_open()).is_true()
	assert_bool(menu.buttons.visible).is_true()

	menu.quit_button.pressed.emit()
	menu.no_button.pressed.emit()
	assert_bool(menu.is_confirming_quit()).is_false()
	assert_array(quits).is_empty()

	menu.quit_button.pressed.emit()
	menu.yes_button.pressed.emit()
	assert_array(quits).has_size(1)


func test_f5_toggles_combat_strength_and_f9_does_nothing() -> void:
	var augmentations := Augmentations.of(_player())
	assert_bool(augmentations.is_active(&"combat_strength")).is_false()

	await _hold(KEY_F5)

	assert_bool(augmentations.is_active(&"combat_strength")).is_true()
	assert_bool(FileAccess.file_exists(Saves.SLOT)).is_false()

	assert_int(QuickSave.save_game(get_tree())).is_equal(SaveFile.Status.OK)
	await _hold(KEY_F9)
	await get_tree().process_frame
	assert_object(get_tree().current_scene).is_same(_level)
	assert_bool(QuickSave.is_loading()).is_false()
	assert_array(EventLog.find(&"game.loaded")).is_empty()
