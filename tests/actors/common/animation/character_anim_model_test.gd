extends GdUnitTestSuite
## Unit (ADR 0103): CharacterAnimModel's state choice. Speeds are kept away from the thresholds
## (idle below 0.25 m/s, sprint at 3.0 m/s or with the sprint stance); dead beats unconscious beats
## everything; a shot overrides the hold pose; the grip comes from WeaponData.

const CONFIG: CharacterAnimConfig = preload("res://actors/common/animation/blocky_character_anim.tres")
const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol_unsilenced.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const RIFLE: WeaponData = preload("res://items/weapons/assault_rifle/assault_rifle.tres")
const SHOTGUN: WeaponData = preload("res://items/weapons/shotgun/shotgun.tres")
const SNIPER: WeaponData = preload("res://items/weapons/sniper_rifle/sniper_rifle.tres")
const STEP := 1.0 / 60.0
const NONE := CharacterAnimModel.NO_GRIP

var _model: CharacterAnimModel


func before_test() -> void:
	_model = CharacterAnimModel.new(CONFIG)
	_model.clip_lengths = {&"holding-right-shoot": 0.2, &"holding-both-shoot": 0.2, &"attack-melee-right": 0.42}


func test_still_body_idles() -> void:
	_model.update(STEP, 0.05, false, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("idle")
	assert_float(_model.playback).is_equal(1.0)


func test_patrol_speed_walks_at_a_scaled_rate() -> void:
	_model.update(STEP, 1.5, false, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("walk")
	assert_float(_model.playback).is_equal_approx(1.5 / CONFIG.walk_clip_speed, 0.001)
	_model.update(STEP, 2.5, false, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("walk")
	assert_float(_model.playback).is_greater(1.5 / CONFIG.walk_clip_speed)


func test_running_or_the_sprint_stance_sprints() -> void:
	_model.update(STEP, 4.0, false, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("sprint")
	assert_float(_model.playback).is_equal_approx(4.0 / CONFIG.sprint_clip_speed, 0.001)
	# The stance tag sprints at a speed that would otherwise walk.
	_model.update(STEP, 2.0, true, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("sprint")
	# The tag alone does not move a still body.
	_model.update(STEP, 0.05, true, false, false, NONE)
	assert_str(String(_model.base_clip())).is_equal("idle")


func test_playback_is_clamped() -> void:
	_model.update(STEP, 0.6, false, false, false, NONE)
	assert_float(_model.playback).is_equal(CONFIG.min_playback)
	_model.update(STEP, 30.0, false, false, false, NONE)
	assert_float(_model.playback).is_equal(CONFIG.max_playback)


func test_grip_comes_from_weapon_data() -> void:
	assert_int(PISTOL.grip).is_equal(WeaponData.Grip.ONE_HAND)
	assert_int(BATON.grip).is_equal(WeaponData.Grip.ONE_HAND)
	for weapon: WeaponData in [RIFLE, SHOTGUN, SNIPER]:
		assert_int(weapon.grip).is_equal(WeaponData.Grip.TWO_HAND)
	_model.update(STEP, 0.0, false, false, false, PISTOL.grip)
	assert_str(String(_model.hold_clip())).is_equal("holding-right")
	assert_array(_model.hold_parts()).contains_exactly([&"arm-right"])
	_model.update(STEP, 0.0, false, false, false, RIFLE.grip)
	assert_str(String(_model.hold_clip())).is_equal("holding-both")
	assert_array(_model.hold_parts()).contains_exactly_in_any_order([&"arm-right", &"arm-left"])
	_model.update(STEP, 0.0, false, false, false, NONE)
	assert_str(String(_model.hold_clip())).is_empty()


func test_a_shot_overrides_holding_then_ends() -> void:
	_model.update(STEP, 1.5, false, false, false, RIFLE.grip)
	assert_str(String(_model.fire(false))).is_equal("holding-both-shoot")
	assert_str(String(_model.upper_clip())).is_equal("holding-both-shoot")
	assert_array(_model.action_parts).contains([&"torso", &"arm-left", &"arm-right"])
	assert_array(_model.action_parts).not_contains([&"leg-left", &"leg-right"])
	# The legs keep walking under it.
	assert_str(String(_model.base_clip())).is_equal("walk")
	for tick in 15:
		_model.update(STEP, 1.5, false, false, false, RIFLE.grip)
	assert_str(String(_model.upper_clip())).is_equal("holding-both")


func test_one_handed_shot_and_melee_swing() -> void:
	_model.update(STEP, 0.0, false, false, false, PISTOL.grip)
	assert_str(String(_model.fire(false))).is_equal("holding-right-shoot")
	assert_array(_model.action_parts).not_contains([&"arm-left"])
	_model.update(STEP, 0.0, false, false, false, BATON.grip)
	assert_str(String(_model.fire(true))).is_equal("attack-melee-right")
	assert_float(_model.action_left).is_equal_approx(0.42, 0.001)


func test_a_shot_with_nothing_drawn_plays_nothing() -> void:
	_model.update(STEP, 0.0, false, false, false, NONE)
	assert_str(String(_model.fire(false))).is_empty()
	assert_str(String(_model.upper_clip())).is_empty()


func test_dead_beats_unconscious_beats_everything() -> void:
	var config := CONFIG.duplicate() as CharacterAnimConfig
	config.unconscious_clip = &"sit"
	_model = CharacterAnimModel.new(config)
	_model.update(STEP, 2.0, true, false, true, RIFLE.grip)
	assert_int(_model.down).is_equal(CharacterAnimModel.Down.UNCONSCIOUS)
	assert_str(String(_model.down_clip())).is_equal("sit")
	# Down: nothing held, no shot plays.
	assert_str(String(_model.hold_clip())).is_empty()
	assert_str(String(_model.fire(false))).is_empty()
	_model.update(STEP, 2.0, true, true, true, RIFLE.grip)
	assert_int(_model.down).is_equal(CharacterAnimModel.Down.DEAD)
	assert_str(String(_model.down_clip())).is_equal("die")


func test_going_down_cuts_an_action() -> void:
	_model.update(STEP, 0.0, false, false, false, BATON.grip)
	_model.fire(true)
	_model.update(STEP, 0.0, false, false, true, BATON.grip)
	assert_str(String(_model.upper_clip())).is_empty()
	# Waking shows the drawn weapon's hold pose again, and standing still idles.
	_model.update(STEP, 0.0, false, false, false, BATON.grip)
	assert_str(String(_model.down_clip())).is_empty()
	assert_str(String(_model.upper_clip())).is_equal("holding-right")
	assert_str(String(_model.base_clip())).is_equal("idle")


func test_layer_cross_fades_and_holds_a_clip_end() -> void:
	var layer := CharacterAnimLayer.new()
	layer.snap(&"idle", [], 1.0, true, 0.0)
	layer.play(&"walk", [], 0.6, true, 1.0, 0.2)
	assert_float(layer.weight_of(&"idle")).is_equal(1.0)
	for tick in 6:
		layer.step(STEP)
	assert_float(layer.weight_of(&"walk")).is_equal_approx(0.5, 0.01)
	for tick in 60:
		layer.step(STEP)
	assert_float(layer.weight_of(&"walk")).is_equal(1.0)
	assert_float(layer.current.time).is_less(0.6)
	layer.play(&"die", [], 0.33, false, 1.0, 0.1)
	for tick in 60:
		layer.step(STEP)
	assert_float(layer.current.time).is_equal(0.33)
	assert_float(layer.current.progress()).is_equal(1.0)
