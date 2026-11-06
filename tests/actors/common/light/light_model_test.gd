extends GdUnitTestSuite
## Unit: LightModel (ADR 0065). Godot's distance attenuation, the spot cone, shadowed points, the
## sample points (standing and crouched heights), the saturating point level and the weighted
## combine rule.

const CONFIG: LightExposureConfig = preload("res://actors/common/light/light_exposure.tres")


func test_attenuation_follows_godots_range_window_and_decay() -> void:
	# (1 - (d / r)^4)^2 / d: at 2 m of a 4 m light, (1 - 1/16)^2 / 2.
	assert_float(LightModel.attenuation(2.0, 4.0)).is_equal_approx(pow(15.0 / 16.0, 2.0) / 2.0, 0.0001)
	# Decay 2 is inverse square.
	assert_float(LightModel.attenuation(2.0, 4.0, 2.0)).is_equal_approx(pow(15.0 / 16.0, 2.0) / 4.0, 0.0001)
	# Decay 0 keeps the window only.
	assert_float(LightModel.attenuation(1.0, 4.0, 0.0)).is_equal_approx(pow(1.0 - 1.0 / 256.0, 2.0), 0.0001)


func test_attenuation_is_zero_at_and_beyond_the_range() -> void:
	assert_float(LightModel.attenuation(4.0, 4.0)).is_equal(0.0)
	assert_float(LightModel.attenuation(6.0, 4.0)).is_equal(0.0)
	assert_float(LightModel.attenuation(1.0, 0.0)).is_equal(0.0)


func test_attenuation_falls_with_distance() -> void:
	var near := LightModel.attenuation(1.0, 5.0)
	var mid := LightModel.attenuation(2.5, 5.0)
	var far := LightModel.attenuation(4.0, 5.0)

	assert_float(near).is_greater(mid)
	assert_float(mid).is_greater(far)
	assert_float(far).is_greater(0.0)


func test_omni_contribution_scales_with_energy() -> void:
	var source := LightModel.Source.omni(Vector3(0, 3, 0), 2.0, 5.0)

	var value := LightModel.contribution(source, Vector3(0, 1, 0))

	assert_float(value).is_equal_approx(2.0 * LightModel.attenuation(2.0, 5.0), 0.0001)


func test_spot_lights_points_on_its_axis_like_an_omni_light() -> void:
	var spot := LightModel.Source.spot(Vector3(0, 3, 0), Vector3.DOWN, 1.0, 5.0, 40.0)
	var omni := LightModel.Source.omni(Vector3(0, 3, 0), 1.0, 5.0)

	var on_axis := LightModel.contribution(spot, Vector3(0, 1, 0))

	assert_float(on_axis).is_equal_approx(LightModel.contribution(omni, Vector3(0, 1, 0)), 0.001)


func test_spot_does_not_light_outside_its_cone() -> void:
	var spot := LightModel.Source.spot(Vector3(0, 3, 0), Vector3.DOWN, 1.0, 5.0, 30.0)

	# 2 m to the side of a point 1 m below: 63 degrees off the axis.
	assert_float(LightModel.contribution(spot, Vector3(2, 2, 0))).is_equal(0.0)
	# Behind the light.
	assert_float(LightModel.contribution(spot, Vector3(0, 4, 0))).is_equal(0.0)


func test_spot_cone_fades_towards_its_edge() -> void:
	var spot := LightModel.Source.spot(Vector3(0, 3, 0), Vector3.DOWN, 1.0, 10.0, 40.0)
	var centre := LightModel.spot_factor(Vector3.DOWN, Vector3(0, -1, 0), 40.0)
	# 20 degrees off a 40 degree cone.
	var half := LightModel.spot_factor(Vector3.DOWN, Vector3(sin(deg_to_rad(20.0)), -cos(deg_to_rad(20.0)), 0), 40.0)

	assert_float(centre).is_equal_approx(1.0, 0.001)
	assert_float(half).is_between(0.2, 0.9)
	assert_float(LightModel.contribution(spot, Vector3(0.5, 0, 0))).is_greater(0.0)


func test_a_shadowed_point_gets_no_light_from_that_source() -> void:
	var sources: Array[LightModel.Source] = [LightModel.Source.omni(Vector3(0, 3, 0), 1.0, 5.0)]
	var points := PackedVector3Array([Vector3(0, 1, 0)])
	var weights := PackedFloat32Array([1.0])
	var blocked := func(_s: int, _p: int) -> bool: return false

	var lit := LightModel.level(sources, points, weights, 0.04, 4.0)
	var shadowed := LightModel.level(sources, points, weights, 0.04, 4.0, blocked)

	assert_float(lit).is_greater(0.5)
	assert_float(shadowed).is_equal_approx(0.04, 0.0001)


