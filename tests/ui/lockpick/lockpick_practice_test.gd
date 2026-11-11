extends GdUnitTestSuite
## Integration (ADR 0107, 0109): the minigame on locks that are not doors (lockpick_ui_helpers.gd has
## the fixture). A minimal entity with a Lockable and a MechanicalLock is picked like a door
## (generality); the assists follow the picker's Lockpicking tier (Untrained sound only and a brass
## lock, Trained + gauge, Advanced + captions, Master + the clear lock); a practice lock draws the clear
## lock with every assist whatever the skill, breaks picks like
## any lock, and once opened re-locks about 3 s later with a new layout and counter (the screen stays
## open: "new pin layout"), also when the picker has left. Its noises reach a listener entity like
## any noise: a snapped pick (6) carries, a click (2) does not, 2.4 m away.

const UiHelpers := preload("res://tests/ui/lockpick/lockpick_ui_helpers.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")
const Fixtures := preload("res://tests/core/stimulus/stimulus_fixtures.gd")

var _ui: UiHelpers
var _nav: Helpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_ui = UiHelpers.new()
	_nav = Helpers.new()
	await _ui.setup(scene_runner(Helpers.WALL_PLAYER))


func after_test() -> void:
	_ui.teardown()
	_nav.teardown()


func test_any_entity_with_a_mechanical_lock_is_picked() -> void:
	var locker := await _ui.add_box_lock(3)
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_bool(await _ui.pick_open()).is_true()
	await _ui.seconds(1.0)
	assert_bool(Lockable.of(locker).locked).is_false()
	assert_bool(_ui.screen.is_open()).is_false()


func test_assists_follow_the_lockpicking_tier() -> void:
	await _ui.add_box_lock(3)
	await _ui.hold_picks(1)
	for tier in 4:
		_ui.player.skills.set_tier(&"lockpicking", tier)
		await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
		assert_bool(await _ui.set_pins(1)).is_true()
		_ui.screen.refresh()
		await get_tree().process_frame
		var at := "tier %d" % tier
		assert_bool(_ui.screen.view.drawn_gauge).override_failure_message(at).is_equal(tier >= 1)
		assert_bool(_ui.screen.caption_panel.visible).override_failure_message(at).is_equal(tier >= 2)
		assert_str(_ui.screen.caption_label.text).is_equal("click")
		assert_bool(_ui.screen.view.drawn_clear).override_failure_message(at).is_equal(tier >= 3)
		_ui.screen.leave()
		await _ui.driver.frames(2)


func test_a_practice_lock_shows_every_assist_and_relocks_with_a_new_layout() -> void:
	var body := await _ui.add_practice(MechanicalLockData.Tier.SIMPLE)
	var lock := body.get_node("MechanicalLock") as MechanicalLock
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_int(_ui.screen.assist).is_equal(LockpickParams.ASSIST_PINS)
	assert_int(_ui.screen.model.pins.size()).is_equal(3)
	_ui.screen.refresh()
	await get_tree().process_frame
	assert_bool(_ui.screen.view.drawn_clear).is_true()
	assert_bool(_ui.screen.view.drawn_gauge).is_true()
	assert_int(lock.layout_number()).is_equal(1)
	var before := _shears()

	assert_bool(await _ui.pick_open()).is_true()
	await _ui.seconds(0.5)
	assert_bool(Lockable.of(body).locked).is_false()
	assert_bool(_ui.screen.is_open()).is_true()
	await _ui.seconds(2.7)
	# Re-locked: a new layout, the counter, the caption; the pins settle over about 0.5 s.
	assert_bool(Lockable.of(body).locked).is_true()
	assert_int(lock.layout_number()).is_equal(2)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_bool(_ui.screen.model.opened).is_false()
	assert_float(_ui.screen.model.relayout_t).is_less(1.0)
	assert_array(_shears()).is_not_equal(before)
	_ui.screen.refresh()
	assert_str(_ui.screen.caption_label.text).is_equal("new pin layout")
	assert_str(_ui.screen.tag_label.text).contains("Layout 2")
	assert_array(EventLog.find(&"lock.relocked")).has_size(1)
	await _ui.seconds(0.6)
	assert_float(_ui.screen.model.relayout_t).is_equal(1.0)
	# It can be picked again, and picks break on it like on any lock.
	assert_bool(await _ui.force_snap()).is_true()
	await _ui.driver.frames(1)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_int(_ui.player.inventory.inventory.count_of(&"lockpick")).is_equal(0)


func test_a_practice_lock_relocks_after_the_picker_left() -> void:
	var body := await _ui.add_practice(MechanicalLockData.Tier.SIMPLE)
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	assert_bool(await _ui.pick_open()).is_true()
	await _ui.seconds(0.3)
	_ui.screen.leave()
	assert_bool(Lockable.of(body).locked).is_false()
	await _ui.seconds(3.0)
	assert_bool(Lockable.of(body).locked).is_true()
	var lock := body.get_node("MechanicalLock") as MechanicalLock
	assert_int(int(lock.save_state()["layout"])).is_equal(2)


func test_pick_noises_reach_a_listener_by_loudness() -> void:
	await _nav.sync_navigation(_ui.driver.runner.scene())
	var heard: Array[Effect] = [Fixtures.add_tag(&"heard")]
	var receptrons: Array[Receptron] = [Fixtures.receptron(&"noise", heard)]
	var listener := Fixtures.entity(
		_ui.driver.runner.scene(), "Listener", Helpers.ORIGIN + Vector3(2.5, 0.5, 2.5), receptrons
	)
	await _ui.add_box_lock(3)
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	assert_bool(await _ui.set_pins(2)).is_true()
	await _ui.driver.frames(3)
	assert_bool(Fixtures.tags_of(listener).has(&"heard")).override_failure_message("a click carried").is_false()
	assert_bool(await _ui.force_snap()).is_true()
	await _ui.driver.frames(3)
	assert_bool(Fixtures.tags_of(listener).has(&"heard")).is_true()
	var loud := EventLog.find(&"stimulus.emitted").filter(
		func(entry: EventLogEntry) -> bool: return entry.data.get("type") == &"noise"
	)
	assert_int(loud.size()).is_greater(2)


func _shears() -> Array[float]:
	var out: Array[float] = []
	for pin in _ui.screen.model.pins:
		out.append(pin.shear)
	return out
