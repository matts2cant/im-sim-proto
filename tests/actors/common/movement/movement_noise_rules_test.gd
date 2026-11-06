extends GdUnitTestSuite
## Unit: MovementNoiseRules (footstep and landing loudness, strides, volume).

var _config: MovementNoiseConfig


func before_test() -> void:
	var surfaces := SurfaceTable.new()
	surfaces.default_surface = &"concrete"
	surfaces.multipliers = {&"concrete": 1.0, &"carpet": 0.5, &"metal": 1.6}
	_config = MovementNoiseConfig.new()
	_config.surfaces = surfaces
	_config.walk_stride = 2.0
	_config.sprint_stride = 2.6
	_config.crouch_stride = 1.2
	_config.walk_loudness = 6.0
	_config.sprint_loudness = 14.0
	_config.crouch_loudness = 2.0
	_config.landing_min_impact_speed = 3.0
	_config.landing_loudness = 6.0
	_config.landing_reference_speed = 5.0
	_config.landing_max_factor = 4.0
	_config.audio_reference_loudness = 6.0
	_config.audio_min_db = -18.0
	_config.audio_max_db = 6.0


func test_stride_per_stance() -> void:
	assert_float(MovementNoiseRules.stride(MovementNoiseRules.Stance.WALK, _config)).is_equal(2.0)
	assert_float(MovementNoiseRules.stride(MovementNoiseRules.Stance.SPRINT, _config)).is_equal(2.6)
	assert_float(MovementNoiseRules.stride(MovementNoiseRules.Stance.CROUCH, _config)).is_equal(1.2)


func test_footstep_loudness_is_mode_times_surface() -> void:
	assert_float(MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.WALK, &"concrete", _config)).is_equal(
		6.0
	)
	(
		assert_float(MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.SPRINT, &"metal", _config))
		. is_equal_approx(22.4, 0.0001)
	)
	assert_float(MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.CROUCH, &"carpet", _config)).is_equal(
		1.0
	)


func test_footstep_on_unknown_surface_uses_default() -> void:
	assert_float(MovementNoiseRules.footstep_loudness(MovementNoiseRules.Stance.WALK, &"lava", _config)).is_equal(6.0)


func test_landing_below_threshold_is_silent() -> void:
	assert_float(MovementNoiseRules.landing_loudness(2.99, &"metal", _config)).is_equal(0.0)


func test_landing_loudness_scales_with_impact_and_clamps() -> void:
	assert_float(MovementNoiseRules.landing_loudness(3.0, &"concrete", _config)).is_equal(6.0)
	assert_float(MovementNoiseRules.landing_loudness(10.0, &"concrete", _config)).is_equal(12.0)
	assert_float(MovementNoiseRules.landing_loudness(10.0, &"carpet", _config)).is_equal(6.0)
	assert_float(MovementNoiseRules.landing_loudness(50.0, &"concrete", _config)).is_equal(24.0)


func test_volume_db_reference_and_clamps() -> void:
	assert_float(MovementNoiseRules.volume_db(6.0, _config)).is_equal_approx(0.0, 0.0001)
	assert_float(MovementNoiseRules.volume_db(60.0, _config)).is_equal_approx(6.0, 0.0001)
	assert_float(MovementNoiseRules.volume_db(0.6, _config)).is_equal_approx(-10.0, 0.0001)
	assert_float(MovementNoiseRules.volume_db(0.0, _config)).is_equal(-18.0)


func test_stance_from_tags_crouch_wins() -> void:
	assert_int(MovementNoiseRules.stance_of(false, false)).is_equal(MovementNoiseRules.Stance.WALK)
	assert_int(MovementNoiseRules.stance_of(false, true)).is_equal(MovementNoiseRules.Stance.SPRINT)
	assert_int(MovementNoiseRules.stance_of(true, true)).is_equal(MovementNoiseRules.Stance.CROUCH)


func test_landing_base_is_its_own_value() -> void:
	_config.landing_loudness = 4.0

	assert_float(MovementNoiseRules.landing_loudness(10.0, &"concrete", _config)).is_equal(8.0)