func test_shadow_check_only_asks_about_contributing_pairs() -> void:
	var sources: Array[LightModel.Source] = [
		LightModel.Source.omni(Vector3(0, 3, 0), 1.0, 5.0),
		LightModel.Source.omni(Vector3(50, 3, 0), 1.0, 5.0),
	]
	var points := PackedVector3Array([Vector3(0, 1, 0), Vector3(0, 0.2, 0)])
	var asked: Array[Vector2i] = []
	var visible := func(s: int, p: int) -> bool:
		asked.append(Vector2i(s, p))
		return true

	LightModel.level(sources, points, PackedFloat32Array([1, 1]), 0.04, 4.0, visible)

	assert_array(asked).contains_exactly([Vector2i(0, 0), Vector2i(0, 1)])


func test_partly_shadowed_body_reads_between_lit_and_dark() -> void:
	var sources: Array[LightModel.Source] = [LightModel.Source.omni(Vector3(0, 3.6, 0), 1.0, 5.0)]
	var points := LightModel.sample_points(Vector3.ZERO, CONFIG.standing_heights)
	var feet_hidden := func(_s: int, p: int) -> bool: return p != 0

	var lit := LightModel.level(sources, points, CONFIG.weights, CONFIG.ambient, CONFIG.gain)
	var partial := LightModel.level(sources, points, CONFIG.weights, CONFIG.ambient, CONFIG.gain, feet_hidden)

	assert_float(partial).is_less(lit)
	assert_float(partial).is_greater(CONFIG.ambient + 0.2)


func test_sample_points_stand_and_crouch_heights_above_the_feet() -> void:
	var standing := LightModel.sample_points(Vector3(1, 2, 3), CONFIG.standing_heights)
	var crouched := LightModel.sample_points(Vector3(1, 2, 3), CONFIG.crouched_heights)

	assert_array(Array(standing)).is_equal([Vector3(1, 2.2, 3), Vector3(1, 3, 3), Vector3(1, 3.6, 3)])
	assert_float(crouched[0].y).is_equal_approx(2.2, 0.0001)
	assert_float(crouched[1].y).is_equal_approx(2.55, 0.0001)
	assert_float(crouched[2].y).is_equal_approx(2.85, 0.0001)


func test_crouching_under_a_ceiling_light_reads_darker() -> void:
	var sources: Array[LightModel.Source] = [LightModel.Source.omni(Vector3(0, 3.6, 0), 1.0, 5.0)]
	var standing := LightModel.sample_points(Vector3.ZERO, CONFIG.standing_heights)
	var crouched := LightModel.sample_points(Vector3.ZERO, CONFIG.crouched_heights)

	var stand_level := LightModel.level(sources, standing, CONFIG.weights, CONFIG.ambient, CONFIG.gain)
	var crouch_level := LightModel.level(sources, crouched, CONFIG.weights, CONFIG.ambient, CONFIG.gain)

	assert_float(crouch_level).is_less(stand_level)


func test_point_level_saturates_below_one() -> void:
	assert_float(LightModel.point_level(0.0, 4.0)).is_equal(0.0)
	assert_float(LightModel.point_level(0.25, 4.0)).is_equal_approx(1.0 - exp(-1.0), 0.0001)
	assert_float(LightModel.point_level(100.0, 4.0)).is_less_equal(1.0)
	assert_float(LightModel.point_level(-1.0, 4.0)).is_equal(0.0)


func test_combine_is_ambient_plus_weighted_average() -> void:
	var levels := PackedFloat32Array([0.0, 1.0, 0.5])
	var weights := PackedFloat32Array([0.25, 0.5, 0.25])

	# Weighted average 0.625; ambient 0.04 + 0.96 x 0.625.
	assert_float(LightModel.combine(levels, weights, 0.04)).is_equal_approx(0.04 + 0.96 * 0.625, 0.0001)
	assert_float(LightModel.combine(PackedFloat32Array([0, 0, 0]), weights, 0.04)).is_equal_approx(0.04, 0.0001)
	# Missing weights count 1.
	assert_float(LightModel.combine(PackedFloat32Array([1, 0]), PackedFloat32Array(), 0.0)).is_equal_approx(0.5, 0.0001)


func test_two_lights_add_up() -> void:
	var one: Array[LightModel.Source] = [LightModel.Source.omni(Vector3(0, 3, -1), 0.5, 5.0)]
	var two: Array[LightModel.Source] = [
		LightModel.Source.omni(Vector3(0, 3, -1), 0.5, 5.0), LightModel.Source.omni(Vector3(0, 3, 1), 0.5, 5.0)
	]
	var points := LightModel.sample_points(Vector3.ZERO, CONFIG.standing_heights)

	var single := LightModel.level(one, points, CONFIG.weights, CONFIG.ambient, CONFIG.gain)
	var double := LightModel.level(two, points, CONFIG.weights, CONFIG.ambient, CONFIG.gain)

	assert_float(double).is_greater(single)
	assert_float(double).is_less_equal(1.0)


func test_no_lights_is_ambient() -> void:
	var sources: Array[LightModel.Source] = []
	var points := LightModel.sample_points(Vector3.ZERO, CONFIG.standing_heights)

	assert_float(LightModel.level(sources, points, CONFIG.weights, CONFIG.ambient, CONFIG.gain)).is_equal_approx(
		CONFIG.ambient, 0.0001
	)
