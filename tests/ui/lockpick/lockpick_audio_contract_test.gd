extends GdUnitTestSuite
## Integration across the LockpickAudio contract (ADR 0107 minigame, ADR 0108 sounds): the real
## minigame on a lock drives the real LockpickAudio. A set plays a one-shot (the click), the binding
## pin rubbing sets the scrape voice, forcing at high tension sets the strain voice, and leaving stops
## everything (stop_all: both voices back to 0, no one-shot playing). Once the lock opens the scrape
## and strain targets go to 0 at once, before the screen closes.

const UiHelpers := preload("res://tests/ui/lockpick/lockpick_ui_helpers.gd")
const Helpers := preload("res://tests/objects/door/door_helpers.gd")

var _ui: UiHelpers


func before_test() -> void:
	DebugPanel.set_open(false)
	EventLog.clear()
	StimulusSystem.clear()
	_ui = UiHelpers.new()
	await _ui.setup(scene_runner(Helpers.WALL_PLAYER))


func after_test() -> void:
	_ui.teardown()


func test_the_minigame_drives_the_real_lockpick_audio() -> void:
	await _ui.add_box_lock(3)
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	var audio := _ui.screen.audio
	var model := _ui.screen.model
	assert_object(audio).is_instanceof(LockpickAudio)
	assert_bool(audio.is_playing_one_shot()).is_false()

	# Lifting the binding pin: it rubs (scrape) and sets (a click one-shot).
	model.tension = 0.45
	var index := model.binding_index()
	model.aim_x = index
	await _ui.seconds(0.4)
	model.aim = model.pins[index].shear + 0.15
	var scrape := 0.0
	for i in 60:
		await _ui.driver.frames(1)
		scrape = maxf(scrape, audio.voices._scrape_gain_target)
		if model.pins[index].is_set:
			break
	assert_float(scrape).is_greater(0.0)
	assert_bool(model.pins[index].is_set).is_true()
	assert_bool(audio.is_playing_one_shot()).is_true()

	# Forcing the next binding pin at high tension strains the pick.
	var next := model.binding_index()
	model.pins[next].shear = 0.74
	model.aim = 0.0
	await _ui.driver.frames(2)
	model.aim_x = next
	await _ui.seconds(0.4)
	model.tension = 0.9
	model.aim = 1.0
	await _ui.seconds(0.15)
	assert_float(audio.voices._strain_gain_target).is_greater(0.0)

	# Leaving stops everything.
	await _ui.driver.hold(&"use", 2)
	assert_bool(_ui.screen.is_open()).is_false()
	assert_float(audio.voices._scrape_gain_target).is_equal(0.0)
	assert_float(audio.voices._strain_gain_target).is_equal(0.0)
	assert_bool(audio.is_playing_one_shot()).is_false()


func test_scrape_and_strain_go_silent_once_the_lock_opens() -> void:
	await _ui.add_box_lock(3)
	await _ui.hold_picks(1)
	await _ui.click_at(UiHelpers.WALL_FEET, UiHelpers.WALL_LOCK)
	var audio := _ui.screen.audio
	assert_bool(await _ui.set_pins(2)).is_true()
	# The last pin, lifted while it rubs, some strain left over.
	var model := _ui.screen.model
	var last := model.binding_index()
	model.aim = 0.0
	await _ui.driver.frames(2)
	model.aim_x = last
	await _ui.seconds(0.4)
	model.strain = 0.6
	model.aim = model.pins[last].shear + 0.15
	var scrape := 0.0
	for i in 60:
		await _ui.driver.frames(1)
		if model.opened:
			break
		scrape = maxf(scrape, audio.voices._scrape_gain_target)
	assert_float(scrape).is_greater(0.0)
	assert_bool(model.opened).is_true()
	await _ui.driver.frames(2)
	assert_bool(_ui.screen.is_open()).is_true()
	assert_float(audio.voices._scrape_gain_target).is_equal(0.0)
	assert_float(audio.voices._strain_gain_target).is_equal(0.0)
