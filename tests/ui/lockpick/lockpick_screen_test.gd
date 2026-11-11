extends GdUnitTestSuite
## Integration (ADR 0107, 0109): the real player picks a door's pin lock through the LockpickScreen
## (lockpick_ui_helpers.gd has the fixture). LMB with a lockpick on the leaf opens the minigame: the
## game keeps running, the camera turns to the lock, the wheel works tension (W does not walk), mouse
## motion moves the pick (sideways only while the tip is down), A / D too. E or Esc
## leaves (Esc does not open the game menu), so does damage or the lock unlocked by other means;
## leaving loses the progress. A picked door unlocks and opens, the pick is kept; a broken pick uses
## up one lockpick, the last one ends the attempt.

const UiHelpers := preload("res://tests/ui/lockpick/lockpick_ui_helpers.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")

var _ui: UiHelpers
var _lock: MechanicalLock


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_ui = UiHelpers.new()
	await _ui.setup(scene_runner(Helpers.WALL_PLAYER))
	_lock = Helpers.add_mechanical(_ui.door_entity, 3)
	Helpers.lock(_ui.door_entity)


func after_test() -> void:
	_ui.teardown()
	PauseScreens.reset(get_tree())


func test_lmb_with_a_lockpick_starts_the_minigame_facing_the_lock() -> void:
	# Empty hands: nothing.
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL + Vector3(0.3, 0.2, 0))
	assert_bool(_ui.screen.is_open()).is_false()
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL + Vector3(0.3, 0.2, 0))

	assert_bool(_ui.screen.is_open()).is_true()
	assert_array(EventLog.find(&"lock.pick_started")).has_size(1)
	assert_bool(get_tree().paused).is_false()
	assert_bool(_ui.player.input_enabled).is_false()
	# The view turns to the keyhole.
	await _ui.seconds(0.4)
	var eye := _ui.player.eye_transform()
	var to_lock := (_lock.noise_origin() - eye.origin).normalized()
	assert_float((-eye.basis.z).dot(to_lock)).is_greater(0.995)
	# W does not walk (nor turn the wrench); the wheel does, 3 % a notch, 1 % with Shift, and the belt
	# keeps the lockpick in hand.
	var feet := _ui.player.global_position
	_ui.driver.runner.simulate_action_press(&"move_forward")
	await _ui.seconds(0.5)
	_ui.driver.runner.simulate_action_release(&"move_forward")
	assert_float(_ui.player.global_position.distance_to(feet)).is_less(0.01)
	assert_float(_ui.screen.model.tension).is_equal(0.0)
	for i in 5:
		await _wheel(MOUSE_BUTTON_WHEEL_UP)
	assert_float(_ui.screen.model.tension).is_equal_approx(0.15, 0.0001)
	_ui.driver.runner.simulate_action_press(&"lockpick_fine")
	await _wheel(MOUSE_BUTTON_WHEEL_DOWN)
	_ui.driver.runner.simulate_action_release(&"lockpick_fine")
	assert_float(_ui.screen.model.tension).is_equal_approx(0.14, 0.0001)
	assert_str(String(_ui.player.inventory.held_tool())).is_equal("lockpick")


func test_the_mouse_moves_the_pick_sideways_only_while_it_is_down() -> void:
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	var model := _ui.screen.model
	await _ui.seconds(0.4)
	var view_before := _ui.player.eye_transform().basis
	# 60 px right: the next pin.
	await _move(Vector2(60, 0))
	assert_int(model.pick).is_equal(1)
	# 90 px up lifts the tip (300 px for the full lift); sideways now does not move it.
	await _move(Vector2(0, -90))
	assert_float(model.tip).is_equal_approx(0.3, 0.01)
	await _move(Vector2(60, 0))
	assert_int(model.pick).is_equal(1)
	# Down again, it slides on to the pin the mouse aims at.
	await _move(Vector2(0, 90))
	assert_int(model.pick).is_equal(2)
	# A / D work while the tip is down.
	await _ui.driver.hold(&"lockpick_prev_pin", 2)
	await _ui.seconds(0.4)
	assert_int(model.pick).is_equal(1)
	# The view did not turn.
	assert_bool(_ui.player.eye_transform().basis.is_equal_approx(view_before)).is_true()


