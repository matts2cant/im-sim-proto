extends GdUnitTestSuite
## Integration (ADR 0133): OverlayFocus, the counted focus of the screens that keep the world
## running. Two holds released in either order give the player's input, its HUD and the mouse back
## once, when the last one goes; the newest hold's mouse mode wins; a hold for everyone (the debug
## panel) blocks input without hiding the HUD; a freed holder counts as released. Real screens: the
## Tab interface and the reading overlay open together and closed in either order.
## (Headless has no mouse modes: the mode the holds want is read from OverlayFocus.mouse_mode().)

const PlayerDriver := preload("res://tests/actors/player/player_driver.gd")
const ROOM := "res://tests/objects/fixtures/carry_room.tscn"

var _driver: PlayerDriver
var _player: Player
var _hud: Hud
var _first: RefCounted
var _second: RefCounted


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_first = RefCounted.new()
	_second = RefCounted.new()


func after_test() -> void:
	OverlayFocus.release(_first)
	OverlayFocus.release(_second)
	DebugPanel.set_open(false)
	PauseScreens.reset(get_tree())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_two_holds_released_first_to_last_restore_once() -> void:
	await _load()
	await _assert_two_holds_restore(_first, _second)


func test_two_holds_released_last_to_first_restore_once() -> void:
	await _load()
	await _assert_two_holds_restore(_second, _first)


func test_the_newest_hold_sets_the_mouse() -> void:
	await _load()
	var before := Input.mouse_mode
	OverlayFocus.acquire(_first, _player, Input.MOUSE_MODE_CAPTURED)
	assert_int(OverlayFocus.mouse_mode()).is_equal(Input.MOUSE_MODE_CAPTURED)
	OverlayFocus.acquire_all(_second)
	assert_int(OverlayFocus.mouse_mode()).is_equal(Input.MOUSE_MODE_VISIBLE)

	OverlayFocus.release(_second)
	assert_int(OverlayFocus.mouse_mode()).is_equal(Input.MOUSE_MODE_CAPTURED)
	OverlayFocus.release(_first)
	assert_int(OverlayFocus.count()).is_equal(0)
	assert_int(Input.mouse_mode).is_equal(before)


func test_a_hold_for_everyone_blocks_input_but_keeps_the_hud() -> void:
	await _load()
	OverlayFocus.acquire_all(_first)

	assert_bool(_player.accepts_input()).is_false()
	assert_bool(OverlayFocus.is_held(_player)).is_false()
	assert_bool(_hud.visible).is_true()
	OverlayFocus.release(_first)
	assert_bool(_player.accepts_input()).is_true()


func test_the_debug_panel_holds_every_players_input() -> void:
	await _load()
	DebugPanel.set_open(true)
	assert_bool(_player.accepts_input()).is_false()
	DebugPanel.set_open(false)
	assert_bool(_player.accepts_input()).is_true()


func test_a_freed_holder_counts_as_released() -> void:
	await _load()
	var holder := Node.new()
	add_child(holder)
	OverlayFocus.acquire(holder, _player, Input.MOUSE_MODE_VISIBLE, true)
	assert_bool(_hud.visible).is_false()

	holder.free()

	assert_bool(OverlayFocus.is_held(_player)).is_false()
	assert_bool(_hud.visible).is_true()
	assert_bool(_player.accepts_input()).is_true()


func test_tab_interface_and_reading_overlay_close_in_either_order() -> void:
	await _load()
	var tabs := TabInterface.of(_player)
	var overlay := _player.get_node("ReadingOverlay") as ReadingOverlay
	for tabs_first: bool in [true, false]:
		tabs.open()
		overlay.open("Note", "Text.")
		assert_bool(tabs.is_open() and overlay.is_open()).is_true()
		assert_bool(_hud.visible).is_false()

		if tabs_first:
			tabs.close()
			# The Tab interface hid the HUD; the reading overlay still holds the input.
			assert_bool(_hud.visible).is_true()
		else:
			overlay.close()
			assert_bool(_hud.visible).is_false()
		assert_bool(_player.accepts_input()).is_false()

		overlay.close()
		tabs.close()
		assert_bool(_player.accepts_input()).is_true()
		assert_bool(_hud.visible).is_true()
		assert_int(OverlayFocus.count()).is_equal(0)


func _assert_two_holds_restore(released_first: Object, released_last: Object) -> void:
	_hud.visible = true
	var before := Input.mouse_mode
	OverlayFocus.acquire(_first, _player, Input.MOUSE_MODE_VISIBLE, true)
	OverlayFocus.acquire(_second, _player, Input.MOUSE_MODE_VISIBLE, true)
	assert_bool(_player.accepts_input()).is_false()
	assert_bool(_hud.visible).is_false()

	OverlayFocus.release(released_first)
	assert_bool(_player.accepts_input()).override_failure_message("restored before the last hold").is_false()
	assert_bool(_hud.visible).override_failure_message("HUD back before the last hold").is_false()
	assert_int(OverlayFocus.mouse_mode()).is_equal(Input.MOUSE_MODE_VISIBLE)

	OverlayFocus.release(released_last)
	assert_bool(_player.accepts_input()).is_true()
	assert_bool(_hud.visible).is_true()
	assert_int(OverlayFocus.count()).is_equal(0)
	assert_int(Input.mouse_mode).is_equal(before)
	# Releasing again changes nothing.
	_hud.visible = false
	OverlayFocus.release(released_last)
	assert_bool(_hud.visible).is_false()
	_hud.visible = true


func _load() -> void:
	_driver = PlayerDriver.new(scene_runner(ROOM))
	_player = _driver.player
	_hud = Hud.of(_player)
	await _driver.settle()
	await _driver.place(Vector3.ZERO)
