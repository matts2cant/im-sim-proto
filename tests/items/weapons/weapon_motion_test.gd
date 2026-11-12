extends GdUnitTestSuite
## Unit (ADR 0128): WeaponMotion, the first-person weapon motion by code, on a plain config and on
## the shipped weapons' configs. Stepped at 60 Hz.
## - Bob: none standing still or airborne; walking at the reference speed (4 m/s) swings it by the
##   config's bob; it grows with speed up to the cap (sprinting 6 m/s: x1.5) and shrinks crouched.
## - Reload: the dip rises over the first share of the reload, holds, and is gone at its end.
## - Draw: lowered when drawn, raised after draw_time; a holster lowers it over holster_time.
## - Kick: one shot peaks after kick_time and is back within six of them; automatic shots stack
##   no higher than kick_stack_max. Sway lags a turn and returns.

const DT := 1.0 / 60.0
const PISTOL: WeaponMotionConfig = preload("res://items/weapons/pistol/pistol_motion.tres")
const SHOTGUN: WeaponMotionConfig = preload("res://items/weapons/shotgun/shotgun_motion.tres")
const SMG: WeaponMotionConfig = preload("res://items/weapons/smg/smg_motion.tres")

var _config: WeaponMotionConfig
var _motion: WeaponMotion


func before_test() -> void:
	_config = WeaponMotionConfig.new()
	_motion = WeaponMotion.new(_config, 11)


func test_no_bob_standing_still_or_airborne() -> void:
	var still := _peak_bob(0.0, true, false)
	assert_float(still.x).is_equal(0.0)
	assert_float(still.y).is_equal(0.0)
	_motion.reset()
	var airborne := _peak_bob(4.0, false, false)
	assert_float(airborne.length()).is_equal(0.0)


func test_bob_scales_with_speed_and_is_smaller_crouched() -> void:
	var walk := _peak_bob(4.0, true, false)
	_motion.reset()
	var slow := _peak_bob(2.0, true, false)
	_motion.reset()
	var sprint := _peak_bob(6.0, true, false)
	_motion.reset()
	var crouch := _peak_bob(2.0, true, true)
	# Walking at the reference speed: the config's side swing and footstep dip.
	assert_float(walk.x).is_equal_approx(_config.bob_side, _config.bob_side * 0.1)
	assert_float(walk.y).is_equal_approx(_config.bob_height, _config.bob_height * 0.1)
	assert_float(slow.y).is_equal_approx(walk.y * 0.5, walk.y * 0.1)
	assert_float(sprint.y).is_equal_approx(walk.y * 1.5, walk.y * 0.1)
	# Crouch-walking (2 m/s) is smaller than walking at that speed.
	assert_float(crouch.y).is_equal_approx(slow.y * _config.bob_crouch_scale, walk.y * 0.1)


func test_bob_fades_out_after_stopping() -> void:
	_peak_bob(4.0, true, false)
	_run(0.6, 0.0)
	assert_float(_motion.bob_amount()).is_less(0.01)


func test_reload_dips_over_the_reload_time() -> void:
	var weapon := WeaponState.new(load("res://items/weapons/pistol/pistol.tres") as WeaponData)
	weapon.magazine = 2
	assert_bool(weapon.start_reload()).is_true()
	var total := weapon.reload_total
	var samples: Dictionary[float, float] = {}
	var elapsed := 0.0
	while weapon.is_reloading():
		_motion.step(DT, 0.0, true, false, weapon.reload_progress())
		weapon.step(DT)
		elapsed += DT
		for at: float in [0.05, 0.5, 0.95]:
			if not samples.has(at) and elapsed >= total * at:
				samples[at] = _motion.dip()
	_motion.step(DT, 0.0, true, false, -1.0)
	assert_float(total).is_equal_approx(1.6, 0.001)
	assert_float(samples[0.05]).is_between(0.05, 0.5)
	assert_float(samples[0.5]).is_equal(1.0)
	assert_float(samples[0.95]).is_between(0.05, 0.5)
	assert_float(_motion.dip()).is_equal(0.0)
	assert_vector(_motion.offset).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)