func test_e_leaves_and_loses_the_progress() -> void:
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	var model := _ui.screen.model
	model.tension = 0.45
	model.aim = 0.3
	await _ui.seconds(0.2)

	# E with LMB held: leaves.
	_ui.driver.runner.simulate_action_press(&"fire")
	await _ui.driver.hold(&"use", 2)
	await _ui.driver.frames(2)

	assert_bool(_ui.screen.is_open()).is_false()
	assert_bool(_ui.player.input_enabled).is_true()
	assert_bool(_ui.door.is_open()).is_false()
	assert_str(EventLog.find(&"lock.pick_cancelled")[0].data["reason"]).is_equal("left")
	# E did not also open or use the door, and the still-held LMB does not start it again.
	await _ui.driver.frames(5)
	assert_bool(_ui.screen.is_open()).is_false()
	_ui.driver.runner.simulate_action_release(&"fire")
	# A new attempt starts from scratch.
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_float(_ui.screen.model.tension).is_equal(0.0)


func test_esc_leaves_without_opening_the_game_menu() -> void:
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	await _ui.driver.hold(&"ui_cancel", 2)
	await _ui.driver.frames(2)
	assert_bool(_ui.screen.is_open()).is_false()
	var menu := _ui.player.get_node("GameMenu") as GameMenu
	assert_bool(menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_damage_or_an_unlock_by_other_means_ends_it() -> void:
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	_ui.player.body.take_damage(&"damage.blunt", 5.0)
	await _ui.driver.frames(2)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_str(EventLog.find(&"lock.pick_cancelled")[0].data["reason"]).is_equal("damage")

	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	assert_bool(_ui.screen.is_open()).is_true()
	Lockable.of(_ui.door_entity).unlock(null, &"command")
	await _ui.driver.frames(2)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_str(EventLog.find(&"lock.pick_cancelled")[1].data["reason"]).is_equal("unlocked")


func test_a_picked_door_unlocks_and_opens_and_keeps_the_pick() -> void:
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	assert_bool(await _ui.pick_open()).is_true()
	await _ui.seconds(0.2)
	assert_bool(_ui.door.is_locked()).is_false()
	assert_array(EventLog.find(&"lock.picked")).has_size(1)
	# The plug turns, then the screen closes and the door swings open.
	await _ui.seconds(1.0)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_bool(_ui.player.input_enabled).is_true()
	assert_bool(_ui.door.is_open()).is_true()
	assert_int(_ui.player.inventory.inventory.count_of(&"lockpick")).is_equal(1)


func test_a_broken_pick_uses_one_up_and_the_last_ends_it() -> void:
	await _ui.hold_picks(2)
	await _ui.click_at(UiHelpers.DOOR_FEET, UiHelpers.DOOR_PANEL)
	assert_bool(await _ui.force_snap()).is_true()
	await _ui.driver.frames(1)
	assert_int(_ui.player.inventory.inventory.count_of(&"lockpick")).is_equal(1)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_str(String(_ui.player.inventory.held_tool())).is_equal("lockpick")

	assert_bool(await _ui.force_snap()).is_true()
	await _ui.driver.frames(1)
	assert_int(_ui.player.inventory.inventory.count_of(&"lockpick")).is_equal(0)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_str(EventLog.find(&"lock.pick_cancelled")[0].data["reason"]).is_equal("no_picks")
	assert_bool(_ui.door.is_locked()).is_true()


func _wheel(button: MouseButton) -> void:
	_ui.driver.runner.simulate_mouse_button_pressed(button)
	await _ui.driver.frames(1)


# Relative mouse motion of `pixels` (screen pixels, y down), then a moment for the tip to follow.
func _move(pixels: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = pixels
	motion.screen_relative = pixels
	_ui.player.get_viewport().push_input(motion)
	await _ui.seconds(0.5)
