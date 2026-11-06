extends GdUnitTestSuite
## Unit: WeaponState (fire rate, ammo, reload timing, dry fire) with the real pistol and baton data.

const PISTOL: WeaponData = preload("res://items/weapons/pistol/pistol.tres")
const BATON: WeaponData = preload("res://items/weapons/baton/baton.tres")
const FRAME := 1.0 / 60.0


func test_pistol_starts_with_a_full_magazine_and_reserve() -> void:
	var state := WeaponState.new(PISTOL)

	assert_int(state.magazine).is_equal(10)
	assert_int(state.reserve).is_equal(30)


func test_fire_rate_is_one_shot_per_cycle() -> void:
	var state := WeaponState.new(PISTOL)

	assert_int(state.try_fire()).is_equal(WeaponState.Result.FIRED)
	assert_int(state.try_fire()).is_equal(WeaponState.Result.BUSY)
	# 0.35 s = 21 frames.
	_frames(state, 20)
	assert_int(state.try_fire()).is_equal(WeaponState.Result.BUSY)
	_frames(state, 1)
	assert_int(state.try_fire()).is_equal(WeaponState.Result.FIRED)
	assert_int(state.magazine).is_equal(8)


func test_empty_magazine_dry_fires() -> void:
	var state := WeaponState.new(PISTOL)
	for i in 10:
		assert_int(state.try_fire()).is_equal(WeaponState.Result.FIRED)
		_frames(state, 21)

	assert_int(state.try_fire()).is_equal(WeaponState.Result.DRY)
	assert_int(state.magazine).is_equal(0)
	assert_int(state.reserve).is_equal(30)


func test_reload_takes_its_time_and_moves_rounds() -> void:
	var state := WeaponState.new(PISTOL)
	for i in 3:
		state.try_fire()
		_frames(state, 21)

	assert_bool(state.start_reload()).is_true()
	assert_int(state.try_fire()).is_equal(WeaponState.Result.RELOADING)
	# 1.6 s = 96 frames.
	_frames(state, 95)
	assert_bool(state.is_reloading()).is_true()
	assert_int(state.magazine).is_equal(7)
	_frames(state, 1)
	assert_bool(state.is_reloading()).is_false()
	assert_int(state.magazine).is_equal(10)
	assert_int(state.reserve).is_equal(27)


func test_reload_takes_only_what_the_reserve_has() -> void:
	var state := WeaponState.new(PISTOL)
	state.magazine = 0
	state.reserve = 4

	state.start_reload()
	_frames(state, 96)

	assert_int(state.magazine).is_equal(4)
	assert_int(state.reserve).is_equal(0)
	state.magazine = 0
	assert_bool(state.start_reload()).is_false()


func test_reload_refused_when_full_or_already_reloading() -> void:
	var state := WeaponState.new(PISTOL)
	assert_bool(state.start_reload()).is_false()

	state.try_fire()
	assert_bool(state.start_reload()).is_true()
	assert_bool(state.start_reload()).is_false()


func test_cancelled_reload_moves_nothing() -> void:
	var state := WeaponState.new(PISTOL)
	state.try_fire()
	state.start_reload()
	_frames(state, 50)

	state.cancel_reload()
	_frames(state, 60)

	assert_int(state.magazine).is_equal(9)
	assert_int(state.reserve).is_equal(30)


func test_baton_has_no_ammo_and_swings_every_cycle() -> void:
	var state := WeaponState.new(BATON)

	assert_int(state.try_fire()).is_equal(WeaponState.Result.FIRED)
	_frames(state, 35)
	assert_int(state.try_fire()).is_equal(WeaponState.Result.BUSY)
	_frames(state, 1)
	assert_int(state.try_fire()).is_equal(WeaponState.Result.FIRED)
	assert_bool(state.start_reload()).is_false()


func test_save_round_trip() -> void:
	var state := WeaponState.new(PISTOL)
	state.try_fire()
	var other := WeaponState.new(PISTOL)

	other.from_dict(state.to_dict())

	assert_int(other.magazine).is_equal(9)
	assert_int(other.reserve).is_equal(30)


func _frames(state: WeaponState, count: int) -> void:
	for i in count:
		state.step(FRAME)