func test_reload_dip_takes_the_weapon_out_of_view() -> void:
	_motion.config = PISTOL
	_motion.step(DT, 0.0, true, false, 0.5)
	# At the bottom: well down and nose down (the pistol leaves the lower edge of the view).
	assert_float(-_motion.offset.y).is_greater_equal(0.25)
	assert_float(-_motion.turn.x).is_greater_equal(30.0)


func test_draw_raises_and_holster_lowers() -> void:
	_motion.start_draw()
	var lowered := _motion.offset.y
	assert_float(lowered).is_equal_approx(-_config.draw_drop, 0.0001)
	_run(_config.draw_time * 0.5, 0.0)
	assert_float(_motion.raised()).is_between(0.4, 0.6)
	_run(_config.draw_time * 0.5 + DT, 0.0)
	assert_float(_motion.raised()).is_equal(1.0)
	assert_vector(_motion.offset).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.0001)
	_motion.start_holster()
	assert_bool(_motion.is_lowered()).is_false()
	_run(_config.holster_time + DT, 0.0)
	assert_bool(_motion.is_lowered()).is_true()
	assert_float(_motion.offset.y).is_equal_approx(-_config.draw_drop, 0.0001)


func test_one_kick_peaks_after_kick_time_and_returns() -> void:
	_motion.config = SHOTGUN
	_motion.kick()
	var peak := 0.0
	var peak_time := 0.0
	var elapsed := 0.0
	while elapsed < SHOTGUN.kick_time * 6.0:
		_motion.step(DT, 0.0, true, false, -1.0)
		elapsed += DT
		if _motion.kick_amount() > peak:
			peak = _motion.kick_amount()
			peak_time = elapsed
	assert_float(peak).is_between(0.9, 1.0)
	assert_float(peak_time).is_equal_approx(SHOTGUN.kick_time, DT)
	assert_float(_motion.kick_amount()).is_less(0.15)
	# Back, nose up at the peak's scale.
	_motion.reset()
	_motion.kick()
	_run(SHOTGUN.kick_time, 0.0)
	assert_float(_motion.offset.z).is_greater(SHOTGUN.kick_back * 0.8)
	assert_float(_motion.turn.x).is_greater(SHOTGUN.kick_pitch_deg * 0.8)


func test_automatic_kicks_stack_up_to_the_cap() -> void:
	_motion.config = SMG
	var highest := 0.0
	for shot in 20:
		_motion.kick()
		for frame in 4:
			_motion.step(DT, 0.0, true, false, -1.0)
			highest = maxf(highest, _motion.kick_amount())
	assert_float(highest).is_greater(1.0)
	assert_float(highest).is_less_equal(SMG.kick_stack_max)


func test_sway_lags_a_turn_and_returns() -> void:
	_motion.add_turn(Vector2(10.0, 0.0))
	_motion.step(DT, 0.0, true, false, -1.0)
	# Turning right: the model lags to the left (yaw positive) and shifts left.
	assert_float(_motion.turn.y).is_greater(0.0)
	assert_float(_motion.offset.x).is_less(0.0)
	assert_float(_motion.sway().length()).is_less_equal(_config.sway_max_deg)
	_run(0.6, 0.0)
	assert_float(_motion.sway().length()).is_less(0.01)


# Steps `seconds` at `speed` on the ground, standing.
func _run(seconds: float, speed: float) -> void:
	for i in roundi(seconds / DT):
		_motion.step(DT, speed, true, false, -1.0)


# Walks 3 s at `speed` and returns the largest side swing (x) and footstep dip (y, positive down)
# over the last 2 s (the bob has eased in).
func _peak_bob(speed: float, grounded: bool, crouched: bool) -> Vector2:
	var peak := Vector2.ZERO
	for i in 180:
		_motion.step(DT, speed, grounded, crouched, -1.0)
		if i >= 60:
			peak.x = maxf(peak.x, absf(_motion.offset.x))
			peak.y = maxf(peak.y, -_motion.offset.y)
	return peak
