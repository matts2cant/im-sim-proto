extends GdUnitTestSuite
## Unit: BodyDamageModel and BodyProfile (part health, multipliers, area split, heal, fall damage).

const PLAYER_PROFILE: BodyProfile = preload("res://actors/player/player_body.tres")
const DUMMY_PROFILE: BodyProfile = preload("res://actors/dummy/dummy_body.tres")
const FALL_DAMAGE: Receptron = preload("res://actors/common/body/receptrons/fall_damage.tres")

var _model: BodyDamageModel


func before_test() -> void:
	_model = BodyDamageModel.new(PLAYER_PROFILE)


func test_profiles_set_part_health() -> void:
	var expected := {&"head": 60.0, &"torso": 100.0, &"arm_l": 60.0, &"arm_r": 60.0, &"leg_l": 70.0, &"leg_r": 70.0}
	for part: StringName in expected:
		assert_float(_model.health(part)).is_equal(expected[part])
	var dummy := BodyDamageModel.new(DUMMY_PROFILE)
	var dummy_expected := {&"head": 40.0, &"torso": 80.0, &"arm_l": 50.0, &"leg_r": 50.0}
	for part: StringName in dummy_expected:
		assert_float(dummy.health(part)).is_equal(dummy_expected[part])


func test_headshot_doubles_ballistic_only() -> void:
	assert_float(_model.damage_part(&"head", &"damage.ballistic", 25.0)).is_equal(50.0)
	assert_float(_model.health(&"head")).is_equal(10.0)
	assert_float(_model.damage_part(&"head", &"damage.blunt", 5.0)).is_equal(5.0)
	assert_float(_model.damage_part(&"torso", &"damage.ballistic", 25.0)).is_equal(25.0)


func test_type_resistance_multiplies() -> void:
	var profile := PLAYER_PROFILE.duplicate() as BodyProfile
	profile.type_multipliers = {&"damage.fire": 0.5, &"damage": 0.8}
	var model := BodyDamageModel.new(profile)

	assert_float(model.damage_part(&"torso", &"damage.fire", 10.0)).is_equal(5.0)
	# No entry for blunt: the `damage` ancestor entry applies.
	assert_float(model.damage_part(&"torso", &"damage.blunt", 10.0)).is_equal_approx(8.0, 0.0001)
	# Head ballistic: 0.8 (body) x 2 (head).
	assert_float(model.damage_part(&"head", &"damage.ballistic", 10.0)).is_equal_approx(16.0, 0.0001)


func test_health_clamps_at_zero_but_reports_full_damage() -> void:
	var dummy := BodyDamageModel.new(DUMMY_PROFILE)

	assert_float(dummy.damage_part(&"head", &"damage.ballistic", 25.0)).is_equal(50.0)
	assert_float(dummy.health(&"head")).is_equal(0.0)
	assert_bool(dummy.is_dead()).is_true()


func test_explosive_split_torso_40_others_12() -> void:
	var dealt := _model.damage_area(&"damage.explosive", 50.0)

	assert_float(dealt[&"torso"]).is_equal_approx(20.0, 0.0001)
	for part: StringName in [&"head", &"arm_l", &"arm_r", &"leg_l", &"leg_r"]:
		assert_float(dealt[part]).is_equal_approx(6.0, 0.0001)
	assert_float(_model.health(&"torso")).is_equal_approx(80.0, 0.0001)


func test_area_weights_are_data_per_type_most_specific_wins() -> void:
	var profile := PLAYER_PROFILE.duplicate() as BodyProfile
	profile.area_weights_by_type = profile.area_weights_by_type.duplicate()
	profile.area_weights_by_type[&"damage.gas"] = {&"head": 0.5, &"torso": 0.5}
	var model := BodyDamageModel.new(profile)

	var gas := model.split(&"damage.gas.sleep", 10.0)
	var blunt := model.split(&"damage.blunt", 10.0)
	var ballistic := model.split(&"damage.ballistic", 10.0)

	assert_dict(gas).is_equal({&"head": 5.0, &"torso": 5.0})
	assert_dict(blunt).is_equal({&"torso": 10.0})
	assert_dict(ballistic).is_equal({&"torso": 10.0})


func test_fire_split_evenly() -> void:
	var dealt := _model.damage_area(&"damage.fire", 6.0)

	assert_int(dealt.size()).is_equal(6)
	for part in BodyDamageModel.PARTS:
		assert_float(dealt[part]).is_equal_approx(1.0, 0.0001)


func test_other_types_without_part_hit_the_torso() -> void:
	var dealt := _model.damage_area(&"damage.blunt", 7.0)

	assert_array(dealt.keys()).contains_exactly([&"torso"])
	assert_float(_model.health(&"torso")).is_equal(93.0)


func test_death_on_head_or_torso_only() -> void:
	_model.damage_part(&"leg_l", &"damage.blunt", 100.0)
	_model.damage_part(&"arm_r", &"damage.blunt", 100.0)
	assert_bool(_model.is_dead()).is_false()
	assert_int(_model.disabled_legs()).is_equal(1)
	assert_int(_model.disabled_arms()).is_equal(1)

	_model.damage_part(&"torso", &"damage.blunt", 100.0)
	assert_bool(_model.is_dead()).is_true()


func test_heal_splits_evenly_over_damaged_parts() -> void:
	_model.damage_part(&"head", &"damage.blunt", 20.0)
	_model.damage_part(&"torso", &"damage.blunt", 20.0)

	var healed := _model.heal(30.0)

	assert_float(healed).is_equal_approx(30.0, 0.0001)
	assert_float(_model.health(&"head")).is_equal_approx(55.0, 0.0001)
	assert_float(_model.health(&"torso")).is_equal_approx(95.0, 0.0001)


func test_heal_overflow_goes_to_parts_still_damaged() -> void:
	_model.damage_part(&"head", &"damage.blunt", 4.0)
	_model.damage_part(&"torso", &"damage.blunt", 40.0)
	_model.damage_part(&"leg_l", &"damage.blunt", 70.0)

	# 30 / 3 = 10 each; the head only takes 4, its 6 left is split over torso and leg (+3 each).
	var healed := _model.heal(30.0)

	assert_float(healed).is_equal_approx(30.0, 0.0001)
	assert_float(_model.health(&"head")).is_equal_approx(60.0, 0.0001)
	assert_float(_model.health(&"torso")).is_equal_approx(73.0, 0.0001)
	assert_float(_model.health(&"leg_l")).is_equal_approx(13.0, 0.0001)


func test_heal_stops_at_full_health() -> void:
	_model.damage_part(&"arm_l", &"damage.blunt", 10.0)

	assert_float(_model.heal(30.0)).is_equal_approx(10.0, 0.0001)
	assert_float(_model.heal(30.0)).is_equal(0.0)


func test_dead_cannot_heal() -> void:
	_model.damage_part(&"head", &"damage.blunt", 60.0)

	assert_float(_model.heal(30.0)).is_equal(0.0)
	assert_float(_model.health(&"head")).is_equal(0.0)


# Fall damage = the fall_damage receptron's effect (impact speed -> damage) shared by the profile.
func test_fall_damage_formula() -> void:
	var effect := FALL_DAMAGE.effects[0] as BodyDamageEffect
	for speed: float in [9.9, 10.0, 14.0, 20.0]:
		var per_leg := _model.split(&"damage.fall", effect.damage(speed))
		var expected := maxf(speed - 10.0, 0.0) * 8.0
		if expected <= 0.0:
			assert_float(effect.damage(speed)).is_equal(0.0)
			continue
		assert_array(per_leg.keys()).contains_exactly_in_any_order([&"leg_l", &"leg_r"])
		for leg: StringName in per_leg:
			assert_float(per_leg[leg]).is_equal_approx(expected, 0.0001)


func test_save_round_trip() -> void:
	_model.damage_part(&"arm_r", &"damage.blunt", 12.5)
	var other := BodyDamageModel.new(PLAYER_PROFILE)

	other.from_dict(_model.to_dict())

	assert_float(other.health(&"arm_r")).is_equal(47.5)
	assert_float(other.health(&"head")).is_equal(60.0)
